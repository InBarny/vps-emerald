import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Simple promo code logic extracted for testing
String generatePromoCode() {
  const chars = '0123456789';
  final buffer = StringBuffer('EMERALD');
  for (var i = 0; i < 4; i++) {
    buffer.write(chars[i % chars.length]); // deterministic for test
  }
  return buffer.toString();
}

void main() {
  group('Promo Code Logic', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('promo code starts with EMERALD and has 4 extra chars', () {
      final code = generatePromoCode();
      expect(code.startsWith('EMERALD'), isTrue);
      expect(code.length, equals('EMERALD'.length + 4));
    });

    test('promo code can be saved and loaded as used', () async {
      final prefs = await SharedPreferences.getInstance();
      const code = 'EMERALD1234';
      await prefs.setString('promo_code', code);
      await prefs.setBool('promo_used', true);

      expect(prefs.getString('promo_code'), equals(code));
      expect(prefs.getBool('promo_used'), isTrue);
    });

    test('promo code defaults to unused', () async {
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('promo_used'), isNull);
    });
  });
}
