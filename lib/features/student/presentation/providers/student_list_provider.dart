import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../../domain/repositories/student_repository.dart';
import '../../domain/models/student_stats.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/providers/global_providers.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return StudentRepositoryImpl(db);
});

final studentSearchProvider = StateProvider<String>((ref) => '');

final studentFilterProvider = StateProvider<String?>((ref) => null);

final studentsStreamProvider = StreamProvider<List<StudentStats>>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  final search = ref.watch(studentSearchProvider);
  final gradeFilter = ref.watch(globalGradeFilterProvider);
  final filter = ref.watch(studentFilterProvider);
  final db = ref.watch(databaseProvider);
  
  final stream = repository.watchStudents(
    search: search.isEmpty ? null : search,
    gradeFilter: gradeFilter,
  );

  return stream.map((students) {
    if (filter == null || filter.isEmpty) {
      return students;
    }

    final todayStr = DateTime.now().toIso8601String().split('T')[0];

    if (filter == 'at_risk') {
      return students.where((s) {
        return s.growthRate < -5.0 || s.attendanceRate < 0.85 || s.homeworkCompletionRate < 0.70;
      }).toList();
    }

    if (filter == 'homework_incomplete') {
      final incompleteIds = db.homeworksBox.values
          .where((h) => h['date'] == todayStr && h['status'] == 'INCOMPLETE')
          .map((h) => h['student_id'] as int)
          .toSet();
      return students.where((s) => incompleteIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_present') {
      final presentIds = db.attendancesBox.values
          .where((a) => a['date'] == todayStr && a['status'] == 'ATTENDANCE')
          .map((a) => a['student_id'] as int)
          .toSet();
      return students.where((s) => presentIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_late') {
      final lateIds = db.attendancesBox.values
          .where((a) => a['date'] == todayStr && a['status'] == 'LATE')
          .map((a) => a['student_id'] as int)
          .toSet();
      return students.where((s) => lateIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_absent') {
      final absentIds = db.attendancesBox.values
          .where((a) => a['date'] == todayStr && a['status'] == 'ABSENT')
          .map((a) => a['student_id'] as int)
          .toSet();
      return students.where((s) => absentIds.contains(s.id)).toList();
    }

    return students;
  });
});

final collapsedGradesProvider = StateProvider<Set<int>>((ref) => <int>{});

final sortedActiveStudentIdsProvider = StreamProvider<List<int>>((ref) {
  final gradeFilter = ref.watch(globalGradeFilterProvider);
  final repository = ref.watch(studentRepositoryProvider);
  // Watch active students under the global grade filter context, sorted in grouped order
  return repository.watchStudents(gradeFilter: gradeFilter).map((students) {
    return students.map((s) => s.id).toList();
  });
});
