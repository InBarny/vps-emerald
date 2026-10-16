// lib/ui/screens/servers_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../../models/server_config.dart';
import '../../vpn/models/server_models.dart';
import '../add_server_page.dart';
import '../app_controller.dart';
import '../widgets/glass_card.dart';

class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _searchQuery = _searchController.text.toLowerCase());
        }
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ServerProfile> get _filteredServers {
    final servers = widget.controller.servers;
    if (_searchQuery.isEmpty) return servers;
    return servers.where((s) {
      return s.name.toLowerCase().contains(_searchQuery) ||
          s.host.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  Future<void> _refreshSubscription() async {
    final hasLink = widget.controller.subscriptionInfo.vpnLink != null;
    if (!hasLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0a1f14),
          content: Text(
            'Нет активной подписки для обновления',
            style: TextStyle(color: Color(0xFFffaa00)),
          ),
        ),
      );
      return;
    }
    setState(() => _isRefreshing = true);
    await widget.controller.loadServersFromSubscription();
    if (mounted) {
      setState(() => _isRefreshing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0a1f14),
          content: Text(
            widget.controller.servers.isNotEmpty
                ? 'Серверы обновлены (${widget.controller.servers.length})'
                : 'Не удалось обновить серверы',
            style: TextStyle(
              color: widget.controller.servers.isNotEmpty
                  ? const Color(0xFF00ff88)
                  : const Color(0xFFff4444),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _importFromLink(BuildContext context) async {
    final linkController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a1f14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x2E00ff88)),
        ),
        title: const Text(
          'Импорт VLESS ссылки',
          style: TextStyle(color: Color(0xFFe8f5e9)),
        ),
        content: TextField(
          controller: linkController,
          style: const TextStyle(color: Color(0xFFe8f5e9)),
          decoration: InputDecoration(
            hintText: 'vless://...',
            hintStyle: const TextStyle(color: Color(0xFF4a7a5c)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF88b89a)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, linkController.text.trim()),
            child: const Text('Импортировать'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final config = ServerConfig.fromVlessUri(result);
      final profile = config.toProfile();
      widget.controller.serverRepository.upsert(profile);
      if (widget.controller.servers.length == 1) {
        widget.controller.selectServer(profile.id);
      }
      await widget.controller.saveServersToStorage();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0a1f14),
            content: Text(
              'Сервер "${config.name}" добавлен',
              style: const TextStyle(color: Color(0xFFe8f5e9)),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0a1f14),
            content: Text(
              'Неверная VLESS ссылка: $e',
              style: const TextStyle(color: Color(0xFFff4444)),
            ),
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ServerProfile server,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a1f14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x2E00ff88)),
        ),
        title: const Text(
          'Удалить сервер',
          style: TextStyle(color: Color(0xFFe8f5e9)),
        ),
        content: Text(
          'Удалить "${server.name}"?',
          style: const TextStyle(color: Color(0xFF88b89a)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF88b89a)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFff4444),
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      widget.controller.serverRepository.remove(server.id);
      await widget.controller.saveServersToStorage();
      if (widget.controller.selectedServer?.id == server.id) {
        if (widget.controller.servers.isNotEmpty) {
          widget.controller.selectServer(widget.controller.servers.first.id);
        }
      }
    }
  }

  String _getFlag(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return '🇷🇺';
    if (h.contains('de')) return '🇩🇪';
    if (h.contains('us')) return '🇺🇸';
    if (h.contains('uk') || h.contains('gb')) return '🇬🇧';
    if (h.contains('fr')) return '🇫🇷';
    if (h.contains('nl')) return '🇳🇱';
    if (h.contains('jp')) return '🇯🇵';
    if (h.contains('sg')) return '🇸🇬';
    if (h.contains('ca')) return '🇨🇦';
    return '🌐';
  }

  String _getCity(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return 'Россия';
    if (h.contains('de')) return 'Германия';
    if (h.contains('us')) return 'США';
    if (h.contains('uk') || h.contains('gb')) return 'Великобритания';
    if (h.contains('fr')) return 'Франция';
    if (h.contains('nl')) return 'Нидерланды';
    if (h.contains('jp')) return 'Япония';
    if (h.contains('sg')) return 'Сингапур';
    if (h.contains('ca')) return 'Канада';
    return 'Международный';
  }

  @override
  Widget build(BuildContext context) {
    final servers = _filteredServers;
    final selectedId = widget.controller.selectedServer?.id;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'import_link',
            backgroundColor: const Color(0xFF00ff88),
            foregroundColor: const Color(0xFF05140c),
            onPressed: () => _importFromLink(context),
            child: const Icon(Icons.link),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'add_server',
            backgroundColor: const Color(0xFF00ff88),
            foregroundColor: const Color(0xFF05140c),
            onPressed: () async {
              final newConfig = await Navigator.push<ServerConfig>(
                context,
                MaterialPageRoute(builder: (_) => const AddServerPage()),
              );
              if (newConfig != null) {
                final profile = newConfig.toProfile();
                widget.controller.serverRepository.upsert(profile);
                if (widget.controller.servers.isEmpty) {
                  widget.controller.selectServer(profile.id);
                }
                await widget.controller.saveServersToStorage();
              }
            },
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 700;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: isWide ? 2 : 1,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _buildTitle('Серверы'),
                            const Spacer(),
                            if (_isRefreshing)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF00ff88),
                                ),
                              )
                            else
                              IconButton(
                                icon: const Icon(
                                  Icons.refresh,
                                  color: Color(0xFF88b89a),
                                  size: 20,
                                ),
                                tooltip: 'Обновить подписку',
                                onPressed: _refreshSubscription,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSearch(),
                        const SizedBox(height: 24),
                        ...servers.map((s) => _buildServerItem(s, selectedId)),
                        if (servers.isEmpty)
                          const Center(
                            child: Text(
                              'Нет серверов',
                              style: TextStyle(color: Color(0xFF4a7a5c)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (isWide && selectedId != null) ...[
                  const VerticalDivider(width: 1, color: Color(0x2E00ff88)),
                  const SizedBox(width: 24),
                  Expanded(
                    flex: 3,
                    child: _ServerDetails(
                      server: widget.controller.selectedServer!,
                      onDelete: () => _confirmDelete(
                        context,
                        widget.controller.selectedServer!,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTitle(String text) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Colors.white, Color(0xFF88ffaa)],
      ).createShader(bounds),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 600,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withOpacity(0.03),
                const Color(0xFF00ff88).withOpacity(0.01),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF00ff88).withOpacity(0.12),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.search, size: 18, color: const Color(0xFF4a7a5c)),
              const SizedBox(width: 12),
              Expanded(
                child: Material(
                  type: MaterialType.transparency,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Поиск серверов...',
                      hintStyle: TextStyle(color: Color(0xFF4a7a5c)),
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServerItem(ServerProfile s, String? selectedId) {
    final isSelected = s.id == selectedId;
    final ping = s.latencyMs ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        onTap: () {
          // Guard: controller/selected state may be in transient null state during rebuilds.
          final id = s.id;
          if (id.isEmpty) return;
          widget.controller.selectServer(id);
        },
        child: Row(
          children: [
            Text(_getFlag(s.host), style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _getCity(s.host),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF88b89a),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  '${ping} ms',
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 14,
                    color: ping < 100
                        ? const Color(0xFF00ff88)
                        : const Color(0xFFffaa00),
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Пинг',
                  style: TextStyle(fontSize: 11, color: Color(0xFF4a7a5c)),
                ),
              ],
            ),
            const SizedBox(width: 24),
            if (isSelected)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF00ff88),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Активен',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF05140c),
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => widget.controller.selectServer(s.id),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF00ff88)),
                  foregroundColor: const Color(0xFF00ff88),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Подключить',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServerDetails extends StatelessWidget {
  const _ServerDetails({required this.server, required this.onDelete});

  final ServerProfile server;
  final VoidCallback onDelete;

  String _getFlag(String host) {
    final h = host.toLowerCase();
    if (h.contains('ru')) return '🇷🇺';
    if (h.contains('de')) return '🇩🇪';
    if (h.contains('us')) return '🇺🇸';
    if (h.contains('uk') || h.contains('gb')) return '🇬🇧';
    if (h.contains('fr')) return '🇫🇷';
    if (h.contains('nl')) return '🇳🇱';
    if (h.contains('jp')) return '🇯🇵';
    if (h.contains('sg')) return '🇸🇬';
    return '🌐';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00ff88).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0x2E00ff88)),
                  ),
                  child: Center(
                    child: Text(
                      _getFlag(server.host),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${server.host}:${server.port}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF88b89a),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: Color(0x2E00ff88)),
            if (server.latencyMs != null)
              _buildInfoRow('Пинг', '${server.latencyMs} ms'),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Удалить сервер'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFff6b6b),
                side: BorderSide(
                  color: const Color(0xFFff4444).withOpacity(0.4),
                ),
                backgroundColor: const Color(0xFFff4444).withOpacity(0.06),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isSensitive = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF88b89a)),
            ),
          ),
          Expanded(
            child: Text(
              isSensitive ? _maskValue(value) : value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                fontFamily: 'JetBrainsMono',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _maskValue(String value) {
    if (value.length <= 8) return '••••••••';
    return '${value.substring(0, 4)}••••${value.substring(value.length - 4)}';
  }
}
