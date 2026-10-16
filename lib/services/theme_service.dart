// lib/services/theme_service.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeMode { system, light, dark }

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';

  final SharedPreferences _prefs;

  ThemeService(this._prefs);

  AppThemeMode get currentMode {
    final index = _prefs.getInt(_themeKey) ?? 0;
    return AppThemeMode.values[index.clamp(0, AppThemeMode.values.length - 1)];
  }

  Future<void> setMode(AppThemeMode mode) async {
    await _prefs.setInt(_themeKey, mode.index);
    notifyListeners();
  }

  ThemeMode get themeMode {
    switch (currentMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }
}
