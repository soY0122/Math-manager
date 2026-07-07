import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/exam_models.dart';
import '../../domain/repositories/exam_repository.dart';
import '../../../../core/database/database.dart';

class ExamRepositoryImpl implements ExamRepository {
  final AppDatabase db;

  ExamRepositoryImpl(this.db);

  Stream<void> _watchMulti(List<Box> boxes) async* {
    yield null; // Initial trigger
    final controller = StreamController<void>();
    final subs = <StreamSubscription>[];
    for (final box in boxes) {
      subs.add(box.watch().listen((_) {
        if (!controller.isClosed) controller.add(null);
      }));
    }
    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
      controller.close();
    };
    yield* controller.stream;
  }

  @override
  Stream<List<ExamOverview>> watchExams() {
    return _watchMulti([db.examsBox, db.examRecordsBox, db.studentsBox]).asyncMap((_) async {
      final List<ExamOverview> list = [];

      final allExams = db.examsBox.values.toList();
      final allRecords = db.examRecordsBox.values.toList();
      final allStudents = db.studentsBox.values.toList();

      for (final e in allExams) {
        final examId = e['id'] as int;
        final title = e['title'] as String;
        final date = e['date'] as String;
        final grade = e['grade'] as int? ?? 3; // default to 초3 if missing

        // Find active students in this exam's grade
        final gradeStudentIds = allStudents
            .where((s) => s['is_active'] == true && s['grade'] == grade)
            .map((s) => s['id'] as int)
            .toSet();

        // Query scores for this exam belonging to students in that grade
        final examRecords = allRecords
            .where((r) => r['exam_id'] == examId && gradeStudentIds.contains(r['student_id']))
            .toList();
        final scores = examRecords.map((r) => r['score'] as int).toList();

        final double avgScore = scores.isNotEmpty
            ? scores.reduce((a, b) => a + b) / scores.length
            : 0.0;
        final int maxScore = scores.isNotEmpty ? scores.reduce((a, b) => a > b ? a : b) : 0;
        final int minScore = scores.isNotEmpty ? scores.reduce((a, b) => a < b ? a : b) : 0;
        final int count = scores.length;

        list.add(ExamOverview(
          id: examId,
          title: title,
          date: date,
          grade: grade,
          averageScore: avgScore,
          maxScore: maxScore,
          minScore: minScore,
          studentCount: count,
        ));
      }

      // Sort exams chronologically descending
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    });
  }

  @override
  Stream<List<StudentExamScoreItem>> watchExamScores(int examId) {
    return _watchMulti([db.studentsBox, db.examRecordsBox, db.examsBox]).asyncMap((_) async {
      final List<StudentExamScoreItem> list = [];

      final allStudents = db.studentsBox.values.toList();
      final exam = db.examsBox.get(examId);
      final int examGrade = exam != null ? (exam['grade'] as int? ?? 3) : 3;

      // Filter active students to ONLY those in the exam's grade
      final activeStudents = allStudents
          .where((s) => s['is_active'] == true && s['grade'] == examGrade)
          .toList();
      activeStudents.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

      for (final s in activeStudents) {
        final studentId = s['id'] as int;
        final studentName = s['name'] as String;
        final school = s['school'] as String;
        final grade = s['grade'] as int;
        final className = s['class_name'] as String;

        // Lookup score
        final recordKey = '${examId}_$studentId';
        final record = db.examRecordsBox.get(recordKey);

        final int score = record != null ? (record['score'] as int) : 0;
        final int recordId = record != null ? 1 : 0; // Simulated indicator

        list.add(StudentExamScoreItem(
          studentId: studentId,
          studentName: studentName,
          school: school,
          grade: grade,
          className: className,
          recordId: recordId,
          score: score,
        ));
      }

      return list;
    });
  }

  @override
  Future<int> addExam(String title, String date, int grade) async {
    // Generate new ID
    final keys = db.examsBox.keys.toList();
    final newId = keys.isNotEmpty ? (keys.cast<int>().reduce((a, b) => a > b ? a : b) + 1) : 1;

    await db.examsBox.put(newId, {
      'id': newId,
      'title': title,
      'date': date,
      'grade': grade,
    });

    // Generate schedule ID
    final sKeys = db.schedulesBox.keys.toList();
    final newSId = sKeys.isNotEmpty ? (sKeys.cast<int>().reduce((a, b) => a > b ? a : b) + 1) : 1;

    String gradeLabel = '';
    if (grade >= 1 && grade <= 6) {
      gradeLabel = '초$grade';
    } else if (grade >= 7 && grade <= 9) {
      gradeLabel = '중${grade - 6}';
    }

    await db.schedulesBox.put(newSId, {
      'id': newSId,
      'title': '$title ($gradeLabel)',
      'date': date,
      'type': 'EXAM',
      'memo': '$gradeLabel 정기 시험 일정',
    });

    return newId;
  }

  @override
  Future<void> updateExamScore({
    required int examId,
    required int studentId,
    required int score,
    int? recordId,
  }) async {
    final recordKey = '${examId}_$studentId';
    await db.examRecordsBox.put(recordKey, {
      'exam_id': examId,
      'student_id': studentId,
      'score': score,
    });
  }

  @override
  Future<void> updateExam(int id, String title, String date) async {
    final examVal = db.examsBox.get(id);
    if (examVal != null) {
      final Map exam = Map.from(examVal);
      exam['title'] = title;
      exam['date'] = date;
      await db.examsBox.put(id, exam);
    }
  }

  @override
  Future<void> deleteExam(int examId) async {
    await db.examsBox.delete(examId);

    // Relational safety deletes:
    // 1. Delete exam records
    final erKeys = db.examRecordsBox.keys.toList();
    for (final key in erKeys) {
      if (key.toString().startsWith('${examId}_')) {
        await db.examRecordsBox.delete(key);
      }
    }
  }

  @override
  Future<ExamBackup> deleteExamWithBackup(int examId) async {
    final examMap = db.examsBox.get(examId);
    if (examMap == null) {
      throw Exception('시험을 찾을 수 없습니다.');
    }

    final examRecords = db.examRecordsBox.values
        .where((r) => r['exam_id'] == examId)
        .map((r) => Map<dynamic, dynamic>.from(r))
        .toList();

    final backup = ExamBackup(
      exam: Map<dynamic, dynamic>.from(examMap),
      examRecords: examRecords,
    );

    await deleteExam(examId);
    return backup;
  }

  @override
  Future<void> restoreExamBackup(ExamBackup backup) async {
    final id = backup.exam['id'] as int;
    await db.examsBox.put(id, backup.exam);

    for (final r in backup.examRecords) {
      await db.examRecordsBox.put('${id}_${r['student_id']}', r);
    }
  }
}
