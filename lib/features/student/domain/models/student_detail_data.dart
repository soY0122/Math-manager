import 'student_stats.dart';
import '../../../../core/utils/student_evaluator.dart';
import '../../../test/domain/models/exam_models.dart';

class StudentDetailData {
  final StudentStats stats;
  final List<StudentAttendanceLog> attendanceLogs;
  final List<StudentHomeworkLog> homeworkLogs;
  final List<StudentExamLog> examLogs;
  final AIEvaluation aiEvaluation;
  final List<StudentConsultingLog> consultingLogs;
  final Map<String, StudentComparisonResult> groupComparisons;

  const StudentDetailData({
    required this.stats,
    required this.attendanceLogs,
    required this.homeworkLogs,
    required this.examLogs,
    required this.aiEvaluation,
    required this.consultingLogs,
    required this.groupComparisons,
  });
}

class StudentAttendanceLog {
  final String date; // YYYY-MM-DD
  final String status; // 'ATTENDANCE', 'LATE', 'ABSENT', 'LEAVE'

  const StudentAttendanceLog({
    required this.date,
    required this.status,
  });
}

class StudentHomeworkLog {
  final String title;
  final String date; // YYYY-MM-DD
  final String status; // 'COMPLETED', 'PARTIAL', 'INCOMPLETE'
  final String? memo;

  const StudentHomeworkLog({
    required this.title,
    required this.date,
    required this.status,
    this.memo,
  });
}

class StudentExamLog {
  final String title;
  final String date; // YYYY-MM-DD
  final int score;
  final String examGroupId;
  final String examGroupName;
  final String examGroupColorHex;
  final int maxPossibleScore;

  const StudentExamLog({
    required this.title,
    required this.date,
    required this.score,
    required this.examGroupId,
    required this.examGroupName,
    required this.examGroupColorHex,
    this.maxPossibleScore = 100,
  });
}

class StudentConsultingLog {
  final String? id;
  final String title;
  final String date; // YYYY-MM-DD
  final String? memo;

  const StudentConsultingLog({
    this.id,
    required this.title,
    required this.date,
    this.memo,
  });
}
