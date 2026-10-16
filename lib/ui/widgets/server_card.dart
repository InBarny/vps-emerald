// lib/ui/widgets/server_card.dart
import 'package:flutter/material.dart';
import '../../vpn/models/server_models.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

/// Карточка сервера в стиле Heavy Emerald (glassmorphism)
/// Точное соответствие reference WPF ServersView
class ServerCard extends StatelessWidget {
  const ServerCard({
    super.key,
    required this.server,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  final ServerProfile server;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _countryFlag {
    final host = server.host.toLowerCase();
    if (host.contains('ru')) return '🇷🇺';
    if (host.contains('de')) return '🇩🇪';
    if (host.contains('us')) return '🇺🇸';
    if (host.contains('uk') || host.contains('gb')) return '🇬🇧';
    if (host.contains('fr')) return '🇫🇷';
    if (host.contains('nl')) return '🇳🇱';
    if (host.contains('jp')) return '🇯🇵';
    if (host.contains('sg')) return '🇸🇬';
    if (host.contains('au')) return '🇦🇺';
    if (host.contains('ca')) return '🇨🇦';
    if (host.contains('ch')) return '🇨🇭';
    if (host.contains('se')) return '🇸🇪';
    if (host.contains('no')) return '🇳🇴';
    if (host.contains('fi')) return '🇫🇮';
    if (host.contains('dk')) return '🇩🇰';
    if (host.contains('pl')) return '🇵🇱';
    if (host.contains('cz')) return '🇨🇿';
    if (host.contains('ua')) return '🇺🇦';
    if (host.contains('kz')) return '🇰🇿';
    return '🌐';
  }

  String get _city {
    final host = server.host.toLowerCase();
    if (host.contains('ru')) return 'Россия';
    if (host.contains('de')) return 'Германия';
    if (host.contains('us')) return 'США';
    if (host.contains('uk') || host.contains('gb')) return 'Великобритания';
    if (host.contains('fr')) return 'Франция';
    if (host.contains('nl')) return 'Нидерланды';
    if (host.contains('jp')) return 'Япония';
    if (host.contains('sg')) return 'Сингапур';
    if (host.contains('au')) return 'Австралия';
    if (host.contains('ca')) return 'Канада';
    if (host.contains('ch')) return 'Швейцария';
    if (host.contains('se')) return 'Швеция';
    if (host.contains('no')) return 'Норвегия';
    if (host.contains('fi')) return 'Финляндия';
    if (host.contains('dk')) return 'Дания';
    if (host.contains('pl')) return 'Польша';
    if (host.contains('cz')) return 'Чехия';
    if (host.contains('ua')) return 'Украина';
    if (host.contains('kz')) return 'Казахстан';
    return 'Международный';
  }

  Color get _pingColor {
    final latency = server.latencyMs;
    if (latency == null) return AppColors.textDark;
    if (latency < 50) return AppColors.connected;
    if (latency < 150) return AppColors.warning;
    return AppColors.error;
  }

  String get _pingText {
    final latency = server.latencyMs;
    if (latency == null) return '—';
    return '$latency';
  }

  String get _loadText {
    final hash = server.id.hashCode.abs() % 100;
    return '$hash%';
  }

  Color get _loadColor {
    final hash = server.id.hashCode.abs() % 100;
    if (hash < 50) return AppColors.connected;
    if (hash < 80) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(server.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.error.withOpacity(0.4)),
        ),
        child: const Icon(Icons.delete, color: AppColors.error),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.bgPanel,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl),
              side: const BorderSide(color: AppColors.glassBorder),
            ),
            title: const Text('Удалить сервер', style: TextStyle(color: AppColors.text)),
            content: Text(
              'Удалить "${server.name}"?',
              style: const TextStyle(color: AppColors.textDim),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Отмена', style: TextStyle(color: AppColors.textDim)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Удалить'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => onDelete(),
      child: GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                // Flag
                SizedBox(
                  width: 40,
                  child: Text(
                    _countryFlag,
                    style: const TextStyle(fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Server info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _city,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textDim,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
                // Ping
                _MetaColumn(
                  value: _pingText,
                  label: 'Пинг',
                  valueColor: _pingColor,
                ),
                const SizedBox(width: AppSpacing.lg),
                // Load
                _MetaColumn(
                  value: _loadText,
                  label: 'Нагрузка',
                  valueColor: _loadColor,
                ),
                const SizedBox(width: AppSpacing.lg),
                // Connect button
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.emerald,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Активен',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.bg,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Подключить'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaColumn extends StatelessWidget {
  const _MetaColumn({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 14,
            color: valueColor,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textDark,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

/// Адаптивный список серверов
class ServerList extends StatelessWidget {
  const ServerList({
    super.key,
    required this.servers,
    required this.selectedId,
    required this.onSelect,
    required this.onDelete,
  });

  final List<ServerProfile> servers;
  final String? selectedId;
  final ValueChanged<ServerProfile> onSelect;
  final ValueChanged<ServerProfile> onDelete;

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.dns_outlined,
              size: 64,
              color: AppColors.textDark,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Нет серверов',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textDim,
                decoration: TextDecoration.none,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Добавьте сервер для подключения',
              style: TextStyle(color: AppColors.textDark),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: servers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final server = servers[index];
        return ServerCard(
          server: server,
          isSelected: server.id == selectedId,
          onTap: () => onSelect(server),
          onDelete: () => onDelete(server),
        );
      },
    );
  }
}
