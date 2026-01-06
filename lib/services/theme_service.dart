import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeService extends ChangeNotifier {
  static const String _themeKey = 'theme_mode';
  static ThemeService? _instance;
  
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  // Singleton pattern
  factory ThemeService() {
    _instance ??= ThemeService._internal();
    return _instance!;
  }

  ThemeService._internal() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);
      if (themeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeString,
          orElse: () => ThemeMode.light,
        );
        notifyListeners();
      }
    } catch (e) {
      print('⚠️ Tema yükleme hatası: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    // ✅ Önce UI'ı güncelle, sonra kaydet
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, mode.toString());
    } catch (e) {
      print('⚠️ Tema kaydetme hatası: $e');
    }
  }

  void toggleTheme() {
    // ✅ Anlık güncelleme için önce notifyListeners çağrılıyor
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _themeMode = newMode;
    notifyListeners(); // ✅ Anlık UI güncellemesi
    // ✅ Arka planda kaydet
    setThemeMode(newMode);
  }
}

