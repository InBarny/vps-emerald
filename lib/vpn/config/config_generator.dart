import 'dart:convert';
import 'dart:math';

import '../../core/errors/vpn_error.dart';
import '../models/server_models.dart';

class _ParsedExcludedDomains {
  const _ParsedExcludedDomains({
    required this.exactDomains,
    required this.suffixes,
  });

  final List<String> exactDomains;
  final List<String> suffixes;
}

class _RouteParts {
  _RouteParts({
    required this.domainRules,
    required this.overrideRules,
    required this.finalOutbound,
  });
  final List<Map<String, dynamic>> domainRules;
  final List<Map<String, dynamic>> overrideRules;
  final String finalOutbound;
}

class SingBoxConfigGenerator {
  String generateVlessRealityConfig({
    required ServerProfile server,
    required SplitTunnelSettings splitTunnel,
    int localSocksPort = 2080,
    int localMixedPort = 2081,
    ServerProfile? albaniaProxy,
    String? logOutputPath,
  }) {
    _validate(server, localSocksPort, localMixedPort);

    final routeParts = _buildRouteParts(splitTunnel, albaniaProxy);

    final random = Random();
    final uniqueId = random.nextInt(10000);
    final thirdOctet = random.nextInt(254) + 1;
    final tunInterfaceName = 'vps-$uniqueId';
    final tunAddress = '10.255.$thirdOctet.1/30';

    // VLESS outbound — БЕЗ domain_resolver (ломает Reality), БЕЗ flow
    final Map<String, dynamic> vlessOutbound = {
      'type': 'vless',
      'tag': 'proxy',
      'server': server.host,
      'server_port': server.port,
      'uuid': server.uuid,
      'packet_encoding': 'xudp',
      'tls': {
        'enabled': true,
        'server_name': server.reality.serverName,
        'utls': {'enabled': true, 'fingerprint': server.reality.fingerprint},
        'reality': {
          'enabled': true,
          'public_key': server.reality.publicKey,
          if (server.reality.shortId.isNotEmpty)
            'short_id': server.reality.shortId,
        },
      },
    };

    final outbounds = <Map<String, dynamic>>[
      vlessOutbound,
      {
        'type': 'direct',
        'tag': 'direct',
        'domain_resolver': {'server': 'local-udp', 'strategy': 'prefer_ipv4'},
      },
      {'type': 'block', 'tag': 'block'},
    ];

    if (albaniaProxy != null) {
      final albaniaOutbound = <String, dynamic>{
        'type': 'vless',
        'tag': 'albania-proxy',
        'server': albaniaProxy.host,
        'server_port': albaniaProxy.port,
        'uuid': albaniaProxy.uuid,
        'packet_encoding': 'xudp',
        'tls': {
          'enabled': true,
          'server_name': albaniaProxy.reality.serverName,
          'utls': {
            'enabled': true,
            'fingerprint': albaniaProxy.reality.fingerprint,
          },
          'reality': {
            'enabled': true,
            'public_key': albaniaProxy.reality.publicKey,
            if (albaniaProxy.reality.shortId.isNotEmpty)
              'short_id': albaniaProxy.reality.shortId,
          },
        },
      };
      outbounds.insert(1, albaniaOutbound);
    }

    final dnsServers = [
      {
        'tag': 'google-doh',
        'type': 'https',
        'server': 'dns.google',
        'server_port': 443,
        'path': '/dns-query',
        'detour': 'proxy',
      },
      {
        'tag': 'cloudflare-doh',
        'type': 'https',
        'server': 'cloudflare-dns.com',
        'server_port': 443,
        'path': '/dns-query',
        'detour': 'proxy',
      },
      {
        'tag': 'local-udp',
        'type': 'udp',
        'server': '223.5.5.5',
        'server_port': 53,
        'detour': 'direct',
      },
    ];

    final dnsRules = <Map<String, dynamic>>[];

    dnsRules.add({
      'domain': [server.host],
      'server': 'local-udp',
    });
    if (albaniaProxy != null) {
      dnsRules.add({
        'domain': [albaniaProxy.host],
        'server': 'local-udp',
      });
    }

    if (splitTunnel.excludedDomains.isNotEmpty) {
      final parsed = _parseExcludedDomains(splitTunnel.excludedDomains);
      if (parsed.exactDomains.isNotEmpty) {
        dnsRules.add({'domain': parsed.exactDomains, 'server': 'local-udp'});
      }
      if (parsed.suffixes.isNotEmpty) {
        dnsRules.add({'domain_suffix': parsed.suffixes, 'server': 'local-udp'});
      }
    }

    dnsRules.add({'server': 'google-doh'});

    final routeRules = <Map<String, dynamic>>[
      {'action': 'sniff'},
      {'protocol': 'dns', 'action': 'hijack-dns'},
      ...routeParts.domainRules,
      ...routeParts.overrideRules,
      {'ip_is_private': true, 'outbound': 'direct'},
      {
        'inbound': ['tun-in'],
        'action': 'route',
        'outbound': routeParts.finalOutbound,
      },
    ];

    final logConfig = <String, dynamic>{'level': 'warn', 'timestamp': true};
    if (logOutputPath != null && logOutputPath.isNotEmpty) {
      logConfig['output'] = logOutputPath;
    }

    final config = {
      'log': logConfig,
      'dns': {
        'servers': dnsServers,
        'rules': dnsRules,
        'strategy': 'prefer_ipv4',
        'disable_cache': false,
        // УБРАНО: 'disable_ipv6': true — unknown field в 1.13
      },
      'inbounds': [
        {
          'type': 'mixed',
          'tag': 'mixed-in',
          'listen': '127.0.0.1',
          'listen_port': localMixedPort,
        },
        {
          'type': 'tun',
          'tag': 'tun-in',
          'interface_name': tunInterfaceName,
          'address': [tunAddress],
          'mtu': 1400,
          'stack': 'system',
          'auto_route': true,
          'strict_route': true,
          'endpoint_independent_nat': false,
        },
      ],
      'outbounds': outbounds,
      'route': {
        'auto_detect_interface': true,
        'default_domain_resolver': {
          'server': 'local-udp',
          'strategy': 'prefer_ipv4',
        },
        'rules': routeRules,
        'final': routeParts.finalOutbound,
      },
      'experimental': {
        'clash_api': {'external_controller': '127.0.0.1:9090'},
        'cache_file': {'enabled': true},
      },
    };

    return const JsonEncoder.withIndent('  ').convert(config);
  }

  _ParsedExcludedDomains _parseExcludedDomains(List<String> domains) {
    final exact = <String>{};
    final suffixes = <String>{};

    for (var entry in domains) {
      entry = entry.trim().toLowerCase();
      if (entry.isEmpty) continue;

      if (entry.startsWith('http://') || entry.startsWith('https://')) {
        entry = entry.replaceFirst(RegExp(r'^https?://'), '');
      }

      entry = entry.split('/').first;
      if (entry.isEmpty) continue;

      if (entry.startsWith('.')) {
        final rawSuffix = entry.substring(1);
        if (rawSuffix.isEmpty) continue;

        final parts = rawSuffix.split('.').where((p) => p.isNotEmpty).toList();

        if (parts.length <= 1) {
          continue;
        }

        suffixes.add(rawSuffix);
      } else {
        exact.add(entry);
        if (!entry.startsWith('www.')) {
          exact.add('www.$entry');
        }
      }
    }

    return _ParsedExcludedDomains(
      exactDomains: exact.toList(growable: false)..sort(),
      suffixes: suffixes.toList(growable: false)..sort(),
    );
  }

  void _validate(ServerProfile server, int localSocksPort, int localMixedPort) {
    if (server.host.trim().isEmpty) {
      throw VpnError(VpnErrorKind.config, 'Server host is required');
    }
    if (server.uuid.trim().isEmpty) {
      throw VpnError(VpnErrorKind.config, 'UUID is required');
    }
    if (server.reality.publicKey.trim().isEmpty) {
      throw VpnError(VpnErrorKind.config, 'Reality public key is required');
    }
    if (server.reality.serverName.trim().isEmpty) {
      throw VpnError(VpnErrorKind.config, 'Reality SNI/serverName is required');
    }
    if (server.port <= 0 || server.port > 65535) {
      throw VpnError(VpnErrorKind.config, 'Server port must be in 1..65535');
    }
    if (localSocksPort <= 0 || localSocksPort > 65535) {
      throw VpnError(VpnErrorKind.config, 'SOCKS port must be in 1..65535');
    }
    if (localMixedPort <= 0 || localMixedPort > 65535) {
      throw VpnError(VpnErrorKind.config, 'Mixed port must be in 1..65535');
    }
  }

  _RouteParts _buildRouteParts(
    SplitTunnelSettings splitTunnel,
    ServerProfile? albaniaProxy,
  ) {
    final domainRules = <Map<String, dynamic>>[];
    final overrideRules = <Map<String, dynamic>>[];

    if (splitTunnel.excludedDomains.isNotEmpty) {
      final parsed = _parseExcludedDomains(splitTunnel.excludedDomains);

      if (parsed.exactDomains.isNotEmpty) {
        domainRules.add({'domain': parsed.exactDomains, 'outbound': 'direct'});
      }
      if (parsed.suffixes.isNotEmpty) {
        domainRules.add({
          'domain_suffix': parsed.suffixes,
          'outbound': 'direct',
        });
      }
    }

    if (splitTunnel.domainOverrides.isNotEmpty && albaniaProxy != null) {
      for (final override in splitTunnel.domainOverrides) {
        if (!override.enabled) continue;
        final domain = override.domain.trim().toLowerCase();
        if (domain.isEmpty) continue;
        if (domain.startsWith('*.')) {
          overrideRules.add({
            'domain_suffix': [domain.substring(2)],
            'outbound': 'albania-proxy',
          });
        } else {
          overrideRules.add({
            'domain': [domain],
            'outbound': 'albania-proxy',
          });
          if (!domain.startsWith('www.')) {
            overrideRules.add({
              'domain': ['www.$domain'],
              'outbound': 'albania-proxy',
            });
          }
        }
      }
    }

    String finalOutbound = 'proxy';
    if (splitTunnel.mode != SplitTunnelMode.disabled) {
      if (splitTunnel.appIdentifiers.isEmpty) {
        throw VpnError(
          VpnErrorKind.splitTunneling,
          'Split tunneling is enabled, but app list is empty',
        );
      }
      final outboundForSelected =
          splitTunnel.mode == SplitTunnelMode.excludeSelectedApps
          ? 'direct'
          : 'proxy';
      finalOutbound = splitTunnel.mode == SplitTunnelMode.excludeSelectedApps
          ? 'proxy'
          : 'direct';
      domainRules.add({
        'process_name': splitTunnel.appIdentifiers,
        'outbound': outboundForSelected,
      });
    }

    return _RouteParts(
      domainRules: domainRules,
      overrideRules: overrideRules,
      finalOutbound: finalOutbound,
    );
  }
}
