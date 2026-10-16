import '../config/app_config.dart';
import 'backend_api_service.dart';

/// API client for 3X-UI panel (v3.x) через backend прокси.
/// Все секретные ключи хранятся на сервере.
class X3UIApi {
  final BackendApiService _backend;

  X3UIApi()
    : _backend = BackendApiService(
        baseUrl: AppConfig.apiBaseUrl,
        appToken: AppConfig.appToken,
      );

  // ── clients ───────────────────────────────────────────────────

  /// List every client with attached inbound IDs and traffic record.
  Future<List<ClientInfo>> listClients() async {
    final result = await _backend.getClientStatus(''); // backend возвращает список
    final list = result?['obj'] as List<dynamic>? ?? [];
    return list.map((e) => ClientInfo.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Check whether a promo client (email starting with 'emerald_promo') already exists.
  Future<bool> hasPromoClient() async {
    return _backend.hasPromoClient();
  }

  /// Get one client by email.
  Future<ClientInfo?> getClient(String email) async {
    try {
      final result = await _backend.getClientStatus(email);
      if (result == null) return null;
      final client = result['client'] as Map<String, dynamic>?;
      if (client != null) return ClientInfo.fromJson(client);
      // Fallback: result itself may be the client
      return ClientInfo.fromJson(result);
    } catch (_) {
      return null;
    }
  }

  /// Create a new client attached to given inbounds.
  Future<bool> addClient({
    required String email,
    required String uuid,
    required List<int> inboundIds,
    int totalGB = 0,
    required int expiryTimeMs,
    String? subId,
    bool enable = true,
    String? comment,
  }) async {
    final days = ((expiryTimeMs - DateTime.now().millisecondsSinceEpoch) / 86400000).ceil();
    final result = await _backend.createClient(
      email: email,
      days: days.clamp(1, 365),
      uuid: uuid,
      inboundIds: inboundIds,
      totalGb: totalGB,
      subId: subId,
    );
    return result?['success'] == true;
  }

  /// Update an existing client (extend expiry / change limits).
  Future<bool> updateClient({
    required String email,
    int? totalGB,
    int? expiryTimeMs,
    bool? enable,
  }) async {
    final result = await _backend.extendClient(
      email: email,
      newExpireMs: expiryTimeMs ?? DateTime.now().add(const Duration(days: 30)).millisecondsSinceEpoch,
      totalGb: totalGB,
    );
    return result?['success'] == true;
  }

  /// Delete a client by email.
  Future<bool> deleteClient(String email) async {
    // TODO: добавить endpoint /api/v1/client/delete на backend
    return false;
  }

  // ── inbounds ──────────────────────────────────────────────────

  /// List all inbounds with their client stats.
  Future<List<InboundInfo>> listInbounds() async {
    final raw = await _backend.listInbounds();
    if (raw == null) return [];
    return raw.map((e) => InboundInfo.fromJson(e)).toList();
  }

  /// Lightweight inbound list for pickers.
  Future<List<InboundOption>> listInboundOptions() async {
    final inbounds = await listInbounds();
    return inbounds
        .map(
          (i) => InboundOption(
            id: i.id,
            remark: i.remark,
            protocol: i.protocol,
            port: i.port,
            tlsFlowCapable: false,
            enable: i.enable,
          ),
        )
        .toList();
  }

  // ── subscription link ────────────────────────────────────────────

  /// Build subscription URL for a client by subId.
  String getSubscriptionUrl(String subId) {
    return '${AppConfig.subscriptionBaseUrl}/aL9xK3mP/${Uri.encodeComponent(subId)}';
  }

  /// Get raw subscription content.
  Future<String?> fetchSubscriptionContent(String subId) async {
    // TODO: добавить endpoint для получения raw подписки
    return null;
  }

  // ── utility ───────────────────────────────────────────────────

  /// Generate a fresh UUID v4 from the server.
  Future<String?> getNewUuid() async {
    return _backend.getNewUuid();
  }

  void dispose() => _backend.dispose();
}

// ── models ───────────────────────────────────────────────────────

class InboundInfo {
  final int id;
  final String remark;
  final String protocol;
  final int port;
  final bool enable;

  InboundInfo({
    required this.id,
    required this.remark,
    required this.protocol,
    required this.port,
    required this.enable,
  });

  factory InboundInfo.fromJson(Map<String, dynamic> json) => InboundInfo(
        id: json['id'] ?? 0,
        remark: json['remark'] ?? '',
        protocol: json['protocol'] ?? '',
        port: json['port'] ?? 0,
        enable: json['enable'] ?? false,
      );
}

class InboundOption {
  final int id;
  final String remark;
  final String protocol;
  final int port;
  final bool tlsFlowCapable;
  final bool enable;

  InboundOption({
    required this.id,
    required this.remark,
    required this.protocol,
    required this.port,
    required this.tlsFlowCapable,
    required this.enable,
  });

  factory InboundOption.fromJson(Map<String, dynamic> json) => InboundOption(
        id: json['id'] ?? 0,
        remark: json['remark'] ?? '',
        protocol: json['protocol'] ?? '',
        port: json['port'] ?? 0,
        tlsFlowCapable: json['tlsFlowCapable'] ?? false,
        enable: json['enable'] ?? true,
      );
}

class ClientInfo {
  final int id;
  final String email;
  final String? subId;
  final String? uuid;
  final int totalGB;
  final int expiryTime;
  final bool enable;
  final List<int> inboundIds;
  final ClientTraffic? traffic;

  ClientInfo({
    required this.id,
    required this.email,
    this.subId,
    this.uuid,
    required this.totalGB,
    required this.expiryTime,
    required this.enable,
    required this.inboundIds,
    this.traffic,
  });

  factory ClientInfo.fromJson(Map<String, dynamic> json) => ClientInfo(
        id: json['id'] ?? 0,
        email: json['email'] ?? '',
        subId: json['subId'],
        uuid: json['uuid'],
        totalGB: json['totalGB'] ?? 0,
        expiryTime: json['expiryTime'] ?? 0,
        enable: json['enable'] ?? false,
        inboundIds: (json['inboundIds'] as List<dynamic>? ?? []).cast<int>(),
        traffic: json['traffic'] == null
            ? null
            : ClientTraffic.fromJson(json['traffic'] as Map<String, dynamic>),
      );

  /// Expiry as DateTime.
  DateTime? get expiryDate =>
      expiryTime > 0 ? DateTime.fromMillisecondsSinceEpoch(expiryTime) : null;

  /// True if expired.
  bool get isExpired =>
      expiryTime > 0 && DateTime.now().millisecondsSinceEpoch > expiryTime;
}

class ClientTraffic {
  final int up;
  final int down;
  final bool enable;

  ClientTraffic({required this.up, required this.down, required this.enable});

  factory ClientTraffic.fromJson(Map<String, dynamic> json) => ClientTraffic(
        up: json['up'] ?? 0,
        down: json['down'] ?? 0,
        enable: json['enable'] ?? false,
      );
}
