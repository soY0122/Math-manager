import '../models/student_homework_item.dart';

abstract class HomeworkRepository {
  Stream<List<StudentHomeworkItem>> watchHomeworkForDate(String date, {int? gradeFilter});
  Future<void> updateHomeworkStatus({
    required String studentId,
    required String date,
    required String status,
    required String title,
    String? memo,
    String? homeworkId,
  });
  Future<void> markAllAsCompleted(String date, String title, {int? gradeFilter});
  Future<void> addHomeworkAssignment({
    required String date,
    required String title,
    required int? gradeFilter,
  });
  Future<void> deleteHomeworkAssignment({
    required String date,
    required String title,
    required int? gradeFilter,
  });
}
