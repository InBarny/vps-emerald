import '../../vpn/models/server_models.dart';

/// Server state for managing server list and selection
sealed class ServerState {
  const ServerState();
}

class ServerInitial extends ServerState {
  const ServerInitial();
}

class ServerLoading extends ServerState {
  const ServerLoading();
}

class ServerLoaded extends ServerState {
  final List<ServerProfile> servers;
  final ServerProfile? selectedServer;
  final bool isRefreshing;

  const ServerLoaded({
    required this.servers,
    this.selectedServer,
    this.isRefreshing = false,
  });

  ServerLoaded copyWith({
    List<ServerProfile>? servers,
    ServerProfile? selectedServer,
    bool? isRefreshing,
  }) {
    return ServerLoaded(
      servers: servers ?? this.servers,
      selectedServer: selectedServer ?? this.selectedServer,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

class ServerError extends ServerState {
  final String message;
  const ServerError({required this.message});
}
