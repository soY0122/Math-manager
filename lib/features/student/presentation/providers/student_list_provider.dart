import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/repositories/student_repository_impl.dart';
import '../../domain/repositories/student_repository.dart';
import '../../domain/models/student_stats.dart';
import '../../../../core/providers/global_providers.dart';

final studentRepositoryProvider = Provider<StudentRepository>((ref) {
  return StudentRepositoryImpl();
});

final todayAttendancesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final today = DateTime.now();
  final targetTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
  return FirebaseFirestore.instance
      .collection('attendances')
      .where('date', isEqualTo: targetTimestamp)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});

final todayHomeworksProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final today = DateTime.now();
  final targetTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
  return FirebaseFirestore.instance
      .collection('homeworks')
      .where('date', isEqualTo: targetTimestamp)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => doc.data()).toList());
});

final studentSearchProvider = StateProvider<String>((ref) => '');

final studentFilterProvider = StateProvider<String?>((ref) => null);

final studentsStreamProvider = StreamProvider<List<StudentStats>>((ref) {
  final repository = ref.watch(studentRepositoryProvider);
  final search = ref.watch(studentSearchProvider);
  final gradeFilter = ref.watch(globalGradeFilterProvider);
  final filter = ref.watch(studentFilterProvider);
  
  final stream = repository.watchStudents(
    search: search.isEmpty ? null : search,
    gradeFilter: gradeFilter,
  );

  final todayAttendances = ref.watch(todayAttendancesProvider).value ?? [];
  final todayHomeworks = ref.watch(todayHomeworksProvider).value ?? [];

  return stream.map((students) {
    if (filter == null || filter.isEmpty) {
      return students;
    }

    if (filter == 'at_risk') {
      return students.where((s) {
        return s.riskScore >= 4;
      }).toList();
    }

    if (filter == 'homework_incomplete') {
      final incompleteIds = todayHomeworks
          .where((h) => h['status'] == 'INCOMPLETE')
          .map((h) => h['studentId'] as String)
          .toSet();
      return students.where((s) => incompleteIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_present') {
      final presentIds = todayAttendances
          .where((a) => a['status'] == 'ATTENDANCE' || a['status'] == 'EARLY_LEAVE')
          .map((a) => a['studentId'] as String)
          .toSet();
      return students.where((s) => presentIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_late') {
      final lateIds = todayAttendances
          .where((a) => a['status'] == 'LATE')
          .map((a) => a['studentId'] as String)
          .toSet();
      return students.where((s) => lateIds.contains(s.id)).toList();
    }

    if (filter == 'attendance_absent') {
      final absentIds = todayAttendances
          .where((a) => a['status'] == 'ABSENT')
          .map((a) => a['studentId'] as String)
          .toSet();
      return students.where((s) => absentIds.contains(s.id)).toList();
    }

    return students;
  });
});

final collapsedGradesProvider = StateProvider<Set<int>>((ref) => <int>{});

final sortedActiveStudentIdsProvider = StreamProvider<List<String>>((ref) {
  final gradeFilter = ref.watch(globalGradeFilterProvider);
  final repository = ref.watch(studentRepositoryProvider);
  return repository.watchStudents(gradeFilter: gradeFilter).map((students) {
    return students.map((s) => s.id).toList();
  });
});
