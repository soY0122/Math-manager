import '../models/settings_models.dart';

abstract class SettingsRepository {
  Stream<List<ScheduleItem>> watchSchedulesForDate(String dateStr);
  Stream<List<ScheduleItem>> watchAllSchedules();
  Future<void> addSchedule({
    required String title,
    required String date,
    required String type,
    String? memo,
    String? studentId,
  });
  Future<void> updateSchedule({
    required String id,
    required String title,
    required String date,
    String? memo,
  });
  Future<void> deleteSchedule(String id);
  Stream<AcademyStats> watchAcademyStats({int? gradeFilter});
}
