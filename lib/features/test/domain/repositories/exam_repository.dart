import '../models/exam_models.dart';

abstract class ExamRepository {
  Stream<List<ExamOverview>> watchExams();
  Stream<List<StudentExamScoreItem>> watchExamScores(int examId);
  Future<int> addExam(String title, String date, int grade);
  Future<void> updateExamScore({
    required int examId,
    required int studentId,
    required int score,
    int? recordId,
  });
  Future<void> updateExam(int id, String title, String date);
  Future<void> deleteExam(int examId);
  Future<ExamBackup> deleteExamWithBackup(int examId);
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
