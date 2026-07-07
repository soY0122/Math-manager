import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../database/database.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final db = ref.watch(databaseProvider);
  return ThemeModeNotifier(db);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final AppDatabase db;

  ThemeModeNotifier(this.db) : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    try {
      final savedTheme = db.settingsBox.get('themeMode', defaultValue: 'light') as String;
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
      await db.settingsBox.put('themeMode', val);
    } catch (_) {}
  }
}
