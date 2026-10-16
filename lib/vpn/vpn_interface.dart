import 'models/server_models.dart';
import 'vpn_status.dart';

abstract class VpnInterface {
  /// Initialize VPN subsystem
  void initialize();

  /// Connect to VPN with server profile and split tunnel settings
  Future<void> connect({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  });

  /// Disconnect gracefully, allowing cleanup
  Future<void> disconnect();

  /// Force immediate disconnect without cleanup
  Future<void> forceDisconnect();

  /// Pause connection while preserving session state
  Future<void> pauseConnection();

  /// Reconnect with previous session or fresh connection
  Future<void> reconnect();

  VpnStatus getStatus();

  Stream<VpnStatus> statusStream();
}
