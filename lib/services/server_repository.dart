import '../core/logging/session_logger.dart';
import '../vpn/models/server_models.dart';
import 'latency_checker.dart';

class ServerRepository {
  final List<ServerProfile> _servers = <ServerProfile>[];
  String? _selectedServerId;
  final LatencyChecker _latencyChecker;

  ServerRepository({
    required SessionLogger logger,
    LatencyChecker? latencyChecker,
  }) : _latencyChecker =
           latencyChecker ?? LatencyCheckerFactory.create(logger: logger);

  List<ServerProfile> get servers => List<ServerProfile>.unmodifiable(_servers);

  String? get selectedServerId => _selectedServerId;

  ServerProfile? get selectedServer {
    if (_selectedServerId == null) {
      return null;
    }
    for (final ServerProfile server in _servers) {
      if (server.id == _selectedServerId) {
        return server;
      }
    }
    return null;
  }

  void upsert(ServerProfile profile) {
    final int index = _servers.indexWhere(
      (ServerProfile item) => item.id == profile.id,
    );
    if (index >= 0) {
      _servers[index] = profile;
      return;
    }
    _servers.add(profile);
  }

  bool remove(String id) {
    final int initialLength = _servers.length;
    _servers.removeWhere((ServerProfile item) => item.id == id);
    final bool removed = _servers.length != initialLength;
    if (removed && _selectedServerId == id) {
      _selectedServerId = null;
    }
    return removed;
  }

  bool select(String id) {
    final bool exists = _servers.any((ServerProfile server) => server.id == id);
    if (exists) {
      _selectedServerId = id;
    }
    return exists;
  }

  Future<ServerProfile> updateLatency(
    ServerProfile profile, {
    LatencyCheckOptions? options,
  }) async {
    final result = await _latencyChecker.checkLatency(
      profile,
      options: options,
    );
    final ServerProfile updated = profile.copyWith(
      latencyMs: result.success ? result.latencyMs : 9999,
    );
    upsert(updated);
    return updated;
  }

  Future<void> refreshAllLatencies({
    LatencyCheckOptions? options,
    int maxConcurrent = 5,
  }) async {
    final results = await _latencyChecker.checkMultipleServers(
      List<ServerProfile>.from(_servers),
      maxConcurrent: maxConcurrent,
    );

    for (final result in results) {
      final index = _servers.indexWhere((s) => s.id == result.server.id);
      if (index >= 0) {
        _servers[index] = _servers[index].copyWith(
          latencyMs: result.success ? result.latencyMs : 9999,
        );
      }
    }

    _servers.sort((ServerProfile a, ServerProfile b) {
      final int la = a.latencyMs ?? 9999;
      final int lb = b.latencyMs ?? 9999;
      return la.compareTo(lb);
    });
  }

  void clearLatencyCache() {
    _latencyChecker.clearCache();
  }
}
