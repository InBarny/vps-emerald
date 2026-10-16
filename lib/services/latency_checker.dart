// lib/services/latency_checker.dart
import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/logging/session_logger.dart';
import '../vpn/models/server_models.dart';

/// Result of a latency check operation
class LatencyResult {
  final ServerProfile server;
  final int latencyMs;
  final LatencyCheckMethod method;
  final DateTime timestamp;
  final bool success;
  final String? errorMessage;

  const LatencyResult({
    required this.server,
    required this.latencyMs,
    required this.method,
    required this.timestamp,
    required this.success,
    this.errorMessage,
  });

  @override
  String toString() => success
      ? 'LatencyResult(server: ${server.name}, latency: ${latencyMs}ms, method: $method)'
      : 'LatencyResult(server: ${server.name}, failed: $errorMessage)';
}

/// Options for latency checking
class LatencyCheckOptions {
  final Duration timeout;
  final int maxRetries;
  final List<String> testEndpoints;
  final LatencyCheckMethod preferredMethod;
  final bool cacheResults;
  final Duration cacheDuration;

  const LatencyCheckOptions({
    this.timeout = const Duration(seconds: 5),
    this.maxRetries = 2,
    this.testEndpoints = const [],
    this.preferredMethod = LatencyCheckMethod.tcpConnect,
    this.cacheResults = true,
    this.cacheDuration = const Duration(minutes: 2),
  });

  factory LatencyCheckOptions.defaultOptions() => const LatencyCheckOptions(
    preferredMethod: LatencyCheckMethod.tcpConnect,
  );

  LatencyCheckOptions copyWith({
    Duration? timeout,
    int? maxRetries,
    List<String>? testEndpoints,
    LatencyCheckMethod? preferredMethod,
    bool? cacheResults,
    Duration? cacheDuration,
  }) {
    return LatencyCheckOptions(
      timeout: timeout ?? this.timeout,
      maxRetries: maxRetries ?? this.maxRetries,
      testEndpoints: testEndpoints ?? this.testEndpoints,
      preferredMethod: preferredMethod ?? this.preferredMethod,
      cacheResults: cacheResults ?? this.cacheResults,
      cacheDuration: cacheDuration ?? this.cacheDuration,
    );
  }
}

/// Method used for latency checking
enum LatencyCheckMethod { httpHead, icmpPing, tcpConnect }

/// Abstract interface for latency checking
abstract class LatencyChecker {
  Future<LatencyResult> checkLatency(
    ServerProfile server, {
    LatencyCheckOptions? options,
  });

  Future<List<LatencyResult>> checkMultipleServers(
    List<ServerProfile> servers, {
    int maxConcurrent = 5,
  });

  void clearCache();
}

/// Default implementation of LatencyChecker with multi-strategy support
class DefaultLatencyChecker implements LatencyChecker {
  DefaultLatencyChecker({required SessionLogger logger})
    : _logger = logger,
      _httpClient = http.Client();

  final http.Client _httpClient;
  final SessionLogger _logger;
  final Map<String, _CachedLatency> _cache = {};

  static const List<String> _defaultEndpoints = [
    'http://cp.cloudflare.com/generate_200',
    'http://1.1.1.1/cdn-cgi/trace',
    'http://clients3.google.com/generate_204',
  ];

  @override
  Future<LatencyResult> checkLatency(
    ServerProfile server, {
    LatencyCheckOptions? options,
  }) async {
    final opts = options ?? LatencyCheckOptions.defaultOptions();
    final cacheKey = '${server.id}_${opts.preferredMethod.name}';

    // Check cache first
    if (opts.cacheResults && _cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < opts.cacheDuration) {
        _logger.debug(
          'Latency cache hit for ${server.name}: ${cached.result.latencyMs}ms',
        );
        return cached.result;
      }
    }

    // Try each attempt
    for (int attempt = 0; attempt <= opts.maxRetries; attempt++) {
      try {
        final result = await _measureLatency(server, opts);
        if (result.success) {
          if (opts.cacheResults) {
            _cache[cacheKey] = _CachedLatency(result, DateTime.now());
          }
          _logger.info(
            'Latency check for ${server.name}: ${result.latencyMs}ms via ${result.method.name}',
          );
          return result;
        }
      } catch (e) {
        _logger.debug(
          'Latency check attempt ${attempt + 1} failed for ${server.name}: $e',
        );
      }
    }

    return LatencyResult(
      server: server,
      latencyMs: 9999,
      method: opts.preferredMethod,
      timestamp: DateTime.now(),
      success: false,
      errorMessage: 'All retry attempts failed',
    );
  }

  @override
  Future<List<LatencyResult>> checkMultipleServers(
    List<ServerProfile> servers, {
    int maxConcurrent = 5,
  }) async {
    if (servers.isEmpty) return [];

    final results = <LatencyResult>[];
    final semaphore = _Semaphore(maxConcurrent);

    final futures = servers.map((server) async {
      await semaphore.acquire();
      try {
        final result = await checkLatency(server);
        results.add(result);
      } finally {
        semaphore.release();
      }
    });

    await Future.wait(futures);

    // Sort by latency ascending
    return results..sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
  }

  @override
  void clearCache() {
    _cache.clear();
    _logger.debug('Latency cache cleared');
  }

  Future<LatencyResult> _measureLatency(
    ServerProfile server,
    LatencyCheckOptions opts,
  ) async {
    switch (opts.preferredMethod) {
      case LatencyCheckMethod.httpHead:
        return _httpHeadCheck(server, opts);
      case LatencyCheckMethod.icmpPing:
        return _icmpCheck(server, opts);
      case LatencyCheckMethod.tcpConnect:
        return _tcpCheck(server, opts);
    }
  }

  Future<LatencyResult> _httpHeadCheck(
    ServerProfile server,
    LatencyCheckOptions opts,
  ) async {
    final endpoints = opts.testEndpoints.isNotEmpty
        ? opts.testEndpoints
        : _defaultEndpoints;

    for (final endpoint in endpoints) {
      final stopwatch = Stopwatch()..start();
      try {
        final response = await _httpClient
            .head(Uri.parse(endpoint))
            .timeout(opts.timeout);
        stopwatch.stop();
        if (response.statusCode == 200) {
          return LatencyResult(
            server: server,
            latencyMs: stopwatch.elapsedMilliseconds,
            method: LatencyCheckMethod.httpHead,
            timestamp: DateTime.now(),
            success: true,
          );
        }
      } catch (_) {
        // Try next endpoint
        continue;
      }
    }

    return LatencyResult(
      server: server,
      latencyMs: 9999,
      method: LatencyCheckMethod.httpHead,
      timestamp: DateTime.now(),
      success: false,
      errorMessage: 'All HTTP endpoints failed',
    );
  }

  Future<LatencyResult> _icmpCheck(
    ServerProfile server,
    LatencyCheckOptions opts,
  ) async {
    // ICMP ping requires platform-specific implementation
    // On most platforms, this requires elevated privileges
    // For cross-platform support, we fall back to TCP connect
    try {
      final result = await _invokePlatformIcmp(
        server.host,
        timeout: opts.timeout,
      );
      return LatencyResult(
        server: server,
        latencyMs: result.round(),
        method: LatencyCheckMethod.icmpPing,
        timestamp: DateTime.now(),
        success: true,
      );
    } catch (e) {
      return LatencyResult(
        server: server,
        latencyMs: 9999,
        method: LatencyCheckMethod.icmpPing,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: 'ICMP not available: $e',
      );
    }
  }

  Future<LatencyResult> _tcpCheck(
    ServerProfile server,
    LatencyCheckOptions opts,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      final socket = await Socket.connect(
        server.host,
        server.port,
        timeout: opts.timeout,
      );
      stopwatch.stop();
      socket.destroy();
      return LatencyResult(
        server: server,
        latencyMs: stopwatch.elapsedMilliseconds,
        method: LatencyCheckMethod.tcpConnect,
        timestamp: DateTime.now(),
        success: true,
      );
    } catch (e) {
      stopwatch.stop();
      return LatencyResult(
        server: server,
        latencyMs: 9999,
        method: LatencyCheckMethod.tcpConnect,
        timestamp: DateTime.now(),
        success: false,
        errorMessage: 'TCP connect failed: $e',
      );
    }
  }

  Future<double> _invokePlatformIcmp(
    String host, {
    required Duration timeout,
  }) async {
    // Platform channel integration point for native ICMP
    // This would be implemented via platform channels on each platform
    // For now, throw to indicate not available
    throw UnimplementedError(
      'ICMP ping requires platform channel implementation',
    );
  }
}

/// Cache entry for latency results
class _CachedLatency {
  final LatencyResult result;
  final DateTime timestamp;
  _CachedLatency(this.result, this.timestamp);
}

/// Semaphore for limiting concurrent operations
class _Semaphore {
  int _permits;
  final List<void Function()> _waitQueue = [];

  _Semaphore(this._permits);

  Future<void> acquire() async {
    if (_permits > 0) {
      _permits--;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer.complete);
    await completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final resolve = _waitQueue.removeAt(0);
      resolve();
    } else {
      _permits++;
    }
  }
}

/// Factory for creating latency checker based on platform
class LatencyCheckerFactory {
  static LatencyChecker create({required SessionLogger logger}) {
    return DefaultLatencyChecker(logger: logger);
  }

  static LatencyCheckMethod suggestMethodForPlatform() {
    return LatencyCheckMethod.tcpConnect;
  }
}
