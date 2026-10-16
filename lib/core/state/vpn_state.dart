import '../../vpn/vpn_status.dart' as status;

/// States for VpnCubit - these represent the VPN connection states
/// Renamed from VpnState to avoid conflict with the enum in vpn_status.dart
sealed class VpnCubitState {
  const VpnCubitState();
}

class VpnInitial extends VpnCubitState {
  const VpnInitial();
}

class VpnConnecting extends VpnCubitState {
  const VpnConnecting();
}

class VpnConnectedState extends VpnCubitState {
  final DateTime connectedAt;
  const VpnConnectedState({required this.connectedAt});
}

class VpnDisconnecting extends VpnCubitState {
  const VpnDisconnecting();
}

class VpnDisconnectedState extends VpnCubitState {
  const VpnDisconnectedState();
}

class VpnReconnecting extends VpnCubitState {
  const VpnReconnecting();
}

class VpnErrorState extends VpnCubitState {
  final String message;
  const VpnErrorState({required this.message});
}

/// Extension to create VpnCubitState from VpnStatus
extension VpnStatusExtension on status.VpnStatus {
  VpnCubitState toCubitState() {
    switch (state) {
      case status.VpnState.disconnected:
        return const VpnDisconnectedState();
      case status.VpnState.connecting:
        return const VpnConnecting();
      case status.VpnState.connected:
        return VpnConnectedState(connectedAt: DateTime.now());
      case status.VpnState.disconnecting:
        return const VpnDisconnecting();
      case status.VpnState.error:
        return VpnErrorState(message: message ?? 'Unknown error');
    }
  }
}
