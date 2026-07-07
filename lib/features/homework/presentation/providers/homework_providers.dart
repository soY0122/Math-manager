import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/homework_repository_impl.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../domain/models/student_homework_item.dart';


final homeworkRepositoryProvider = Provider<HomeworkRepository>((ref) {
  return HomeworkRepositoryImpl();
});

final homeworkDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

final homeworkAssignmentTitleProvider = StateProvider<String>((ref) => '쎈 수학 1단원 풀이 및 오답 노트');

final homeworkGradeFilterProvider = StateProvider<int?>((ref) => null);

final homeworkStreamProvider = StreamProvider<List<StudentHomeworkItem>>((ref) {
  final repository = ref.watch(homeworkRepositoryProvider);
  final selectedDate = ref.watch(homeworkDateProvider);
  final dateStr = selectedDate.toIso8601String().split('T')[0];
  final grade = ref.watch(homeworkGradeFilterProvider);
  
  return repository.watchHomeworkForDate(dateStr, gradeFilter: grade);
});
