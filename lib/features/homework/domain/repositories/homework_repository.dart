import '../models/student_homework_item.dart';

abstract class HomeworkRepository {
  Stream<List<StudentHomeworkItem>> watchHomeworkForDate(String date, {int? gradeFilter});
  Future<void> updateHomeworkStatus({
    required int studentId,
    required String date,
    required String status,
    required String title,
    String? memo,
    int? homeworkId,
  });
  Future<void> markAllAsCompleted(String date, String title, {int? gradeFilter});
}
