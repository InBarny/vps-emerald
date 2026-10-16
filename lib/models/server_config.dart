import 'dart:convert';

import '../vpn/models/server_models.dart';

class ServerConfig {
  final String name;
  final String address;
  final int port;
  final String uuid;
  final String serverName; // SNI
  final String publicKey;
  final String shortId;
  final String fingerprint;
  final String flow;

  const ServerConfig({
    required this.name,
    required this.address,
    required this.port,
    required this.uuid,
    required this.serverName,
    required this.publicKey,
    this.shortId = '',
    this.fingerprint = 'chrome',
    this.flow = 'xtls-rprx-vision',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'port': port,
    'uuid': uuid,
    'serverName': serverName,
    'publicKey': publicKey,
    'shortId': shortId,
    'fingerprint': fingerprint,
    'flow': flow,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    name: json['name'] as String,
    address: json['address'] as String,
    port: json['port'] as int,
    uuid: json['uuid'] as String,
    serverName: json['serverName'] as String,
    publicKey: json['publicKey'] as String,
    shortId: json['shortId'] as String? ?? '',
    fingerprint: json['fingerprint'] as String? ?? 'chrome',
    flow: json['flow'] as String? ?? 'xtls-rprx-vision',
  );

  String encode() => jsonEncode(toJson());

  factory ServerConfig.decode(String source) =>
      ServerConfig.fromJson(jsonDecode(source) as Map<String, dynamic>);

  /// Parse a VLESS share link: vless://uuid@host:port?params#name
  factory ServerConfig.fromVlessUri(String uri) {
    final parsed = Uri.parse(uri);

    // 1. Проверка схемы
    if (parsed.scheme != 'vless') {
      throw FormatException(
        'Unsupported scheme: ${parsed.scheme}. Expected vless://',
      );
    }

    // 2. Извлечение обязательных компонентов
    final uuid = parsed.userInfo;
    if (uuid.isEmpty) {
      throw FormatException('UUID is missing in VLESS link');
    }

    final address = parsed.host;
    if (address.isEmpty) {
      throw FormatException('Server address is missing');
    }

    final port = parsed.hasPort ? parsed.port : 443;
    if (port <= 0 || port > 65535) {
      throw FormatException('Invalid port: $port');
    }

    // 3. Имя из фрагмента (может отсутствовать)
    final name = parsed.fragment.isNotEmpty
        ? Uri.decodeComponent(parsed.fragment)
        : address; // fallback на адрес

    // 4. Параметры запроса
    final params = parsed.queryParameters;

    return ServerConfig(
      name: name,
      address: address,
      port: port,
      uuid: uuid,
      serverName: params['sni'] ?? params['serverName'] ?? '',
      publicKey: params['pbk'] ?? '',
      shortId: params['sid'] ?? '',
      fingerprint: params['fp'] ?? 'chrome',
      flow: params['flow'] ?? '',
    );
  }

  String toVlessUri() {
    final params = <String, String>{
      'type': 'tcp',
      'security': 'reality',
      'sni': serverName,
      'pbk': publicKey,
      'fp': fingerprint,
      if (shortId.isNotEmpty) 'sid': shortId,
      if (flow.isNotEmpty) 'flow': flow,
    };
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    return 'vless://$uuid@$address:$port?$query#${Uri.encodeComponent(name)}';
  }

  /// Преобразует ServerConfig в ServerProfile для использования в VPN-движке
  ServerProfile toProfile() {
    return ServerProfile(
      id: '${address}_$port\_$uuid',
      name: name,
      host: address,
      port: port,
      uuid: uuid,
      flow: flow,
      reality: RealitySettings(
        publicKey: publicKey,
        shortId: shortId,
        serverName: serverName,
        fingerprint: fingerprint,
      ),
    );
  }
}
