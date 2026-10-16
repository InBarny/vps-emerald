/// Конфигурация приложения
///
/// Все секретные ключи хранятся на сервере.
/// Приложение общается с backend через BackendApiService.
class AppConfig {
  // ── Backend API ────────────────────────────────────────────
  /// Базовый URL твоего бэкенда
  static const String apiBaseUrl = 'http://109.120.176.131';

  /// Токен авторизации (должен совпадать с APP_TOKEN на сервере)
  static const String appToken = 'aab7e5c842baefd79afdec2c966e6d7b50c454a25db7239417b8b51e9dca50cf';

  // ── YooKassa (через бэкенд, секреты только на сервере) ─────
  /// YooKassa Shop ID (публичный)
  static const String yookassaShopId = '1262857';

  /// URL для возврата после оплаты
  static const String yookassaReturnUrl = 'https://t.me/';

  // ── Server (через бэкенд) ─────────────────────────────────
  /// Базовый URL для подписки (публичный)
  static const String subscriptionBaseUrl = 'https://109.120.176.131:2096';

  /// ID inbound'ов, к которым прикреплять новых клиентов
  static const List<int> defaultInboundIds = [1];
}
