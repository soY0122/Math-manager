import 'package:hive_flutter/hive_flutter.dart';

class AppDatabase {
  late final Box studentsBox;
  late final Box attendancesBox;
  late final Box homeworksBox;
  late final Box examsBox;
  late final Box examRecordsBox;
  late final Box schedulesBox;
  late final Box backupBox;
  late final Box settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    studentsBox = await Hive.openBox('students');
    attendancesBox = await Hive.openBox('attendances');
    homeworksBox = await Hive.openBox('homeworks');
    examsBox = await Hive.openBox('exams');
    examRecordsBox = await Hive.openBox('exam_records');
    schedulesBox = await Hive.openBox('schedules');
    backupBox = await Hive.openBox('backup');
    settingsBox = await Hive.openBox('settings');
    _watchForChanges();
  }

  void _watchForChanges() {
    final boxesToWatch = [
      studentsBox,
      attendancesBox,
      homeworksBox,
      examsBox,
      examRecordsBox,
      schedulesBox,
    ];
    for (final box in boxesToWatch) {
      box.watch().listen((event) {
        settingsBox.put('data_changed_since_last_backup', true);
      });
    }
  }

  Future<void> close() async {
    await Hive.close();
  }

  // Clear all data for reset/testing
  Future<void> clearAll() async {
    await studentsBox.clear();
    await attendancesBox.clear();
    await homeworksBox.clear();
    await examsBox.clear();
    await examRecordsBox.clear();
    await schedulesBox.clear();
  }
}
