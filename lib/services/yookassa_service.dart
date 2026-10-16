import 'dart:async';

import '../config/app_config.dart';
import '../models/subscription_models.dart';
import 'backend_api_service.dart';

class YooKassaService {
  final BackendApiService _backend;

  YooKassaService()
    : _backend = BackendApiService(
        baseUrl: AppConfig.apiBaseUrl,
        appToken: AppConfig.appToken,
      );

  Future<YooKassaPaymentResult?> createPayment(
    double amountRub,
    String description,
    String returnUrl, {
    Map<String, String>? metadata,
  }) async {
    final userId = metadata?['user_id'] ?? 'unknown';
    final planId = metadata?['plan_id'] ?? 'unknown';

    final result = await _backend.createPayment(
      planId: planId,
      amount: amountRub,
      currency: 'RUB',
      description: description,
      userId: userId,
      metadata: metadata,
    );

    if (result == null) return null;

    return YooKassaPaymentResult(
      paymentId: result['payment_id'] ?? '',
      confirmationUrl: result['confirmation_url'] ?? '',
      status: _parseStatus(result['status']),
      amount: amountRub,
      description: description,
      metadata: metadata ?? {},
    );
  }

  Future<PaymentStatus> getPaymentStatus(String paymentId) async {
    final result = await _backend.getPaymentStatus(paymentId);
    return _parseStatus(result?['status']);
  }

  /// Автоматическое подтверждение платежа (capture) если он в статусе waiting_for_capture
  Future<PaymentStatus> capturePayment(String paymentId, double amountRub) async {
    final result = await _backend.capturePayment(paymentId, amountRub, 'RUB');
    return _parseStatus(result?['status']);
  }

  /// Polling проверки статуса платежа с заданным интервалом
  Stream<PaymentStatus> pollPaymentStatus(
    String paymentId, {
    Duration interval = const Duration(seconds: 10),
    Duration timeout = const Duration(minutes: 10),
  }) async* {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < timeout) {
      final status = await getPaymentStatus(paymentId);
      yield status;
      if (status == PaymentStatus.succeeded ||
          status == PaymentStatus.canceled ||
          status == PaymentStatus.failed) {
        break;
      }
      await Future.delayed(interval);
    }
    stopwatch.stop();
  }

  PaymentStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
      case 'waiting_for_capture':
        return PaymentStatus.pending;
      case 'succeeded':
        return PaymentStatus.succeeded;
      case 'canceled':
        return PaymentStatus.canceled;
      case 'failed':
        return PaymentStatus.failed;
      default:
        return PaymentStatus.failed;
    }
  }

  void dispose() => _backend.dispose();
}
