enum SplitTunnelMode { disabled, includeOnlySelectedApps, excludeSelectedApps }

class RealitySettings {
  const RealitySettings({
    required this.publicKey,
    required this.shortId,
    required this.serverName,
    this.fingerprint = 'chrome',
  });

  final String publicKey;
  final String shortId;
  final String serverName;
  final String fingerprint;
}

class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.uuid,
    required this.reality,
    this.flow = 'xtls-rprx-vision',
    this.latencyMs,
  });

  final String id;
  final String name;
  final String host;
  final int port;
  final String uuid;
  final String flow;
  final RealitySettings reality;
  final int? latencyMs;

  ServerProfile copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    String? uuid,
    String? flow,
    RealitySettings? reality,
    int? latencyMs,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      uuid: uuid ?? this.uuid,
      flow: flow ?? this.flow,
      reality: reality ?? this.reality,
      latencyMs: latencyMs ?? this.latencyMs,
    );
  }
}

class DomainOverride {
  const DomainOverride({
    required this.domain,
    required this.outboundServerId,
    this.enabled = true,
  });

  final String domain;
  final String outboundServerId;
  final bool enabled;

  /// Whether this is a wildcard rule (e.g., *.google.com)
  bool get isWildcard => domain.startsWith('*.');

  DomainOverride copyWith({
    String? domain,
    String? outboundServerId,
    bool? enabled,
  }) {
    return DomainOverride(
      domain: domain ?? this.domain,
      outboundServerId: outboundServerId ?? this.outboundServerId,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'outboundServerId': outboundServerId,
    'enabled': enabled,
  };

  factory DomainOverride.fromJson(Map<String, dynamic> json) {
    return DomainOverride(
      domain: json['domain'] as String,
      outboundServerId: json['outboundServerId'] as String,
      enabled: json['enabled'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DomainOverride &&
        other.domain == domain &&
        other.outboundServerId == outboundServerId &&
        other.enabled == enabled;
  }

  @override
  int get hashCode => Object.hash(domain, outboundServerId, enabled);
}

/// Domain validation regex: matches valid domain names
final domainValidationRegex = RegExp(
  r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$',
);

/// Validates a domain string, including wildcard patterns like *.google.com
bool isValidDomain(String domain) {
  if (domain.isEmpty) return false;

  // Handle wildcard patterns
  if (domain.startsWith('*.')) {
    final suffix = domain.substring(2);
    return suffix.isNotEmpty &&
        !suffix.contains('/') &&
        domainValidationRegex.hasMatch(suffix);
  }

  return domainValidationRegex.hasMatch(domain);
}

class SplitTunnelSettings {
  const SplitTunnelSettings({
    required this.mode,
    required this.appIdentifiers,
    this.excludedDomains = const [],
    this.domainOverrides = const [],
  });

  final SplitTunnelMode mode;
  final List<String> appIdentifiers;
  final List<String> excludedDomains;

  /// Domain routing rules for bypassing VPN blocks
  /// Each rule specifies a domain and which outbound server to use for that domain
  final List<DomainOverride> domainOverrides;
}

/// Extension for serializing and deserializing ServerProfile
extension ServerProfileSerialization on ServerProfile {
  /// Convert to JSON for persistent storage
  Map<String, dynamic> toStorageJson() => {
    'id': id,
    'name': name,
    'host': host,
    'port': port,
    'uuid': uuid,
    'flow': flow,
    'latencyMs': latencyMs,
    'reality': {
      'publicKey': reality.publicKey,
      'shortId': reality.shortId,
      'serverName': reality.serverName,
      'fingerprint': reality.fingerprint,
    },
  };

  /// Create ServerProfile from JSON storage format
  static ServerProfile fromStorageJson(Map<String, dynamic> json) {
    final realityJson = json['reality'] as Map<String, dynamic>;
    return ServerProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      host: json['host'] as String,
      port: json['port'] as int,
      uuid: json['uuid'] as String,
      flow: json['flow'] as String? ?? 'xtls-rprx-vision',
      latencyMs: json['latencyMs'] as int?,
      reality: RealitySettings(
        publicKey: realityJson['publicKey'] as String,
        shortId: realityJson['shortId'] as String? ?? '',
        serverName: realityJson['serverName'] as String,
        fingerprint: realityJson['fingerprint'] as String? ?? 'chrome',
      ),
    );
  }

  /// Generate vless:// URI string for sharing
  String toVlessUri() {
    final params = <String, String>{
      'type': 'tcp',
      'security': 'reality',
      'sni': reality.serverName,
      'pbk': reality.publicKey,
      'fp': reality.fingerprint,
      if (reality.shortId.isNotEmpty) 'sid': reality.shortId,
      if (flow.isNotEmpty) 'flow': flow,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'vless://$uuid@$host:$port?$query#${Uri.encodeComponent(name)}';
  }

  /// Parse vless:// URI string to ServerProfile
  static ServerProfile? fromVlessUri(String uri, {String? existingId}) {
    try {
      final parsed = Uri.parse(uri);

      // 1. Check scheme
      if (parsed.scheme != 'vless') {
        return null;
      }

      // 2. Extract required components
      final uuid = parsed.userInfo;
      if (uuid.isEmpty) {
        return null;
      }

      final host = parsed.host;
      if (host.isEmpty) {
        return null;
      }

      final port = parsed.hasPort ? parsed.port : 443;
      if (port <= 0 || port > 65535) {
        return null;
      }

      // 3. Name from fragment
      final name = parsed.fragment.isNotEmpty
          ? Uri.decodeComponent(parsed.fragment)
          : host;

      // 4. Query parameters
      final params = parsed.queryParameters;

      final normalizedPbk = (params['pbk'] ?? '').trim();
      final normalizedShortId = (params['sid'] ?? '').trim();
      final normalizedServerName = (params['sni'] ?? params['serverName'] ?? '')
          .trim();

      return ServerProfile(
        id: existingId ?? '${host}_$port',
        name: name,
        host: host,
        port: port,
        uuid: uuid,
        flow: params['flow'] ?? 'xtls-rprx-vision',
        reality: RealitySettings(
          publicKey: normalizedPbk,
          shortId: normalizedShortId,
          serverName: normalizedServerName,
          fingerprint: (params['fp'] ?? 'chrome').trim(),
        ),
      );
    } catch (e) {
      return null;
    }
  }
}

/// Parse vless:// URI string (standalone function for convenience)
ServerProfile? parseVlessUri(String uri, {String? existingId}) {
  return ServerProfileSerialization.fromVlessUri(uri, existingId: existingId);
}
