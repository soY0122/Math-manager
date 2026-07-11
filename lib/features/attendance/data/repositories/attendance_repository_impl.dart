import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/student_attendance_item.dart';
import '../../domain/repositories/attendance_repository.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  AttendanceRepositoryImpl();

  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  // Background legacy migration helper
  void _migrateLegacyDoc(DocumentSnapshot doc, String expectedId) {
    final docRef = FirebaseFirestore.instance.collection('attendances').doc(doc.id);
    final newDocRef = FirebaseFirestore.instance.collection('attendances').doc(expectedId);
    
    FirebaseFirestore.instance.runTransaction((transaction) async {
      final newDocSnap = await transaction.get(newDocRef);
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      if (!newDocSnap.exists) {
        transaction.set(newDocRef, {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final legacyUp = data['updatedAt'] as Timestamp?;
        final newUp = newDocSnap.data()?['updatedAt'] as Timestamp?;
        bool useLegacy = true;
        if (legacyUp != null && newUp != null) {
          useLegacy = legacyUp.compareTo(newUp) > 0;
        }
        if (useLegacy) {
          transaction.update(newDocRef, {
            ...data,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      transaction.delete(docRef);
    }).catchError((_) {});
  }

  @override
  Stream<List<StudentAttendanceItem>> watchAttendanceForDate(String date, {int? gradeFilter}) {
    final targetTimestamp = _parseDate(date);
    final startOfDay = DateTime(targetTimestamp.toDate().year, targetTimestamp.toDate().month, targetTimestamp.toDate().day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final studentsStream = FirebaseFirestore.instance
        .collection('students')
        .where('isActive', isEqualTo: true)
        .snapshots();

    final attendancesStream = FirebaseFirestore.instance
        .collection('attendances')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .snapshots();

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

        final targetTimestamp = _parseDate(date);
        final startOfDay = DateTime(targetTimestamp.toDate().year, targetTimestamp.toDate().month, targetTimestamp.toDate().day);
        final yyyyMMdd = DateFormat('yyyyMMdd').format(startOfDay);

        // Run background migration for legacy documents
        for (final doc in allAttendances) {
          final studentId = doc.data()['studentId'] as String?;
          final dateTs = doc.data()['date'] as Timestamp?;
          if (studentId == null || dateTs == null) continue;
          final dStr = DateFormat('yyyy-MM-dd').format(dateTs.toDate());
          final expectedId = '${studentId}_${dStr.replaceAll('-', '')}';
          if (doc.id != expectedId) {
            _migrateLegacyDoc(doc, expectedId);
          }
        }

        var activeStudents = allStudents;
        if (gradeFilter != null) {
          activeStudents = activeStudents.where((doc) => doc.data()['grade'] == gradeFilter).toList();
        }
        activeStudents.sort((a, b) => (a.data()['name'] as String).compareTo(b.data()['name'] as String));

        for (final doc in activeStudents) {
          final s = doc.data();
          final studentId = doc.id;
          final studentName = s['name'] as String? ?? '';
          final school = s['school'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';
          
          final expectedId = '${studentId}_$yyyyMMdd';

          QueryDocumentSnapshot<Map<String, dynamic>>? attDoc;
          final deterministicMatches = allAttendances.where((aDoc) => aDoc.id == expectedId).toList();
          if (deterministicMatches.isNotEmpty) {
            attDoc = deterministicMatches.first;
          } else {
            final legacyMatches = allAttendances.where((aDoc) {
              final a = aDoc.data();
              final aStudentId = a['studentId'] as String?;
              final aDateTs = a['date'] as Timestamp?;
              if (aDateTs == null) return false;
              final aDateStr = DateFormat('yyyy-MM-dd').format(aDateTs.toDate());
              return aStudentId == studentId && aDateStr == date;
            }).toList();
            if (legacyMatches.isNotEmpty) {
              attDoc = legacyMatches.first;
            }
          }

          if (attDoc == null) {
            list.add(StudentAttendanceItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              attendanceId: expectedId,
              date: date,
              status: 'ATTENDANCE',
            ));
          } else {
            final att = attDoc.data();
            list.add(StudentAttendanceItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              attendanceId: attDoc.id,
              date: date,
              status: att['status'] as String? ?? 'ATTENDANCE',
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
    final startOfDay = DateTime(targetTimestamp.toDate().year, targetTimestamp.toDate().month, targetTimestamp.toDate().day);
    final yyyyMMdd = DateFormat('yyyyMMdd').format(startOfDay);
    final deterministicId = '${studentId}_$yyyyMMdd';

    final docRef = FirebaseFirestore.instance.collection('attendances').doc(deterministicId);
    await docRef.set({
      'studentId': studentId,
      'date': Timestamp.fromDate(startOfDay),
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Safeguard: If we passed an old legacy doc ID, delete it
    if (attendanceId != null && attendanceId != deterministicId) {
      try {
        await FirebaseFirestore.instance.collection('attendances').doc(attendanceId).delete();
      } catch (_) {}
    }
  }

  Future<void> _markAllAsStatus(String date, String status, {int? gradeFilter}) async {
    final targetTimestamp = _parseDate(date);
    
    // 1. Get active students
    final studentsSnap = await FirebaseFirestore.instance.collection('students').get();
    var targets = studentsSnap.docs.where((doc) => doc.data()['isActive'] == true).toList();
    if (gradeFilter != null) {
      targets = targets.where((doc) => doc.data()['grade'] == gradeFilter).toList();
    }

    final startOfDay = DateTime(targetTimestamp.toDate().year, targetTimestamp.toDate().month, targetTimestamp.toDate().day);
    final yyyyMMdd = DateFormat('yyyyMMdd').format(startOfDay);

    // 2. Prepare the WriteBatch
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in targets) {
      final studentId = doc.id;
      final deterministicId = '${studentId}_$yyyyMMdd';
      final docRef = FirebaseFirestore.instance.collection('attendances').doc(deterministicId);

      batch.set(docRef, {
        'studentId': studentId,
        'date': Timestamp.fromDate(startOfDay),
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  @override
  Future<void> markAllAsPresent(String date, {int? gradeFilter}) async {
    await _markAllAsStatus(date, 'ATTENDANCE', gradeFilter: gradeFilter);
  }

  @override
  Future<void> markAllAsLeave(String date, {int? gradeFilter}) async {
    await _markAllAsStatus(date, 'LEAVE', gradeFilter: gradeFilter);
  }
}
