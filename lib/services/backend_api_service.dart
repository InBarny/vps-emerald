import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Backend API клиент для Heavy Emerald.
/// Все секретные ключи хранятся на сервере, приложение общается только с бэкендом.
class BackendApiService {
  final String baseUrl;
  final String appToken;
  final http.Client _client;

  BackendApiService({
    required this.baseUrl,
    required this.appToken,
    bool allowBadCertificates = true,
  }) : _client = IOClient(
          HttpClient()
            ..badCertificateCallback =
                allowBadCertificates ? (cert, host, port) => true : null,
        );

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-App-Token': appToken,
      };

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  // ── Config ──────────────────────────────────────────────────

  /// Получить публичный конфиг с сервера.
  Future<Map<String, dynamic>?> getConfig() async {
    try {
      final response = await _client
          .get(_uri('/api/v1/config'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ── Payments ────────────────────────────────────────────────

  /// Создать платёж через бэкенд (прокси YooKassa).
  Future<Map<String, dynamic>?> createPayment({
    required String planId,
    required double amount,
    required String currency,
    required String description,
    required String userId,
    Map<String, String>? metadata,
  }) async {
    try {
      final body = jsonEncode({
        'plan_id': planId,
        'amount': amount,
        'currency': currency,
        'description': description,
        'user_id': userId,
        if (metadata != null) 'metadata': metadata,
      });

      final response = await _client
          .post(
            _uri('/api/v1/payment/create'),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Проверить статус платежа.
  Future<Map<String, dynamic>?> getPaymentStatus(String paymentId) async {
    try {
      final response = await _client
          .get(
            _uri('/api/v1/payment/status?payment_id=$paymentId'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Подтвердить платёж (capture).
  Future<Map<String, dynamic>?> capturePayment(
    String paymentId,
    double amount,
    String currency,
  ) async {
    try {
      final body = jsonEncode({
        'payment_id': paymentId,
        'amount': amount,
        'currency': currency,
      });
      final response = await _client
          .post(
            _uri('/api/v1/payment/capture'),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ── VPN Clients ───────────────────────────────────────────────

  /// Создать VPN-клиента через бэкенд.
  Future<Map<String, dynamic>?> createClient({
    required String email,
    required int days,
    required String uuid,
    required List<int> inboundIds,
    int totalGb = 0,
    String? subId,
  }) async {
    try {
      final body = jsonEncode({
        'email': email,
        'days': days,
        'uuid': uuid,
        'inbound_ids': inboundIds,
        'total_gb': totalGb,
        if (subId != null) 'sub_id': subId,
      });

      final response = await _client
          .post(
            _uri('/api/v1/client/create'),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Продлить VPN-клиента.
  Future<Map<String, dynamic>?> extendClient({
    required String email,
    required int newExpireMs,
    int? totalGb,
  }) async {
    try {
      final body = jsonEncode({
        'email': email,
        'new_expire_ms': newExpireMs,
        if (totalGb != null) 'total_gb': totalGb,
      });

      final response = await _client
          .post(
            _uri('/api/v1/client/extend'),
            headers: _headers,
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Получить статус клиента.
  Future<Map<String, dynamic>?> getClientStatus(String email) async {
    try {
      final response = await _client
          .get(
            _uri('/api/v1/client/status?email=${Uri.encodeComponent(email)}'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  // ── Additional 3X-UI proxy methods ─────────────────────────

  /// Получить свежий UUID с сервера.
  Future<String?> getNewUuid() async {
    try {
      final response = await _client
          .get(_uri('/api/v1/uuid'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['uuid'] as String?;
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Получить список активных inbound'ов.
  Future<List<Map<String, dynamic>>?> listInbounds() async {
    try {
      final response = await _client
          .get(_uri('/api/v1/inbounds'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['obj'] as List<dynamic>?;
        if (list != null) {
          return list.cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  /// Проверить, существует ли promo-клиент на сервере.
  Future<bool> hasPromoClient() async {
    try {
      final response = await _client
          .get(_uri('/api/v1/client/has-promo'), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['has_promo'] == true;
      }
    } catch (e) {
      // ignore
    }
    return false;
  }

  void dispose() => _client.close();
}
