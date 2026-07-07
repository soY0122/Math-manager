import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('themeMode') ?? 'light';
      switch (savedTheme) {
        case 'dark':
          state = ThemeMode.dark;
          break;
        case 'light':
        default:
          state = ThemeMode.light;
          break;
      }
    } catch (_) {
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    String val = mode == ThemeMode.dark ? 'dark' : 'light';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('themeMode', val);
    } catch (_) {}
  }
}
