import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/settings_repository_impl.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/models/settings_models.dart';
import '../../../../core/providers/global_providers.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepositoryImpl();
});

final scheduleSelectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final dateSchedulesStreamProvider = StreamProvider<List<ScheduleItem>>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  final selectedDate = ref.watch(scheduleSelectedDateProvider);
  final dateStr = selectedDate.toIso8601String().split('T')[0];
  
  return repository.watchSchedulesForDate(dateStr);
});

final allSchedulesStreamProvider = StreamProvider<List<ScheduleItem>>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  return repository.watchAllSchedules();
});

final settingsExamGroupFilterProvider = StateProvider<String?>((ref) => null);

final academyStatsStreamProvider = StreamProvider<AcademyStats>((ref) {
  final repository = ref.watch(settingsRepositoryProvider);
  final grade = ref.watch(globalGradeFilterProvider);
  final examGroupId = ref.watch(settingsExamGroupFilterProvider);
  return repository.watchAcademyStats(gradeFilter: grade, examGroupId: examGroupId);
});
