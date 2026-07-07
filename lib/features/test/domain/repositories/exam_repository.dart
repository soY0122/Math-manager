import '../models/exam_models.dart';

abstract class ExamRepository {
  Stream<List<ExamOverview>> watchExams();
  Stream<List<StudentExamScoreItem>> watchExamScores(String examId);
  Future<String> addExam(String title, String date, int grade);
  Future<void> updateExamScore({
    required String examId,
    required String studentId,
    required int score,
    String? recordId,
  });
  Future<void> updateExam(String id, String title, String date);
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
