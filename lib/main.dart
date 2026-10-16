// lib/main.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/logging/session_logger.dart';
import 'services/app_list_service.dart';
import 'services/auto_update_service.dart';
import 'services/config_storage.dart';
import 'services/server_repository.dart';
import 'services/theme_service.dart';
import 'ui/app_controller.dart';
import 'ui/screens/connect_screen.dart';
import 'ui/screens/servers_screen.dart';
import 'ui/screens/settings_screen.dart';
import 'ui/screens/subscription_screen.dart';
import 'ui/theme/app_theme.dart';
import 'ui/widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final themeService = ThemeService(prefs);

  runApp(VpsEmeraldApp(themeService: themeService));
}

class VpsEmeraldApp extends StatefulWidget {
  const VpsEmeraldApp({super.key, required this.themeService});

  final ThemeService themeService;

  @override
  State<VpsEmeraldApp> createState() => _VpsEmeraldAppState();
}

class _VpsEmeraldAppState extends State<VpsEmeraldApp> {
  late final AppController _controller;
  late final SessionLogger _logger;
  int _index = 0;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _logger = SessionLogger();
    _controller = AppController(
      serverRepository: ServerRepository(logger: _logger),
      appListService: AppListService(),
      logger: _logger,
    );
    _initializeAsync();
  }

  Future<void> _initializeAsync() async {
    await _logger.initFile();
    final storage = ConfigStorage();
    final savedServers = await storage.loadServers();
    for (final server in savedServers) {
      _controller.serverRepository.upsert(server.toProfile());
    }
    if (_controller.servers.isNotEmpty && _controller.selectedServer == null) {
      _controller.selectServer(_controller.servers.first.id);
    }
    await _controller.initialize();

    setState(() => _initialized = true);
    _controller.addListener(_rebuild);

    if (mounted) {
      await _checkForUpdates();
    }
  }

  Future<void> _checkForUpdates() async {
    if (!Platform.isWindows) return;
    try {
      final update = await AutoUpdateService.checkForUpdate();
      if (update != null && mounted) {
        final shouldUpdate = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => UpdateAvailableDialog(updateInfo: update),
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
              Navigator.of(context).pop(); // close loading
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
      }
    } catch (_) {
      // Игнорируем ошибки автообновления при старте
    }
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_rebuild);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeService,
      builder: (context, _) {
        return MaterialApp(
          title: 'Heavy Emerald',
          debugShowCheckedModeBanner: false,
          theme: AppThemes.dark(),
          darkTheme: AppThemes.dark(),
          themeMode: ThemeMode.dark,
          home: _initialized
              ? AdaptiveScaffold(
                  selectedIndex: _index,
                  onNavigationChanged: (value) => setState(() => _index = value),
                  navigationItems: const [
                    AdaptiveNavigationItem(
                      iconSymbol: '◈',
                      label: 'Панель управления',
                    ),
                    AdaptiveNavigationItem(
                      iconSymbol: '◎',
                      label: 'Серверы',
                    ),
                    AdaptiveNavigationItem(
                      iconSymbol: '◉',
                      label: 'Подписка',
                    ),
                    AdaptiveNavigationItem(
                      iconSymbol: '◆',
                      label: 'Настройки',
                    ),
                  ],
                  bodyBuilder: (context, index) {
                    switch (index) {
                      case 0:
                        return ConnectScreen(controller: _controller);
                      case 1:
                        return ServersScreen(controller: _controller);
                      case 2:
                        return SubscriptionScreen(controller: _controller);
                      case 3:
                        return SettingsScreen(controller: _controller);
                      default:
                        return ConnectScreen(controller: _controller);
                    }
                  },
                )
              : const Scaffold(
                  backgroundColor: AppColors.bg,
                  body: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.emerald,
                    ),
                  ),
                ),
        );
      },
    );
  }
}
