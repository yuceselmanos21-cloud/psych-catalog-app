import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import '../../services/theme_service.dart';

/// Theme service provider
final themeServiceProvider = Provider<ThemeService>((ref) {
  return ThemeService();
});

/// Theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final themeService = ref.watch(themeServiceProvider);
  return ThemeNotifier(themeService);
});

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final ThemeService _themeService;

  ThemeNotifier(this._themeService) : super(ThemeMode.system) {
    _loadTheme();
    // Theme değişikliklerini dinle
    _themeService.addListener(_onThemeChanged);
  }

  void _loadTheme() {
    state = _themeService.themeMode;
  }

  void _onThemeChanged() {
    state = _themeService.themeMode;
  }

  void toggleTheme() {
    _themeService.toggleTheme();
  }

  void setTheme(ThemeMode mode) {
    _themeService.setThemeMode(mode);
  }

  @override
  void dispose() {
    _themeService.removeListener(_onThemeChanged);
    super.dispose();
  }
}
