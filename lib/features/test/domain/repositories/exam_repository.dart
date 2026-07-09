import '../models/exam_models.dart';
import '../models/exam_group_models.dart';

abstract class ExamRepository {
  Stream<List<ExamGroup>> watchExamGroups();
  Future<String> addExamGroup(String name, String colorHex);
  Future<void> updateExamGroup(String id, String name, String colorHex);
  Future<void> reorderExamGroups(List<ExamGroup> orderedGroups);
  Future<void> deleteExamGroup(
    String id, {
    required bool deleteExams,
    String? moveGroupId,
  });

  Stream<List<ExamOverview>> watchExams();
  Stream<List<StudentExamScoreItem>> watchExamScores(String examId);
  Future<String> addExam(String title, String date, int grade, String examGroupId);
  Future<void> updateExamScore({
    required String examId,
    required String studentId,
    required int score,
    String? recordId,
  });
  Future<void> updateExam(String id, String title, String date, String examGroupId);
  Future<void> deleteExam(String examId);
  Future<ExamBackup> deleteExamWithBackup(String examId);
  Future<void> restoreExamBackup(ExamBackup backup);
}

class ExamBackup {
  final Map<dynamic, dynamic> exam;
  final List<Map<dynamic, dynamic>> examRecords;

  const ExamBackup({
    required this.exam,
    required this.examRecords,
  });
}
