import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Информация о доступном обновлении.
class UpdateInfo {
  final String version;
  final String downloadUrl;
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.downloadUrl,
    required this.releaseNotes,
  });
}

/// Сервис автообновления через GitHub Releases.
///
/// Работает только на Windows. Скачивает ZIP, распаковывает его,
/// заменяет все файлы (EXE, DLLs, data/) через updater.bat и перезапускает.
class AutoUpdateService {
  static const String _owner = 'enidopoz';
  static const String _repo = 'heavy-emerald-vpn-releases';
  static const String _assetName = 'HeavyEmerald-Windows-x64.zip';

  /// Текущая версия приложения (из pubspec.yaml → package_info_plus).
  static Future<String?> getCurrentVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      return null;
    }
  }

  /// Проверяет GitHub API на наличие нового релиза.
  /// Возвращает [UpdateInfo] если найдена более новая версия, иначе `null`.
  static Future<UpdateInfo?> checkForUpdate() async {
    if (!Platform.isWindows) return null;

    try {
      final currentVersion = await getCurrentVersion();
      if (currentVersion == null || currentVersion.isEmpty) return null;

      final uri = Uri.parse(
        'https://api.github.com/repos/$_owner/$_repo/releases/latest',
      );
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (data['tag_name'] as String? ?? '').trim();
      if (tagName.isEmpty) return null;

      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;

      if (!_isNewerVersion(latestVersion, currentVersion)) return null;

      final assets = data['assets'] as List<dynamic>? ?? [];
      String? downloadUrl;
      for (final asset in assets) {
        if (asset is Map<String, dynamic> && asset['name'] == _assetName) {
          downloadUrl = asset['browser_download_url'] as String?;
          break;
        }
      }
      if (downloadUrl == null || downloadUrl.isEmpty) return null;

      return UpdateInfo(
        version: latestVersion,
        downloadUrl: downloadUrl,
        releaseNotes: (data['body'] as String? ?? '').trim(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Семантическое сравнение версий `a > b`.
  static bool _isNewerVersion(String latest, String current) {
    List<int> parse(String v) {
      return v.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    }

    final l = parse(latest);
    final c = parse(current);

    for (var i = 0; i < math.max(l.length, c.length); i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  /// Скачивает ZIP, пишет updater.bat и запускает его.
  /// Завершает текущий процесс через `exit(0)`.
  static Future<void> downloadAndInstall(UpdateInfo info) async {
    if (!Platform.isWindows) return;

    final currentExe = File(Platform.resolvedExecutable);
    final appDir = currentExe.parent.path;

    final tempDir = Directory(
      '${Platform.environment['TEMP']}\\heavy_emerald_update',
    );
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    final zipFile = File('${tempDir.path}\\$_assetName');

    // Скачивание ZIP
    final response = await http.get(Uri.parse(info.downloadUrl));
    if (response.statusCode != 200) {
      throw Exception('Download failed: HTTP ${response.statusCode}');
    }
    await zipFile.writeAsBytes(response.bodyBytes);

    // Распаковка ZIP через PowerShell
    final extractDir = Directory('${tempDir.path}\\extracted');
    await extractDir.create();
    final psResult = await Process.run(
      'powershell.exe',
      [
        '-Command',
        'Expand-Archive -Path "${_escapePs(zipFile.path)}" -DestinationPath "${_escapePs(extractDir.path)}" -Force',
      ],
      runInShell: false,
    );
    if (psResult.exitCode != 0) {
      throw Exception('Extract failed: ${psResult.stderr}');
    }

    // Пишем updater.bat
    final updaterBat = File('${tempDir.path}\\updater.bat');
    final batContent = '''@echo off
setlocal EnableExtensions

set "APP_DIR=${_escapeBat(appDir)}"
set "SOURCE_DIR=${_escapeBat(extractDir.path)}"
set "UPDATER_DIR=${_escapeBat(tempDir.path)}"

echo Waiting for app to close...
timeout /t 2 /nobreak >nul

echo Replacing files...
xcopy /E /Y /I "%SOURCE_DIR%\\*" "%APP_DIR%" >nul 2>&1

echo Starting updated app...
start "" "%APP_DIR%\\HeavyEmerald.exe"

echo Cleaning up...
rmdir /S /Q "%UPDATER_DIR%"

endlocal
'''; // <-- newline intentional for batch safety
    await updaterBat.writeAsString(batContent);

    // Запускаем updater в detached-режиме, чтобы он пережил закрытие приложения
    await Process.start(
      'cmd.exe',
      ['/c', updaterBat.path],
      mode: ProcessStartMode.detached,
    );

    // Закрываем текущее приложение
    exit(0);
  }

  /// Экранирует символ `%` для batch-файла.
  static String _escapeBat(String path) {
    return path.replaceAll('%', '%%');
  }

  /// Экранирует кавычки для PowerShell.
  static String _escapePs(String path) {
    return path.replaceAll('"', '`"');
  }
}
