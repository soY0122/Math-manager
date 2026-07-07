import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/student_attendance_item.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl();

  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  @override
  Stream<List<StudentAttendanceItem>> watchAttendanceForDate(String date, {int? gradeFilter}) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final attendancesStream = FirebaseFirestore.instance.collection('attendances').snapshots();

    return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<StudentAttendanceItem>>(
      studentsStream,
      attendancesStream,
      (studentsSnap, attendancesSnap) {
        final List<StudentAttendanceItem> list = [];

        final allStudents = studentsSnap.docs;
        final allAttendances = attendancesSnap.docs;

        var activeStudents = allStudents.where((doc) => doc.data()['isActive'] == true).toList();
        if (gradeFilter != null) {
          activeStudents = activeStudents.where((doc) => doc.data()['grade'] == gradeFilter).toList();
        }
        activeStudents.sort((a, b) => (a.data()['name'] as String).compareTo(b.data()['name'] as String));

        final targetTimestamp = _parseDate(date);

        for (final doc in activeStudents) {
          final s = doc.data();
          final studentId = doc.id; // String ID
          final studentName = s['name'] as String? ?? '';
          final school = s['school'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';

          final attRecords = allAttendances.where((aDoc) {
            final a = aDoc.data();
            final aStudentId = a['studentId'] as String;
            final aDateTs = a['date'] as Timestamp?;
            return aStudentId == studentId && aDateTs != null && aDateTs.seconds == targetTimestamp.seconds;
          }).toList();

          if (attRecords.isEmpty) {
            list.add(StudentAttendanceItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              attendanceId: null,
              date: date,
              status: 'ABSENT',
            ));
          } else {
            final attDoc = attRecords.first;
            final att = attDoc.data();
            list.add(StudentAttendanceItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              attendanceId: attDoc.id,
              date: date,
              status: att['status'] as String? ?? 'ABSENT',
            ));
          }
        }

        return list;
      },
    );
  }

  @override
  Future<void> updateAttendanceStatus({
    required String studentId,
    required String date,
    required String status,
    String? attendanceId,
  }) async {
    final targetTimestamp = _parseDate(date);
    if (attendanceId != null) {
      await FirebaseFirestore.instance.collection('attendances').doc(attendanceId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final query = await FirebaseFirestore.instance
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: targetTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        for (final doc in query.docs) {
          await doc.reference.update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('attendances').add({
          'studentId': studentId,
          'date': targetTimestamp,
          'status': status,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> markAllAsPresent(String date, {int? gradeFilter}) async {
    final targetTimestamp = _parseDate(date);
    final studentsSnap = await FirebaseFirestore.instance.collection('students').get();
    var targets = studentsSnap.docs.where((doc) => doc.data()['isActive'] == true).toList();
    if (gradeFilter != null) {
      targets = targets.where((doc) => doc.data()['grade'] == gradeFilter).toList();
    }

    for (final doc in targets) {
      final studentId = doc.id;
      final query = await FirebaseFirestore.instance
          .collection('attendances')
          .where('studentId', isEqualTo: studentId)
          .where('date', isEqualTo: targetTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        for (final attDoc in query.docs) {
          await attDoc.reference.update({
            'status': 'ATTENDANCE',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('attendances').add({
          'studentId': studentId,
          'date': targetTimestamp,
          'status': 'ATTENDANCE',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }
}
