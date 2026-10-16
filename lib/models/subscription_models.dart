import 'dart:convert';

enum PaymentStatus { pending, succeeded, canceled, failed }

/// Тарифный план
class SubscriptionPlan {
  final String id;
  final String name;
  final int days;
  final double priceRub;
  final String? description;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.days,
    required this.priceRub,
    this.description,
  });
}

/// Информация о подписке пользователя
class SubscriptionInfo {
  DateTime? expireDate;
  String? vpnLink;
  String? marzbanUsername;
  String? promoClientEmail;
  bool autoRenew;
  String plan;
  DateTime createdAt;
  DateTime updatedAt;

  SubscriptionInfo({
    this.expireDate,
    this.vpnLink,
    this.marzbanUsername,
    this.promoClientEmail,
    this.autoRenew = true,
    this.plan = 'none',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  bool get isActive =>
      expireDate != null && DateTime.now().isBefore(expireDate!);

  int get daysRemaining {
    if (expireDate == null) return 0;
    final diff = expireDate!.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  Map<String, dynamic> toJson() => {
    'expire_date': expireDate?.toIso8601String(),
    'vpn_link': vpnLink,
    'marzban_username': marzbanUsername,
    'promo_client_email': promoClientEmail,
    'auto_renew': autoRenew,
    'plan': plan,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  factory SubscriptionInfo.fromJson(Map<String, dynamic> json) =>
      SubscriptionInfo(
        expireDate: json['expire_date'] != null
            ? DateTime.parse(json['expire_date'])
            : null,
        vpnLink: json['vpn_link'],
        marzbanUsername: json['marzban_username'],
        promoClientEmail: json['promo_client_email'],
        autoRenew: json['auto_renew'] ?? true,
        plan: json['plan'] ?? 'none',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );

  String toRawJson() => jsonEncode(toJson());
}

/// Ожидающий платёж
class PendingPayment {
  String paymentId;
  double amount;
  int days;
  String status;
  DateTime createdAt;
  String confirmationUrl;

  PendingPayment({
    required this.paymentId,
    required this.amount,
    required this.days,
    this.status = 'pending',
    required this.confirmationUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'payment_id': paymentId,
    'amount': amount,
    'days': days,
    'status': status,
    'created_at': createdAt.toIso8601String(),
    'confirmation_url': confirmationUrl,
  };

  factory PendingPayment.fromJson(Map<String, dynamic> json) => PendingPayment(
    paymentId: json['payment_id'],
    amount: (json['amount'] as num).toDouble(),
    days: json['days'],
    status: json['status'] ?? 'pending',
    confirmationUrl: json['confirmation_url'] ?? '',
    createdAt: json['created_at'] != null
        ? DateTime.parse(json['created_at'])
        : DateTime.now(),
  );
}

/// Результат создания платежа YooKassa
class YooKassaPaymentResult {
  String paymentId;
  String confirmationUrl;
  PaymentStatus status;
  double amount;
  String description;
  Map<String, String> metadata;

  YooKassaPaymentResult({
    required this.paymentId,
    required this.confirmationUrl,
    this.status = PaymentStatus.pending,
    required this.amount,
    this.description = '',
    this.metadata = const {},
  });
}
