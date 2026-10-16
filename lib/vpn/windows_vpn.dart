// lib/vpn/windows_vpn.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/errors/vpn_error.dart';
import '../core/logging/session_logger.dart';
import 'config/config_generator.dart';
import 'models/server_models.dart';
import 'services/singbox_binary_service.dart';
import 'vpn_interface.dart';
import 'vpn_status.dart';

class _TunInterfaceInfo {
  _TunInterfaceInfo({required this.isActive, required this.interfaceName});
  final bool isActive;
  final String interfaceName;

  @override
  String toString() =>
      'TunInterfaceInfo(active: $isActive, name: $interfaceName)';
}

class WindowsVpn implements VpnInterface {
  WindowsVpn({
    required this.configGenerator,
    required this.binaryService,
    required this.logger,
  }) : _status = const VpnStatus(state: VpnState.disconnected);

  final SingBoxConfigGenerator configGenerator;
  final SingBoxBinaryService binaryService;
  final SessionLogger logger;

  final StreamController<VpnStatus> _statusController =
      StreamController<VpnStatus>.broadcast();
  Process? _process;
  String? _configPath;
  VpnStatus _status;
  String _lastStderr = '';
  Timer? _connectionCheckTimer;
  Timer? _healthCheckTimer;

  // Reconnection settings
  static const int _maxReconnectAttempts = 3;
  static const Duration _reconnectDelay = Duration(seconds: 2);
  int _reconnectAttempts = 0;
  ServerProfile? _lastServer;
  SplitTunnelSettings? _lastSplitTunnel;

  // Добавьте в WindowsVpn:
  Future<bool> _testConnectivity() async {
    try {
      final result = await Process.run('curl', [
        '-s',
        '-o',
        'NUL',
        '-w',
        '%{http_code}',
        '--connect-timeout',
        '5',
        'http://cp.cloudflare.com/generate_200',
      ], runInShell: true);
      return result.stdout.toString().trim() == '200';
    } catch (_) {
      return false;
    }
  }

  /// Проверяет, запущено ли приложение с правами администратора.
  static Future<bool> isAdmin() async {
    if (!Platform.isWindows) return true;
    try {
      final result = await Process.run('powershell', [
        '-Command',
        '(New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)',
      ], runInShell: true);
      return result.exitCode == 0 &&
          result.stdout.toString().trim().toLowerCase() == 'true';
    } catch (_) {
      return false;
    }
  }

  @override
  void initialize() {
    // Windows VPN doesn't require explicit initialization
    logger.info('WindowsVpn initialized');
  }

  /// Гарантированно останавливает все процессы sing-box.exe в системе.
  Future<void> _killExistingSingBox() async {
    try {
      if (_process != null) {
        _process!.kill(ProcessSignal.sigkill);
        try {
          await _process!.exitCode.timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              _process!.kill(ProcessSignal.sigkill);
              return -1;
            },
          );
        } catch (_) {}
        _process = null;
      }
      await Process.run('taskkill', ['/F', '/IM', 'sing-box.exe']);
    } catch (e) {
      logger.debug('No existing sing-box processes to kill: $e');
    }
  }

  @override
  Future<void> connect({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  }) async {
    if (!Platform.isWindows) {
      throw VpnError(
        VpnErrorKind.platformUnsupported,
        'WindowsVpn is only available on Windows',
      );
    }

    if (!await isAdmin()) {
      throw VpnError(
        VpnErrorKind.permissions,
        'Administrator privileges are required to create a VPN tunnel.\nPlease restart the application as Administrator.',
      );
    }

    // Сохраняем параметры для возможного переподключения
    _lastServer = server;
    _lastSplitTunnel = splitTunnel;
    _reconnectAttempts = 0;

    await _killExistingSingBox();

    if (_process != null) return;

    _setStatus(
      const VpnStatus(
        state: VpnState.connecting,
        message: 'Starting sing-box...',
      ),
    );
    _lastStderr = '';

    // Мягкая очистка старых TUN-адаптеров
    await _cleanupOldAdapters();

    try {
      // Debug trace to understand why sing-box config generation fails.
      // This is especially important for Reality (VLESS+Reality) parameters.
      logger.info('=== VPN Connection Starting (debug) ===');
      logger.debug('Server selected: id=${server.id}, name=${server.name}');
      logger.debug(
        'Server endpoint: ${server.host}:${server.port}, uuid=${server.uuid}',
      );
      logger.debug(
        'Reality: serverName=${server.reality.serverName}, fingerprint=${server.reality.fingerprint}',
      );
      logger.debug(
        'Reality publicKey present: ${server.reality.publicKey.isNotEmpty} (len=${server.reality.publicKey.length})',
      );
      logger.debug('Reality shortId=${server.reality.shortId}');

      final String configJson = configGenerator.generateVlessRealityConfig(
        server: server,
        splitTunnel: splitTunnel,
        albaniaProxy: albaniaProxy,
      );

      logger.debug(
        'Generated config JSON (truncated): ${configJson.length > 800 ? configJson.substring(0, 800) + '...' : configJson}',
      );

      logger.info('Preparing sing-box binary...');
      final SingBoxRuntimeFiles runtimeFiles = await binaryService
          .prepareRuntimeBinaryFromAssets(
            descriptor: binaryService.resolveForCurrentPlatform(),
          );
      logger.info('Binary path: ${runtimeFiles.binaryPath}');

      final String binaryDir = File(runtimeFiles.binaryPath).parent.path;
      final File configFile = File(
        '$binaryDir${Platform.pathSeparator}vps_emerald_singbox.json',
      );
      await configFile.writeAsString(configJson);
      _configPath = configFile.path;
      logger.info('Config written to: ${configFile.path}');

      logger.info('Starting sing-box process...');
      _process = await Process.start(
        runtimeFiles.binaryPath,
        <String>['run', '-c', configFile.path],
        workingDirectory: binaryDir,
        runInShell: false,
      );
      logger.info('sing-box PID: ${_process!.pid}');

      _process!.stdout.transform(utf8.decoder).listen(_onLogLine);
      _process!.stderr.transform(utf8.decoder).listen(_onStderrLine);
      unawaited(_watchExit(_process!));

      // Запускаем проверку подключения
      _startConnectionCheck();
      // Health check отключён для снижения фоновой активности
      // _startHealthCheck();
    } on VpnError {
      rethrow;
    } catch (error, stackTrace) {
      logger.error('Failed to start VPN: $error');
      logger.error('Stack trace: $stackTrace');
      _setStatus(
        VpnStatus(
          state: VpnState.error,
          message: 'Failed to start VPN: $error',
        ),
      );
      throw VpnError(
        VpnErrorKind.processStart,
        'Failed to start sing-box',
        details: error,
      );
    }
  }

  Future<void> _cleanupOldAdapters() async {
    try {
      // Clean up both 'vps-*' and '*singbox*' adapters
      await Process.run('powershell', [
        r'Get-NetAdapter | Where-Object { $_.Name -like "vps-*" -or $_.Name -like "*singbox*" } | Remove-NetAdapter -Confirm:$false -ErrorAction SilentlyContinue',
      ]);
    } catch (e) {
      logger.warning('Failed to clean old TUN adapters: $e');
    }
  }

  void _startConnectionCheck() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (
      timer,
    ) async {
      if (_process == null) {
        timer.cancel();
        return;
      }

      final tunInfo = await _getTunInterfaceInfo();
      // Логируем только при смене состояния
      if (tunInfo.isActive && _status.state == VpnState.connecting) {
        logger.info('TUN interface is active - VPN connected!');
        _setStatus(VpnStatus(state: VpnState.connected, message: 'Connected'));
        _reconnectAttempts = 0;
      } else if (!tunInfo.isActive && _status.state == VpnState.connected) {
        logger.warning('TUN interface lost - attempting reconnect');
        _handleConnectionLoss();
      }
    });
  }

  void _handleConnectionLoss() {
    if (_reconnectAttempts < _maxReconnectAttempts &&
        _lastServer != null &&
        _lastSplitTunnel != null) {
      _reconnectAttempts++;
      logger.info(
        'Attempting reconnection ($_reconnectAttempts/$_maxReconnectAttempts)...',
      );

      _setStatus(
        VpnStatus(
          state: VpnState.connecting,
          message:
              'Reconnecting... ($_reconnectAttempts/$_maxReconnectAttempts)',
        ),
      );

      // Wait and then try to reconnect
      Future.delayed(_reconnectDelay * _reconnectAttempts, () async {
        if (_process == null &&
            _lastServer != null &&
            _lastSplitTunnel != null) {
          try {
            await connect(
              server: _lastServer!,
              splitTunnel: _lastSplitTunnel!,
              albaniaProxy: null,
            );
          } catch (e) {
            logger.error('Reconnection failed: $e');
          }
        }
      });
    } else {
      _setStatus(
        const VpnStatus(
          state: VpnState.error,
          message: 'Connection lost. Please reconnect manually.',
        ),
      );
    }
  }

  _TunInterfaceInfo _tunInfoCache = _TunInterfaceInfo(
    isActive: false,
    interfaceName: '',
  );

  Future<_TunInterfaceInfo> _getTunInterfaceInfo() async {
    try {
      // Check for both 'vps-*' (our naming) and 'singbox-tun' (sing-box default naming)
      final result = await Process.run('powershell', [
        r'Get-NetAdapter | Where-Object { ($_.Name -like "vps-*" -or $_.Name -like "*singbox*") -and $_.Status -eq "Up" } | Select-Object -Property Name,MacAddress | ConvertTo-Json -Compress',
      ]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty && output != 'null') {
          logger.debug('Found TUN adapter: $output');
          final nameMatch = RegExp(
            r'"Name"\s*:\s*"([^"]+)"',
          ).firstMatch(output);
          final name = nameMatch?.group(1) ?? 'vpn-tun';
          _tunInfoCache = _TunInterfaceInfo(
            isActive: true,
            interfaceName: name,
          );
          return _tunInfoCache;
        }
      }

      _tunInfoCache = _TunInterfaceInfo(isActive: false, interfaceName: '');
      return _tunInfoCache;
    } catch (e) {
      logger.error('TUN interface check failed: $e');
      _tunInfoCache = _TunInterfaceInfo(isActive: false, interfaceName: '');
      return _tunInfoCache;
    }
  }

  void _onStderrLine(String chunk) {
    _lastStderr += chunk;
    _onLogLine(chunk, isStderr: true);
  }

  void _onLogLine(String chunk, {bool isStderr = false}) {
    final List<String> lines = chunk
        .split('\n')
        .map((String line) => line.trim())
        .where((String line) => line.isNotEmpty)
        .toList();

    for (final String line in lines) {
      // Игнорируем спам о закрытии соединений
      if (line.contains('connection upload closed') ||
          line.contains('connection download closed') ||
          line.contains('dns: exchange')) {
        continue;
      }

      final lower = line.toLowerCase();

      // ✅ ТЕПЕРЬ ЛОГИРУЕМ ВСЁ, чтобы видеть, что происходит в ядре
      if (lower.contains('fatal') ||
          lower.contains('panic') ||
          lower.contains('error')) {
        logger.error('[sing-box] $line');
        if (lower.contains('fatal') || lower.contains('panic')) {
          _setStatus(VpnStatus(state: VpnState.error, message: line));
        }
      } else if (lower.contains('warn')) {
        logger.warning('[sing-box] $line');
      } else {
        // Выводим INFO и DEBUG логи ядра в консоль Flutter
        logger.info('[sing-box] $line');
      }
    }
  }

  Future<void> _watchExit(Process process) async {
    final int code = await process.exitCode;
    _process = null;
    _connectionCheckTimer?.cancel();
    _healthCheckTimer?.cancel();

    if (_status.state == VpnState.disconnecting ||
        _status.state == VpnState.disconnected) {
      _setStatus(const VpnStatus(state: VpnState.disconnected));
      return;
    }

    logger.error('sing-box exited with code $code');
    final String errorMsg = _lastStderr.isNotEmpty
        ? 'sing-box exited unexpectedly (code $code)\n$_lastStderr'
        : 'sing-box exited unexpectedly (code $code)';

    // Attempt reconnection instead of just showing error
    _setStatus(VpnStatus(state: VpnState.error, message: errorMsg));
    _handleConnectionLoss();
  }

  @override
  Future<void> disconnect() async {
    _connectionCheckTimer?.cancel();
    _healthCheckTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts; // Prevent auto-reconnect

    if (_process == null) {
      _setStatus(const VpnStatus(state: VpnState.disconnected));
      return;
    }

    _setStatus(
      const VpnStatus(
        state: VpnState.disconnecting,
        message: 'Stopping sing-box...',
      ),
    );
    final Process process = _process!;
    process.kill(ProcessSignal.sigkill);

    final int code = await process.exitCode.timeout(
      const Duration(seconds: 3),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
    logger.info('sing-box process stopped with code $code');
    _process = null;
    _setStatus(const VpnStatus(state: VpnState.disconnected));
  }

  @override
  Future<void> forceDisconnect() async {
    _connectionCheckTimer?.cancel();
    _healthCheckTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts;

    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigkill);
      } catch (_) {}
      _process = null;
    }

    _setStatus(const VpnStatus(state: VpnState.disconnected));
  }

  @override
  Future<void> pauseConnection() async {
    // For Windows, pause is not fully supported
    // Just mark the state and preserve for reconnection
    _reconnectAttempts = _maxReconnectAttempts;
    logger.info('Pause requested - preserving session state');
  }

  @override
  Future<void> reconnect() async {
    if (_lastServer != null && _lastSplitTunnel != null) {
      _reconnectAttempts = 0;
      await connect(
        server: _lastServer!,
        splitTunnel: _lastSplitTunnel!,
        albaniaProxy: null,
      );
    } else {
      logger.warning('Cannot reconnect - no saved server state');
    }
  }

  @override
  VpnStatus getStatus() => _status;

  @override
  Stream<VpnStatus> statusStream() => _statusController.stream;

  void _setStatus(VpnStatus status) {
    _status = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    _connectionCheckTimer?.cancel();
    _healthCheckTimer?.cancel();
    _reconnectAttempts = _maxReconnectAttempts; // Prevent auto-reconnect
    if (_process != null) {
      await disconnect();
    }
    if (_configPath != null) {
      final File configFile = File(_configPath!);
      if (await configFile.exists()) {
        await configFile.delete();
      }
    }
    await _statusController.close();
  }
}
