import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/exam_repository_impl.dart';
import '../../domain/repositories/exam_repository.dart';
import '../../domain/models/exam_models.dart';
import '../../domain/models/exam_group_models.dart';
import '../../../../core/providers/global_providers.dart';

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepositoryImpl();
});

final examSortNewestProvider = StateProvider<bool>((ref) => true);
final testExamGroupFilterProvider = StateProvider<String?>((ref) => null);

final examGroupsStreamProvider = StreamProvider<List<ExamGroup>>((ref) {
  final repository = ref.watch(examRepositoryProvider);
  return repository.watchExamGroups();
});

final examsListStreamProvider = StreamProvider<List<ExamOverview>>((ref) {
  final repository = ref.watch(examRepositoryProvider);
  final stream = repository.watchExams();
  final gradeFilter = ref.watch(globalGradeFilterProvider);
  final sortNewest = ref.watch(examSortNewestProvider);
  final groupFilter = ref.watch(testExamGroupFilterProvider);

  return stream.map((exams) {
    List<ExamOverview> list = List.from(exams);
    if (gradeFilter != null) {
      list = list.where((e) => e.grade == gradeFilter).toList();
    }
    if (groupFilter != null && groupFilter.isNotEmpty) {
      list = list.where((e) => e.examGroupId == groupFilter).toList();
    }
    if (sortNewest) {
      list.sort((a, b) => b.date.compareTo(a.date));
    } else {
      list.sort((a, b) => a.date.compareTo(b.date));
    }
    return list;
  });
});

final examScoresStreamProvider = StreamProvider.family<List<StudentExamScoreItem>, String>((ref, examId) {
  final repository = ref.watch(examRepositoryProvider);
  return repository.watchExamScores(examId);
});
