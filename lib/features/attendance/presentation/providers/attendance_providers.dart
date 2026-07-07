import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/attendance_repository_impl.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../domain/models/student_attendance_item.dart';
import '../../../../core/database/database_provider.dart';

import '../../../../core/providers/global_providers.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return AttendanceRepositoryImpl(db);
});

final attendanceDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final attendanceStreamProvider = StreamProvider<List<StudentAttendanceItem>>((ref) {
  final repository = ref.watch(attendanceRepositoryProvider);
  final selectedDate = ref.watch(attendanceDateProvider);
  final dateStr = selectedDate.toIso8601String().split('T')[0];
  final grade = ref.watch(globalGradeFilterProvider);
  
  return repository.watchAttendanceForDate(dateStr, gradeFilter: grade);
});
