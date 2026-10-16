// lib/ui/screens/settings_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

import '../../services/app_list_service.dart';
import '../../services/auto_update_service.dart';
import '../../vpn/models/server_models.dart';
import '../app_controller.dart';
import '../widgets/glass_card.dart';
import '../widgets/update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = false;
  bool _loadingRunning = false;
  bool _showRunning = false;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _domainController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounceTimer;
  String _appVersion = '1.0.0';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _searchController.addListener(() {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() => _searchQuery = _searchController.text.toLowerCase());
        }
      });
    });
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = info.version);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _checkUpdateManual() async {
    if (!Platform.isWindows) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0a1f14),
          content: Text(
            'Автообновление доступно только на Windows',
            style: TextStyle(color: Color(0xFFff4444)),
          ),
        ),
      );
      return;
    }
    setState(() => _checkingUpdate = true);
    UpdateInfo? update;
    try {
      update = await AutoUpdateService.checkForUpdate();
    } catch (e) {
      // ignore network errors
    }
    if (mounted) setState(() => _checkingUpdate = false);

    if (update != null && mounted) {
      final updateInfo = update;
      final shouldUpdate = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => UpdateAvailableDialog(updateInfo: updateInfo),
      );
      if (shouldUpdate == true && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
              builder: (ctx) => const Scaffold(
            backgroundColor: Colors.transparent,
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00ff88)),
            ),
          ),
        );
        try {
          await AutoUpdateService.downloadAndInstall(update);
        } catch (e) {
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF0a1f14),
                content: Text(
                  'Ошибка обновления: $e',
                  style: const TextStyle(color: Color(0xFFff4444)),
                ),
              ),
            );
          }
        }
      }
    } else if (mounted) {
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0a1f14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x2E00ff88)),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF00ff88)),
              SizedBox(width: 12),
              Text(
                'Обновлений нет',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ],
          ),
          content: const Text(
            'Вы используете последнюю версию приложения.',
            style: TextStyle(color: Color(0xFF88b89a)),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00ff88),
                foregroundColor: const Color(0xFF0a1f14),
              ),
              child: const Text('Ок'),
            ),
          ],
        ),
      );
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    _domainController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    if (!widget.controller.splitTunnelingSupported) return;
    setState(() => _loading = true);
    await widget.controller.refreshInstalledApps();
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadRunning() async {
    if (!widget.controller.splitTunnelingSupported) return;
    setState(() => _loadingRunning = true);
    await widget.controller.loadRunningProcesses();
    if (!mounted) return;
    setState(() => _loadingRunning = false);
  }

  Future<void> _addCustomApp() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0a1f14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0x2E00ff88)),
        ),
        title: const Text(
          'Добавить приложение',
          style: TextStyle(color: Color(0xFFe8f5e9)),
        ),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Color(0xFFe8f5e9)),
          decoration: InputDecoration(
            hintText: Platform.isWindows
                ? r'C:\Path\To\app.exe'
                : '/Applications/App.app',
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
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      await widget.controller.addCustomApp(result);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0a1f14),
          content: Text(
            'Приложение добавлено',
            style: TextStyle(color: Color(0xFFe8f5e9)),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0a1f14),
          content: Text(
            'Ошибка: $e',
            style: const TextStyle(color: Color(0xFFff4444)),
          ),
        ),
      );
    }
  }

  Future<void> _addDomain() async {
    final rawInput = _domainController.text.trim();
    final domain = _normalizeDomain(rawInput);
    if (domain.isEmpty) return;
    if (!_isValidDomain(domain)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFF0a1f14),
          content: Text(
            'Введите корректный домен',
            style: TextStyle(color: Color(0xFFff4444)),
          ),
        ),
      );
      return;
    }
    widget.controller.addExcludedDomain(domain);
    _domainController.clear();
  }

  bool _isValidDomain(String domain) {
    if (domain.isEmpty) return false;
    if (domain.startsWith('*.')) {
      final suffix = domain.substring(2);
      return suffix.isNotEmpty && suffix.contains('.');
    }
    return domain.contains('.');
  }

  String _normalizeDomain(String input) {
    var domain = input.trim().toLowerCase();
    if (domain.startsWith('https://')) {
      domain = domain.substring(8);
    } else if (domain.startsWith('http://')) {
      domain = domain.substring(7);
    }
    if (domain.startsWith('www.')) {
      domain = domain.substring(4);
    }
    domain = domain.split('/').first;
    domain = domain.split(':').first;
    return domain;
  }

  List<InstalledApp> get _filteredRunningProcesses {
    final installedNames = widget.controller.installedApps
        .map((a) => a.processName.toLowerCase())
        .toSet();
    final procs = widget.controller.runningProcesses.where((p) {
      final isSelected = widget.controller.selectedApps.contains(p.id);
      final isInInstalled = installedNames.contains(p.processName.toLowerCase());
      return !isSelected && !isInInstalled;
    }).toList();
    if (_searchQuery.isEmpty) return procs;
    return procs.where((app) {
      return app.displayName.toLowerCase().contains(_searchQuery) ||
          app.id.toLowerCase().contains(_searchQuery) ||
          app.processName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  List<InstalledApp> get _myApps {
    final apps = <InstalledApp>[...widget.controller.installedApps];
    for (final proc in widget.controller.runningProcesses) {
      if (widget.controller.selectedApps.contains(proc.id) &&
          !apps.any((a) => a.id == proc.id)) {
        apps.add(proc);
      }
    }
    if (_searchQuery.isEmpty) return apps;
    return apps.where((app) {
      return app.displayName.toLowerCase().contains(_searchQuery) ||
          app.id.toLowerCase().contains(_searchQuery) ||
          app.processName.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final splitSupported = controller.splitTunnelingSupported;

    return Padding(
      padding: const EdgeInsets.all(40),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTitle('Настройки'),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 32),

              // Split Tunneling
              if (splitSupported) ...[
                _buildSectionTitle('Умное туннелирование'),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SegmentedButton<SplitTunnelMode>(
                        segments: const [
                          ButtonSegment(
                            value: SplitTunnelMode.disabled,
                            label: Text('Выкл'),
                            icon: Icon(Icons.block),
                          ),
                          ButtonSegment(
                            value: SplitTunnelMode.excludeSelectedApps,
                            label: Text('Исключить'),
                            icon: Icon(Icons.remove_circle_outline),
                          ),
                          ButtonSegment(
                            value: SplitTunnelMode.includeOnlySelectedApps,
                            label: Text('Только'),
                            icon: Icon(Icons.check_circle_outline),
                          ),
                        ],
                        selected: {controller.splitMode},
                        onSelectionChanged: (modes) =>
                            controller.setSplitMode(modes.first),
                        style: SegmentedButton.styleFrom(
                          backgroundColor: const Color(0x08FFFFFF),
                          selectedBackgroundColor: const Color(
                            0xFF00ff88,
                          ).withOpacity(0.2),
                          selectedForegroundColor: const Color(0xFF00ff88),
                          foregroundColor: const Color(0xFF88b89a),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSplitTunnelDescription(controller.splitMode),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'Поиск приложений и процессов...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF4a7a5c),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF4a7a5c),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0x08FFFFFF),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Color(0xFF88b89a),
                            ),
                            onPressed: _loadApps,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _addCustomApp,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Добавить приложение'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00ff88),
                          side: BorderSide(
                            color: const Color(0xFF00ff88).withOpacity(0.3),
                          ),
                          backgroundColor: const Color(
                            0xFF00ff88,
                          ).withOpacity(0.06),
                          minimumSize: const Size(double.infinity, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Running processes toggle
                      Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: () {
                            setState(() => _showRunning = !_showRunning);
                            if (_showRunning &&
                                controller.runningProcesses.isEmpty) {
                              _loadRunning();
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x08FFFFFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(
                                  0xFF00ff88,
                                ).withOpacity(0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _showRunning
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: const Color(0xFF88b89a),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Запущенные процессы',
                                  style: TextStyle(
                                    color: Color(0xFF88b89a),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Spacer(),
                                if (_loadingRunning)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF00ff88),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_showRunning) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 200,
                          child: _RunningProcessesList(
                            controller: controller,
                            processes: _filteredRunningProcesses,
                            splitMode: controller.splitMode,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: const Color(
                                0xFF00ff88,
                              ).withOpacity(0.15),
                              height: 1,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              'Мои приложения',
                              style: TextStyle(
                                color: Color(0xFF88b89a),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: const Color(
                                0xFF00ff88,
                              ).withOpacity(0.15),
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 300,
                        child: _loading
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF00ff88),
                                ),
                              )
                            : _AppsList(
                                controller: controller,
                                apps: _myApps,
                                splitMode: controller.splitMode,
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Domains
                _buildSectionTitle('Исключённые домены'),
                const SizedBox(height: 16),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              type: MaterialType.transparency,
                              child: TextField(
                                controller: _domainController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: 'example.com или *.ru',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF4a7a5c),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0x08FFFFFF),
                                ),
                                onSubmitted: (_) => _addDomain(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _addDomain,
                            child: const Text('Добавить'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: controller.excludedDomains.map((domain) {
                          return Material(
                            type: MaterialType.transparency,
                            child: Chip(
                              label: Text(
                                domain,
                                style: const TextStyle(
                                  color: Color(0xFF00ff88),
                                ),
                              ),
                              deleteIcon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Color(0xFF00ff88),
                              ),
                              onDeleted: () =>
                                  controller.removeExcludedDomain(domain),
                              backgroundColor: const Color(
                                0xFF00ff88,
                              ).withOpacity(0.1),
                              side: const BorderSide(color: Color(0xFF00ff88)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ] else ...[
                const Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 64,
                        color: Color(0xFFffaa00),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Split tunneling доступен только на Windows',
                        style: TextStyle(color: Color(0xFF88b89a)),
                      ),
                    ],
                  ),
                ),
              ],

              // FAQ
              _buildSectionTitle('FAQ'),
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  children: [
                    _buildFaqItem(
                      'Что такое умное туннелирование?',
                      'Это режим, в котором вы выбираете, какие приложения работают через VPN, а какие — напрямую. Например, можно отправить игру в обход VPN, а браузер оставить под защитой.',
                    ),
                    _buildFaqItem(
                      'Как добавить приложение?',
                      'Есть два способа: 1) Выбрать из списка запущенных процессов и нажать «Добавить». 2) Нажать кнопку «Добавить приложение» и указать путь к .exe файлу вручную.',
                    ),
                    _buildFaqItem(
                      'Почему приложение не появляется в списке?',
                      'Список «Запущенные процессы» показывает только те программы, которые работают прямо сейчас. Если приложение не запущено — добавьте его вручную по пути к .exe.',
                    ),
                    _buildFaqItem(
                      'Что делать, если приложение не работает в обход?',
                      'Некоторые программы (например, Discord или игры из лаунчеров) запускают несколько процессов. Попробуйте добавить основной .exe, а если не поможет — добавьте все процессы программы из списка запущенных.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // About
              _buildSectionTitle('О приложении'),
              const SizedBox(height: 16),
              GlassCard(
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF00ff88).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x2E00ff88)),
                      ),
                      child: const Icon(
                        Icons.rocket_launch,
                        color: Color(0xFF00ff88),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Heavy Emerald',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Версия $_appVersion',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF88b89a),
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _checkingUpdate ? null : _checkUpdateManual,
                      icon: _checkingUpdate
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF00ff88),
                              ),
                            )
                          : const Icon(Icons.refresh, size: 18),
                      label: Text(
                        _checkingUpdate ? 'Проверка...' : 'Проверить',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF00ff88),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: const Color(0xFF00ff88),
        shadows: [
          Shadow(
            color: const Color(0xFF00ff88).withOpacity(0.1),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  Widget _buildSplitTunnelDescription(SplitTunnelMode mode) {
    final String description;
    switch (mode) {
      case SplitTunnelMode.disabled:
        description =
            'Весь трафик идёт через VPN. Все приложения используют защищённое соединение.';
        break;
      case SplitTunnelMode.excludeSelectedApps:
        description =
            'Весь трафик через VPN, кроме выбранных приложений. Отмеченные программы работают напрямую.';
        break;
      case SplitTunnelMode.includeOnlySelectedApps:
        description =
            'Только выбранные приложения используют VPN. Остальной трафик идёт напрямую.';
        break;
    }
    return Text(
      description,
      style: const TextStyle(
        fontSize: 12,
        color: Color(0xFF88b89a),
        height: 1.4,
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.help_outline,
                size: 16,
                color: Color(0xFF00ff88),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              answer,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF88b89a),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppsList extends StatelessWidget {
  const _AppsList({
    required this.controller,
    required this.apps,
    required this.splitMode,
  });

  final AppController controller;
  final List<InstalledApp> apps;
  final SplitTunnelMode splitMode;

  @override
  Widget build(BuildContext context) {
    if (apps.isEmpty) {
      return const Center(
        child: Text(
          'Приложения не найдены',
          style: TextStyle(color: Color(0xFF4a7a5c)),
        ),
      );
    }
    if (splitMode == SplitTunnelMode.disabled) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, size: 48, color: Color(0xFF4a7a5c)),
            SizedBox(height: 16),
            Text(
              'Умное туннелирование отключено',
              style: TextStyle(color: Color(0xFF4a7a5c)),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: apps.length,
      itemBuilder: (context, index) {
        final app = apps[index];
        final isSelected = controller.selectedApps.contains(app.id);
        final isCustom = app.isCustom;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  app.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  app.processName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF88b89a)),
                ),
                leading: Checkbox(
                  value: isSelected,
                  onChanged: (value) =>
                      controller.toggleAppSelection(app.id, value ?? false),
                  activeColor: const Color(0xFF00ff88),
                ),
                trailing: isCustom
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Color(0xFFff4444),
                        ),
                        onPressed: () {
                          controller.removeCustomApp(app.id);
                          final messenger = ScaffoldMessenger.maybeOf(context);
                          if (messenger != null) {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF0a1f14),
                                content: Text(
                                  '${app.displayName} удалено',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          }
                        },
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RunningProcessesList extends StatelessWidget {
  const _RunningProcessesList({
    required this.controller,
    required this.processes,
    required this.splitMode,
  });

  final AppController controller;
  final List<InstalledApp> processes;
  final SplitTunnelMode splitMode;

  void _addProcess(InstalledApp app) {
    final existing = controller.installedApps.firstWhere(
      (a) => a.processName.toLowerCase() == app.processName.toLowerCase(),
      orElse: () => app,
    );
    if (existing.id != app.id) {
      controller.toggleAppSelection(existing.id, true);
    } else {
      controller.addCustomProcess(app.processName);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (splitMode == SplitTunnelMode.disabled) {
      return const Center(
        child: Text(
          'Включите Split Tunneling для выбора процессов',
          style: TextStyle(color: Color(0xFF4a7a5c)),
        ),
      );
    }
    if (processes.isEmpty) {
      return const Center(
        child: Text(
          'Нет запущенных процессов',
          style: TextStyle(color: Color(0xFF4a7a5c)),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: processes.length,
      itemBuilder: (context, index) {
        final app = processes[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  app.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                trailing: TextButton(
                  onPressed: () => _addProcess(app),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF00ff88),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Добавить'),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
