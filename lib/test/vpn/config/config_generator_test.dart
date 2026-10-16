// test/vpn/config/config_generator_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:vps_emerald_app/vpn/config/config_generator.dart';
import 'package:vps_emerald_app/vpn/models/server_models.dart';

void main() {
  group('SingBoxConfigGenerator', () {
    late SingBoxConfigGenerator generator;
    late ServerProfile testServer;

    setUp(() {
      generator = SingBoxConfigGenerator();
      testServer = _createTestServer();
    });

    // ============================================================
    // 1. Basic VLESS Reality Configuration Generation
    // ============================================================
    group('Basic VLESS Reality Configuration', () {
      test('generates valid JSON with required fields', () {
        final config = generator.generateVlessRealityConfig(
          server: testServer,
          splitTunnel: _disabledSplitTunnel(),
        );

        expect(
          () => jsonDecode(config),
          returnsNormally,
          reason: 'Config must be valid JSON',
        );
      });

      test('contains version/key fields in outbound', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final outbounds = configJson['outbounds'] as List;
        final vlessOutbound = outbounds.first as Map<String, dynamic>;

        expect(
          vlessOutbound['type'],
          equals('vless'),
          reason: 'First outbound must be VLESS',
        );
        expect(
          vlessOutbound.containsKey('server'),
          isTrue,
          reason: 'Outbound must have server field',
        );
        expect(
          vlessOutbound.containsKey('uuid'),
          isTrue,
          reason: 'Outbound must have uuid field',
        );
        expect(
          vlessOutbound.containsKey('tls'),
          isTrue,
          reason: 'Outbound must have TLS config',
        );
      });

      test('UUID format is preserved correctly', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final outbounds = configJson['outbounds'] as List;
        final vlessOutbound = outbounds.first as Map<String, dynamic>;

        expect(
          vlessOutbound['uuid'],
          equals(testServer.uuid),
          reason: 'UUID must match server UUID',
        );
      });

      test('Reality settings are correctly nested', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final outbounds = configJson['outbounds'] as List;
        final vlessOutbound = outbounds.first as Map<String, dynamic>;
        final tls = vlessOutbound['tls'] as Map<String, dynamic>;
        final reality = tls['reality'] as Map<String, dynamic>;

        expect(reality['enabled'], isTrue);
        expect(reality['public_key'], equals(testServer.reality.publicKey));
      });
    });

    // ============================================================
    // 2. SplitTunnelSettings Disabled Mode
    // ============================================================
    group('Split Tunnel Disabled Mode', () {
      test('no route.rules for excluded domains when disabled', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final domainSuffixRules = rules.where(
          (r) => r is Map && r.containsKey('domain_suffix'),
        );

        expect(
          domainSuffixRules,
          isEmpty,
          reason: 'No domain_suffix rules when split tunneling is disabled',
        );
      });

      test('final outbound is proxy when disabled', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        expect(
          route['final'],
          equals('proxy'),
          reason: 'Final outbound must be proxy when disabled',
        );
      });

      test('no process_name rules when disabled', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final processRules = rules.where(
          (r) => r is Map && r.containsKey('process_name'),
        );

        expect(
          processRules,
          isEmpty,
          reason: 'No process_name rules when split tunneling is disabled',
        );
      });
    });

    // ============================================================
    // 3. Exclude Mode with Domain Suffixes
    // ============================================================
    group('Exclude Mode with Domain Suffixes', () {
      test('generates domain_suffix rules for TLDs', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.me', '.cn'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final domainSuffixRules = rules
            .where((r) => r is Map && r.containsKey('domain_suffix'))
            .toList();

        expect(
          domainSuffixRules.length,
          greaterThan(0),
          reason: 'Must have at least one domain_suffix rule',
        );
      });

      test('leading dot is stripped from TLDs', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.google.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        final suffixes = suffixRule['domain_suffix'] as List;
        expect(
          suffixes,
          containsAll(['ru', 'google.com']),
          reason: 'Leading dot must be stripped',
        );
        expect(
          suffixes,
          isNot(contains('.ru')),
          reason: 'Must not contain leading dot',
        );
      });

      test('no empty rules added', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.cn'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        for (final rule in rules) {
          if (rule is Map) {
            expect(
              rule.values.any((v) => v is List && v.isEmpty),
              isFalse,
              reason: 'No rule should have empty arrays',
            );
          }
        }
      });

      test('excluded domains route to direct', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        expect(
          suffixRule['outbound'],
          equals('direct'),
          reason: 'Excluded domains must route to direct',
        );
      });
    });

    // ============================================================
    // 4. Include Mode with Domain Suffixes
    // ============================================================
    group('Include Mode (whitelist approach)', () {
      test('include mode inverts logic to proxy for matched domains', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.includeOnlySelectedApps,
                      excludedDomains: ['.google.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        expect(
          suffixRule['outbound'],
          equals('proxy'),
          reason: 'Include mode must route matched domains to proxy',
        );
      });

      test('include mode final outbound is direct', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.includeOnlySelectedApps,
                      excludedDomains: ['.google.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        expect(
          route['final'],
          equals('direct'),
          reason: 'Include mode final outbound must be direct',
        );
      });
    });

    // ============================================================
    // 5. App Identifiers Compatibility (Android/iOS)
    // ============================================================
    group('App Identifiers for Different Platforms', () {
      test('process_name rules generated for exclude mode', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      appIdentifiers: ['chrome.exe', 'firefox.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final processRule =
            rules.firstWhere((r) => r is Map && r.containsKey('process_name'))
                as Map;

        expect(processRule['process_name'], isA<List>());
        expect(
          (processRule['process_name'] as List).length,
          equals(2),
          reason: 'Should have 2 process names',
        );
      });

      test('.exe extension is stripped from process names', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      appIdentifiers: ['chrome.exe', 'firefox.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final processRule =
            rules.firstWhere((r) => r is Map && r.containsKey('process_name'))
                as Map;

        final processNames = processRule['process_name'] as List;
        expect(
          processNames,
          containsAll(['chrome', 'firefox']),
          reason: '.exe extension must be stripped',
        );
        expect(
          processNames,
          isNot(contains('chrome.exe')),
          reason: 'Must not contain .exe extension',
        );
      });

      test('process names are lowercased', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      appIdentifiers: ['CHROME.EXE', 'FireFox.Exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final processRule =
            rules.firstWhere((r) => r is Map && r.containsKey('process_name'))
                as Map;

        final processNames = processRule['process_name'] as List;
        expect(
          processNames,
          containsAll(['chrome', 'firefox']),
          reason: 'Process names must be lowercased',
        );
      });
    });

    // ============================================================
    // 6. Combined Scenarios
    // ============================================================
    group('Combined Scenarios', () {
      test('exclude + include domains work together', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.cn'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final hasSuffix = rules.any(
          (r) => r is Map && r.containsKey('domain_suffix'),
        );
        final hasProcess = rules.any(
          (r) => r is Map && r.containsKey('process_name'),
        );

        expect(hasSuffix, isTrue, reason: 'Must have domain_suffix rule');
        expect(hasProcess, isTrue, reason: 'Must have process_name rule');
      });

      test('multiple TLDs (.ru, .cn, .ir) are all present', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.cn', '.ir', '.google.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        final suffixes = suffixRule['domain_suffix'] as List;
        expect(
          suffixes,
          containsAll(['ru', 'cn', 'ir', 'google.com']),
          reason: 'All TLDs must be present',
        );
      });

      test('overlapping rules are handled gracefully', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.com', '.google.com', 'google.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        // Should not throw - just generates config
        expect(
          configJson,
          isA<Map>(),
          reason: 'Overlapping rules should not cause errors',
        );
      });
    });

    // ============================================================
    // 7. Graceful Degradation
    // ============================================================
    group('Graceful Degradation', () {
      test('empty excludedDomains list is handled', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: [],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final hasDomainSuffix = rules.any(
          (r) => r is Map && r.containsKey('domain_suffix'),
        );
        final hasDomain = rules.any((r) => r is Map && r.containsKey('domain'));

        expect(
          hasDomainSuffix || hasDomain,
          isFalse,
          reason: 'No domain rules when excludedDomains is empty',
        );
      });

      test('empty appIdentifiers list throws in non-disabled mode', () {
        expect(
          () => generator.generateVlessRealityConfig(
            server: testServer,
            splitTunnel: _splitTunnel(
              mode: SplitTunnelMode.excludeSelectedApps,
              excludedDomains: [],
            ),
          ),
          throwsA(isA<Exception>()),
          reason: 'Must throw when split tunneling enabled but no apps',
        );
      });

      test('null-like empty strings are trimmed', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['   .ru   ', '  google.com  '],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        final suffixes = suffixRule['domain_suffix'] as List;
        expect(
          suffixes,
          containsAll(['ru']),
          reason: 'Whitespace must be trimmed',
        );
      });
    });

    // ============================================================
    // 8. JSON Validation
    // ============================================================
    group('JSON Validation', () {
      test('jsonDecode does not throw for valid config', () {
        expect(
          () => jsonDecode(
            generator.generateVlessRealityConfig(
              server: testServer,
              splitTunnel: _disabledSplitTunnel(),
            ),
          ),
          returnsNormally,
        );
      });

      test('returned map has expected nested structure', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        expect(configJson.containsKey('log'), isTrue);
        expect(configJson.containsKey('dns'), isTrue);
        expect(configJson.containsKey('inbounds'), isTrue);
        expect(configJson.containsKey('outbounds'), isTrue);
        expect(configJson.containsKey('route'), isTrue);
      });

      test('route.rules[n].domain_suffix has expected nesting', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.ru', '.cn'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule = rules.firstWhere(
          (r) => r is Map && r.containsKey('domain_suffix'),
        );

        expect(
          suffixRule,
          isA<Map>(),
          reason: 'domain_suffix rule must be a Map',
        );
        expect(
          suffixRule['domain_suffix'],
          isA<List>(),
          reason: 'domain_suffix value must be a List',
        );
      });

      test('dns.rules contains expected structure', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _disabledSplitTunnel(),
                  ),
                )
                as Map<String, dynamic>;

        final dns = configJson['dns'] as Map<String, dynamic>;
        expect(dns.containsKey('servers'), isTrue);
        expect(dns.containsKey('rules'), isTrue);
        expect(dns['servers'], isA<List>());
        expect(dns['rules'], isA<List>());
      });
    });

    // ============================================================
    // Edge Cases
    // ============================================================
    group('Edge Cases', () {
      test('domains without dot are treated as exact domains', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['faceit.com'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final domainRule = rules.where(
          (r) => r is Map && r.containsKey('domain'),
        );

        // faceit.com without leading dot should be exact domain
        expect(
          domainRule.length,
          greaterThan(0),
          reason: 'Non-dot prefix domain should create exact domain rule',
        );
      });

      test('incorrect TLD format is handled gracefully', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['..ru', '.123'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        // Should not throw, just generate config
        expect(configJson, isA<Map>());
      });

      test('unicode domains are handled', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.مثال.测试'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        // Should not throw on unicode
        expect(configJson, isA<Map>());
      });

      test('large domain list (>100) parses without performance issues', () {
        final largeList = List.generate(150, (i) => '.domain$i.com');
        final stopwatch = Stopwatch()..start();

        final configJson = jsonDecode(
          generator.generateVlessRealityConfig(
            server: testServer,
            splitTunnel: _splitTunnel(
              mode: SplitTunnelMode.excludeSelectedApps,
              excludedDomains: largeList,
              appIdentifiers: ['chrome.exe'],
            ),
          ),
        );

        stopwatch.stop();

        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(1000),
          reason: 'Large list should parse within 1 second',
        );
        expect(configJson, isA<Map>());
      });

      test('HTTP/HTTPS prefixes are stripped', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: [
                        'https://google.com',
                        'http://example.ru',
                        '.org',
                      ],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final domainRule = rules.where(
          (r) => r is Map && r.containsKey('domain'),
        );
        final suffixRule = rules.where(
          (r) => r is Map && r.containsKey('domain_suffix'),
        );

        // Should contain exact domains after stripping protocols
        if (domainRule.isNotEmpty) {
          final domains = (domainRule.first as Map)['domain'] as List;
          expect(
            domains,
            containsAll(['google.com', 'example.ru']),
            reason: 'Protocol prefixes must be stripped',
          );
        }

        if (suffixRule.isNotEmpty) {
          final suffixes = (suffixRule.first as Map)['domain_suffix'] as List;
          expect(
            suffixes,
            containsAll(['org']),
            reason: 'Suffix without protocol must remain',
          );
        }
      });

      test('path after domain is stripped', () {
        final configJson =
            jsonDecode(
                  generator.generateVlessRealityConfig(
                    server: testServer,
                    splitTunnel: _splitTunnel(
                      mode: SplitTunnelMode.excludeSelectedApps,
                      excludedDomains: ['.google.com/path/to/something'],
                      appIdentifiers: ['chrome.exe'],
                    ),
                  ),
                )
                as Map<String, dynamic>;

        final route = configJson['route'] as Map<String, dynamic>;
        final rules = route['rules'] as List;

        final suffixRule =
            rules.firstWhere((r) => r is Map && r.containsKey('domain_suffix'))
                as Map;

        final suffixes = suffixRule['domain_suffix'] as List;
        expect(
          suffixes,
          containsAll(['google.com']),
          reason: 'Path after domain must be stripped',
        );
        expect(
          suffixes,
          isNot(contains('google.com/path')),
          reason: 'Path should not be included',
        );
      });
    });

    // ============================================================
    // Validation Tests
    // ============================================================
    group('Server Validation', () {
      test('throws when server host is empty', () {
        final emptyHostServer = testServer.copyWith(host: '  ');
        expect(
          () => generator.generateVlessRealityConfig(
            server: emptyHostServer,
            splitTunnel: _disabledSplitTunnel(),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when UUID is empty', () {
        final emptyUuidServer = testServer.copyWith(uuid: '');
        expect(
          () => generator.generateVlessRealityConfig(
            server: emptyUuidServer,
            splitTunnel: _disabledSplitTunnel(),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when port is invalid', () {
        final invalidPortServer = testServer.copyWith(port: -1);
        expect(
          () => generator.generateVlessRealityConfig(
            server: invalidPortServer,
            splitTunnel: _disabledSplitTunnel(),
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('throws when reality public key is empty', () {
        final emptyKeyServer = ServerProfile(
          id: testServer.id,
          name: testServer.name,
          host: testServer.host,
          port: testServer.port,
          uuid: testServer.uuid,
          reality: RealitySettings(
            publicKey: '',
            shortId: '',
            serverName: testServer.reality.serverName,
          ),
        );
        expect(
          () => generator.generateVlessRealityConfig(
            server: emptyKeyServer,
            splitTunnel: _disabledSplitTunnel(),
          ),
          throwsA(isA<Exception>()),
        );
      });
    });
  });
}

// ============================================================
// Helper Functions
// ============================================================

ServerProfile _createTestServer() {
  return ServerProfile(
    id: 'test_server_1',
    name: 'Test Server',
    host: '198.51.100.1',
    port: 443,
    uuid: '550e8400-e29b-41d4-a716-446655440000',
    reality: const RealitySettings(
      publicKey: 'test-public-key-1234567890abcdef',
      shortId: 'abcd1234',
      serverName: 'www.google.com',
      fingerprint: 'chrome',
    ),
  );
}

SplitTunnelSettings _disabledSplitTunnel() {
  return const SplitTunnelSettings(
    mode: SplitTunnelMode.disabled,
    appIdentifiers: [],
    excludedDomains: [],
  );
}

SplitTunnelSettings _splitTunnel({
  required SplitTunnelMode mode,
  List<String> excludedDomains = const [],
  List<String> appIdentifiers = const [],
}) {
  return SplitTunnelSettings(
    mode: mode,
    appIdentifiers: appIdentifiers,
    excludedDomains: excludedDomains,
  );
}
