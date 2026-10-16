// lib/services/app_list_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

class InstalledApp {
  const InstalledApp({
    required this.id,
    required this.displayName,
    required this.processName,
    this.isCustom = false,
  });

  final String id;
  final String displayName;
  final String processName;
  final bool isCustom;

  Map<String, dynamic> toJson() => {
    'id': id,
    'displayName': displayName,
    'processName': processName,
    'isCustom': isCustom,
  };

  factory InstalledApp.fromJson(Map<String, dynamic> json) => InstalledApp(
    id: json['id'] as String,
    displayName: json['displayName'] as String,
    processName: json['processName'] as String,
    isCustom: json['isCustom'] as bool? ?? false,
  );
}

class AppListService {
  static const String _selectedAppsKey = 'selected_apps';
  static const String _customAppsKey = 'custom_apps';
  static const String _cachedSystemAppsKey = 'cached_system_apps';

  List<InstalledApp>? _cache;

  /// Возвращает полный список приложений (системные + кастомные).
  Future<List<InstalledApp>> getInstalledApps({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _cache != null) {
      return _cache!;
    }

    final customApps = await _loadCustomApps();

    if (Platform.isWindows) {
      // Пытаемся загрузить кэшированный список системных приложений,
      // если не требуется принудительное обновление.
      List<InstalledApp> systemApps;
      if (!forceRefresh) {
        systemApps = await _loadCachedSystemApps();
      } else {
        systemApps = [];
      }

      // Если кэша нет или был запрошен forceRefresh, выполняем полное сканирование.
      if (systemApps.isEmpty) {
        systemApps = await _getWindowsApps();
        await _saveCachedSystemApps(systemApps);
      }

      // Объединяем системные и кастомные приложения.
      final allApps = <InstalledApp>[];
      final seenIds = <String>{};
      for (final app in [...customApps, ...systemApps]) {
        if (!seenIds.contains(app.id)) {
          seenIds.add(app.id);
          allApps.add(app);
        }
      }

      allApps.sort((a, b) => a.displayName.compareTo(b.displayName));
      _cache = allApps;
      return _cache!;
    }

    _cache = <InstalledApp>[];
    return _cache!;
  }

  // ---------- Кэширование системных приложений ----------
  Future<List<InstalledApp>> _loadCachedSystemApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_cachedSystemAppsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) {
            final json = e as Map<String, dynamic>;
            return InstalledApp.fromJson({...json, 'isCustom': true});
          })
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCachedSystemApps(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_cachedSystemAppsKey, jsonString);
  }

  // ---------- Популярные приложения (fallback) ----------
  Future<List<InstalledApp>> _getWindowsApps() async {
    final apps = <InstalledApp>[];

    final appData = Platform.environment['APPDATA'] ?? '';
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)';
    final programFiles = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';

    final fallbackApps = <Map<String, String>>[
      if (appData.isNotEmpty)
        {'name': 'Telegram', 'path': '$appData\Telegram Desktop\Telegram.exe'},
      {'name': 'Steam', 'path': '$programFilesX86\Steam\Steam.exe'},
      {'name': 'Chrome', 'path': '$programFiles\Google\Chrome\Application\chrome.exe'},
      {'name': 'Chrome (x86)', 'path': '$programFilesX86\Google\Chrome\Application\chrome.exe'},
      {'name': 'Firefox', 'path': '$programFiles\Mozilla Firefox\firefox.exe'},
      {'name': 'Firefox (x86)', 'path': '$programFilesX86\Mozilla Firefox\firefox.exe'},
      {'name': 'Edge', 'path': '$programFilesX86\Microsoft\Edge\Application\msedge.exe'},
      {'name': 'Edge', 'path': '$programFiles\Microsoft\Edge\Application\msedge.exe'},
    ];
    for (final fa in fallbackApps) {
      if (File(fa['path']!).existsSync()) {
        apps.add(
          InstalledApp(
            id: fa['path']!,
            displayName: fa['name']!,
            processName: fa['path']!.split('\\').last,
            isCustom: false,
          ),
        );
      }
    }

    // Удаляем дубликаты по id
    final unique = <String, InstalledApp>{};
    for (final app in apps) {
      unique[app.id] = app;
    }
    return unique.values.toList();
  }

  // ---------- Управление кастомными приложениями ----------
  Future<List<InstalledApp>> getCustomApps() async {
    return _loadCustomApps();
  }

  Future<void> addCustomApp(InstalledApp app) async {
    final current = await _loadCustomApps();
    if (current.any((a) => a.id == app.id)) return;
    current.add(InstalledApp(
      id: app.id,
      displayName: app.displayName,
      processName: app.processName,
      isCustom: true,
    ));
    await _saveCustomApps(current);
    _cache = null; // сбрасываем кэш
  }

  /// Удаляет кастомное приложение по id
  Future<void> removeCustomApp(String id) async {
    final current = await _loadCustomApps();
    current.removeWhere((a) => a.id == id);
    await _saveCustomApps(current);
    _cache = null;
  }

  Future<List<InstalledApp>> _loadCustomApps() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_customAppsKey);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(jsonString);
      return list
          .map((e) => InstalledApp.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveCustomApps(List<InstalledApp> apps) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(apps.map((a) => a.toJson()).toList());
    await prefs.setString(_customAppsKey, jsonString);
  }

  // ---------- Сохранение / загрузка выбранных приложений ----------
  Future<void> saveSelectedApps(Set<String> selectedAppIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_selectedAppsKey, selectedAppIds.toList());
  }

  Future<Set<String>> loadSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_selectedAppsKey) ?? [];
    return list.toSet();
  }

  // ---------- Запущенные процессы Windows ----------
  Future<List<InstalledApp>> getRunningProcesses() async {
    if (!Platform.isWindows) return [];
    final apps = <InstalledApp>[];
    final seen = <String>{};

    try {
      final result = await Process.run('tasklist', ['/FO', 'CSV', '/NH'], runInShell: true);
      if (result.exitCode == 0) {
        final lines = const LineSplitter().convert(result.stdout.toString());
        for (final line in lines) {
          final parts = _parseCsvLine(line);
          if (parts.length < 2) continue;
          final name = parts[0].replaceAll('"', '').trim();
          final pid = parts[1].replaceAll('"', '').trim();
          if (name.isEmpty || pid.isEmpty || name == 'powershell.exe' || name == 'cmd.exe') continue;
          final id = name.toLowerCase();
          if (seen.add(id)) {
            apps.add(InstalledApp(
              id: id,
              displayName: name,
              processName: name,
            ));
          }
        }
      }
    } catch (_) {}

    apps.sort((a, b) => a.displayName.compareTo(b.displayName));
    return apps;
  }

  List<String> _parseCsvLine(String line) {
    final parts = <String>[];
    var current = '';
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
      } else if (ch == ',' && !inQuotes) {
        parts.add(current);
        current = '';
      } else {
        current += ch;
      }
    }
    parts.add(current);
    return parts;
  }
}
