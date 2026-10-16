import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../models/server_config.dart';

class SubscriptionService {
  final http.Client _client;

  SubscriptionService({bool allowBadCertificates = true})
    : _client = IOClient(
        HttpClient()
          ..badCertificateCallback =
              allowBadCertificates ? (cert, host, port) => true : null,
      );

  /// Fetches a subscription URL and parses VLESS links from the base64 response.
  /// Parsing is offloaded to an isolate via [compute] to avoid UI jank.
  Future<List<ServerConfig>> fetchSubscription(String url) async {
    final response = await _client.get(
      Uri.parse(url),
      headers: {'User-Agent': 'VPSEmerald/1.0 (sing-box)'},
    );

    if (response.statusCode != 200) {
      throw Exception('Subscription fetch failed: HTTP ${response.statusCode}');
    }

    final body = response.body.trim();
    String decoded;
    try {
      decoded = utf8.decode(base64Decode(_padBase64(body)));
    } catch (_) {
      decoded = body;
    }

    return await compute(_parseSubscription, decoded);
  }

  static List<ServerConfig> parseSubscriptionSync(String decoded) => _parseSubscription(decoded);

  static List<ServerConfig> _parseSubscription(String decoded) {
    final lines = decoded
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    final servers = <ServerConfig>[];

    for (final line in lines) {
      if (line.startsWith('vless://')) {
        try {
          servers.add(ServerConfig.fromVlessUri(line));
        } catch (_) {
          // skip unparseable lines
        }
      }
    }
    return servers;
  }

  String _padBase64(String input) {
    final remainder = input.length % 4;
    if (remainder == 0) return input;
    return input + '=' * (4 - remainder);
  }

  void dispose() => _client.close();
}
