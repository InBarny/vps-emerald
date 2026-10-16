enum VpnState { disconnected, connecting, connected, disconnecting, error }

class VpnStatus {
  const VpnStatus({required this.state, this.message});

  final VpnState state;
  final String? message;

  VpnStatus copyWith({VpnState? state, String? message}) {
    return VpnStatus(
      state: state ?? this.state,
      message: message ?? this.message,
    );
  }
}
