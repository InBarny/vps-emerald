import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../logging/session_logger.dart';
import '../../vpn/vpn_interface.dart';
import '../../vpn/vpn_status.dart' as status;
import '../../vpn/models/server_models.dart';
import '../../vpn/config/config_generator.dart';
import '../../vpn/services/singbox_binary_service.dart';
import '../../vpn/windows_vpn.dart';
import '../errors/vpn_error.dart';

import 'vpn_state.dart';

/// VpnCubit manages VPN connection state using ChangeNotifier pattern
/// (simplified implementation without flutter_bloc dependency)
class VpnCubit extends ChangeNotifier {
  VpnCubit({required SessionLogger logger})
    : _logger = logger,
      _vpn = _buildVpn(logger);

  final SessionLogger _logger;
  final VpnInterface _vpn;
  StreamSubscription<status.VpnStatus>? _vpnSubscription;

  VpnCubitState _state = const VpnInitial();
  VpnCubitState get state => _state;

  String? _lastErrorMessage;
  String? get lastErrorMessage => _lastErrorMessage;

  void _setState(VpnCubitState newState) {
    _state = newState;
    notifyListeners();
  }

  static VpnInterface _buildVpn(SessionLogger logger) {
    if (Platform.isWindows) {
      return WindowsVpn(
        configGenerator: SingBoxConfigGenerator(),
        binaryService: SingBoxBinaryService(),
        logger: logger,
      );
    }
    throw VpnError(VpnErrorKind.platformUnsupported, 'Unsupported platform');
  }

  void initialize() {
    _vpnSubscription = _vpn.statusStream().listen((status) {
      _setState(status.toCubitState());
    });
  }

  Future<void> connect({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  }) async {
    _lastErrorMessage = null;
    try {
      _setState(const VpnConnecting());
      await _vpn.connect(
        server: server,
        splitTunnel: splitTunnel,
        albaniaProxy: albaniaProxy,
      );
    } on VpnError catch (error) {
      _lastErrorMessage = error.message;
      _logger.error(error.toString());
      _setState(VpnErrorState(message: error.message));
    } catch (error) {
      _lastErrorMessage = error.toString();
      _setState(VpnErrorState(message: _lastErrorMessage!));
    }
  }

  Future<void> disconnect() async {
    _setState(const VpnDisconnecting());
    await _vpn.disconnect();
    _setState(const VpnDisconnectedState());
  }

  status.VpnStatus get currentStatus => _vpn.getStatus();

  @override
  void dispose() {
    _vpnSubscription?.cancel();
    super.dispose();
  }
}
