import '../models/student_stats.dart';
import '../models/student_detail_data.dart';

abstract class StudentRepository {
  Stream<List<StudentStats>> watchStudents({String? search, int? gradeFilter});
  Stream<StudentDetailData> watchStudentDetail(int studentId);
  
  Future<int> addStudent({
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  });

  Future<void> updateStudent({
    required int id,
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  });

  Future<void> deleteStudent(int id);
  Future<void> updateStudentMemo(int id, String memo);
  Future<StudentBackup> deleteStudentWithBackup(int id);
  Future<void> restoreStudentBackup(StudentBackup backup);
}

class StudentBackup {
  final Map<dynamic, dynamic> student;
  final List<Map<dynamic, dynamic>> attendances;
  final List<Map<dynamic, dynamic>> homeworks;
  final List<Map<dynamic, dynamic>> examRecords;

  const StudentBackup({
    required this.student,
    required this.attendances,
    required this.homeworks,
    required this.examRecords,
  });
}
