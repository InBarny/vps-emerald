import 'package:flutter_test/flutter_test.dart';
import 'package:vps_emerald_app/services/x3_ui_api.dart';

void main() {
  group('X3UIApi addClient body format', () {
    test('InboundOption parses enable field', () {
      final opt = InboundOption.fromJson({
        'id': 1,
        'remark': 'VLESS',
        'protocol': 'vless',
        'port': 443,
        'tlsFlowCapable': true,
        'enable': true,
      });
      expect(opt.id, equals(1));
      expect(opt.enable, isTrue);
    });

    test('InboundOption defaults enable to true', () {
      final opt = InboundOption.fromJson({
        'id': 2,
        'remark': 'Test',
        'protocol': 'trojan',
        'port': 8080,
      });
      expect(opt.enable, isTrue);
    });

    test('ClientInfo parses subId and uuid', () {
      final client = ClientInfo.fromJson({
        'id': 1,
        'email': 'test@local',
        'subId': 'abc123',
        'uuid': 'uuid-456',
        'totalGB': 0,
        'expiryTime': 0,
        'enable': true,
        'inboundIds': [1, 2],
      });
      expect(client.subId, equals('abc123'));
      expect(client.uuid, equals('uuid-456'));
      expect(client.inboundIds, equals([1, 2]));
    });
  });
}
