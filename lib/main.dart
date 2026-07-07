import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database_seeder.dart';
import 'core/database/database_provider.dart';
import 'core/database/database.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'core/theme/theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Korean date formatting
  await initializeDateFormatting('ko_KR', null);

  // Initialize Hive AppDatabase
  final db = AppDatabase();
  await db.init();
  WidgetsBinding.instance.addObserver(DatabaseAutoBackupObserver(db));

  // Seed database with mock data
  try {
    await seedDatabase(db);
  } catch (e) {
    debugPrint('Database seeding warning: $e');
  }

  // Override databaseProvider in ProviderContainer
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
    ],
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MathManagerApp(),
    ),
  );
}

class MathManagerApp extends ConsumerWidget {
  const MathManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Math Manager',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}

class DatabaseAutoBackupObserver extends WidgetsBindingObserver {
  final AppDatabase db;
  DatabaseAutoBackupObserver(this.db);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _triggerAutoBackup();
    }
  }

  Future<void> _triggerAutoBackup() async {
    final enabled = db.settingsBox.get('auto_backup_enabled', defaultValue: false) as bool;
    if (!enabled) return;

    final changed = db.settingsBox.get('data_changed_since_last_backup', defaultValue: false) as bool;
    if (!changed) return;

    final todayStr = DateTime.now().toIso8601String().split('T')[0];
    final lastBackup = db.settingsBox.get('last_backup_date') as String?;

    if (lastBackup == todayStr) {
      return;
    }

    try {
      await db.backupBox.put('students', db.studentsBox.values.toList());
      await db.backupBox.put('attendances', db.attendancesBox.values.toList());
      await db.backupBox.put('homeworks', db.homeworksBox.values.toList());
      await db.backupBox.put('exams', db.examsBox.values.toList());
      await db.backupBox.put('exam_records', db.examRecordsBox.values.toList());
      await db.backupBox.put('schedules', db.schedulesBox.values.toList());

      await db.settingsBox.put('last_backup_date', todayStr);
      await db.settingsBox.put('data_changed_since_last_backup', false);
      debugPrint('Auto backup completed successfully for $todayStr');
    } catch (e) {
      debugPrint('Auto backup failed: $e');
    }
  }
}