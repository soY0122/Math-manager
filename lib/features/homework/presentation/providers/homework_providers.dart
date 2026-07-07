import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/homework_repository_impl.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../domain/models/student_homework_item.dart';
import '../../../../core/database/database_provider.dart';

import '../../../../core/providers/global_providers.dart';

final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HomeworkRepositoryImpl(db);
});

final homeworkDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final homeworkAssignmentTitleProvider = StateProvider<String>((ref) => '쎈 수학 1단원 풀이 및 오답 노트');

final homeworkStreamProvider = StreamProvider<List<StudentHomeworkItem>>((ref) {
  final repository = ref.watch(homeworkRepositoryProvider);
  final selectedDate = ref.watch(homeworkDateProvider);
  final dateStr = selectedDate.toIso8601String().split('T')[0];
  final grade = ref.watch(globalGradeFilterProvider);
  
  return repository.watchHomeworkForDate(dateStr, gradeFilter: grade);
});
