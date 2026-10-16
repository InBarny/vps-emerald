import '../../vpn/models/server_models.dart';

/// Split tunnel state for managing split tunneling rules, excluded domains, and domain overrides
sealed class SplitTunnelState {
  const SplitTunnelState();
}

class SplitTunnelInitial extends SplitTunnelState {
  const SplitTunnelInitial();
}

class SplitTunnelLoaded extends SplitTunnelState {
  final SplitTunnelMode mode;
  final Set<String> selectedApps;
  final List<String> excludedDomains;
  final List<DomainOverride> domainOverrides;
  final bool isLoadingApps;

  const SplitTunnelLoaded({
    required this.mode,
    required this.selectedApps,
    required this.excludedDomains,
    required this.domainOverrides,
    this.isLoadingApps = false,
  });

  bool get isEnabled => mode != SplitTunnelMode.disabled;
  int get selectedAppCount => selectedApps.length;
  int get domainOverrideCount => domainOverrides.length;

  SplitTunnelLoaded copyWith({
    SplitTunnelMode? mode,
    Set<String>? selectedApps,
    List<String>? excludedDomains,
    List<DomainOverride>? domainOverrides,
    bool? isLoadingApps,
  }) {
    return SplitTunnelLoaded(
      mode: mode ?? this.mode,
      selectedApps: selectedApps ?? this.selectedApps,
      excludedDomains: excludedDomains ?? this.excludedDomains,
      domainOverrides: domainOverrides ?? this.domainOverrides,
      isLoadingApps: isLoadingApps ?? this.isLoadingApps,
    );
  }
}

class SplitTunnelError extends SplitTunnelState {
  final String message;
  const SplitTunnelError({required this.message});
}
