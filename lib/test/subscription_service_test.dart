import 'package:flutter_test/flutter_test.dart';
import 'package:vps_emerald_app/models/server_config.dart';
import 'package:vps_emerald_app/services/subscription_service.dart';

void main() {
  group('SubscriptionService parsing', () {
    test('parses single VLESS URI correctly', () {
      const vlessUri =
          'vless://12345678-1234-1234-1234-123456789abc@example.com:443?security=reality&sni=example.com&fp=chrome&pbk=publickey123&sid=shortid&spx=%2F&type=tcp&flow=xtls-rprx-vision#TestServer';
      final result = SubscriptionService.parseSubscriptionSync(vlessUri);
      expect(result.length, equals(1));
      expect(result.first.name, equals('TestServer'));
      expect(result.first.address, equals('example.com'));
      expect(result.first.port, equals(443));
    });

    test('ignores non-VLESS lines', () {
      const input = 'ss://invalid\nvless://12345678-1234-1234-1234-123456789abc@x.com:443#X\nvmess://alsoinvalid';
      final result = SubscriptionService.parseSubscriptionSync(input);
      expect(result.length, equals(1));
      expect(result.first.name, equals('X'));
    });

    test('returns empty list for empty input', () {
      final result = SubscriptionService.parseSubscriptionSync('');
      expect(result, isEmpty);
    });
  });
}
