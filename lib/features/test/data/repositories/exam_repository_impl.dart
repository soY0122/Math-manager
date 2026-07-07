import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/exam_models.dart';
import '../../domain/repositories/exam_repository.dart';

class ExamRepositoryImpl implements ExamRepository {
  ExamRepositoryImpl();



  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  @override
  Stream<List<ExamOverview>> watchExams() {
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();

    return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<ExamOverview>>(
      examsStream,
      examRecordsStream,
      (examsSnap, recordsSnap) {
        final List<ExamOverview> list = [];

        final allExams = examsSnap.docs;
        final allRecords = recordsSnap.docs.map((doc) => doc.data()).toList();

        for (final doc in allExams) {
          final e = doc.data();
          final id = doc.id;
          final title = e['title'] as String? ?? '';
          final dateTs = e['date'] as Timestamp?;
          final date = dateTs != null ? DateFormat('yyyy-MM-dd').format(dateTs.toDate()) : '';
          final grade = e['grade'] as int? ?? 1;

          final examRecords = allRecords.where((r) => r['examId'] == id).toList();

          final double averageScore = examRecords.isNotEmpty
              ? examRecords.map((r) => r['score'] as int).reduce((a, b) => a + b) / examRecords.length
              : 0.0;

          int maxScore = 0;
          int minScore = 0;
          if (examRecords.isNotEmpty) {
            final scores = examRecords.map((r) => r['score'] as int).toList();
            maxScore = scores.reduce((a, b) => a > b ? a : b);
            minScore = scores.reduce((a, b) => a < b ? a : b);
          }

          list.add(ExamOverview(
            id: id,
            title: title,
            date: date,
            grade: grade,
            averageScore: averageScore,
            maxScore: maxScore,
            minScore: minScore,
            studentCount: examRecords.length,
          ));
        }

        return list;
      },
    );
  }

  @override
  Stream<List<StudentExamScoreItem>> watchExamScores(String examId) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();

    return Rx.combineLatest3<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<StudentExamScoreItem>>(
      studentsStream,
      examRecordsStream,
      examsStream,
      (studentsSnap, recordsSnap, examsSnap) {
        final List<StudentExamScoreItem> list = [];

        final examDoc = examsSnap.docs.where((doc) => doc.id == examId).firstOrNull;
        if (examDoc == null) return [];
        final examGrade = examDoc.data()['grade'] as int? ?? 1;

        final allStudents = studentsSnap.docs;
        final allRecords = recordsSnap.docs;

        var activeStudents = allStudents
            .where((doc) => doc.data()['isActive'] == true && doc.data()['grade'] == examGrade)
            .toList();
        activeStudents.sort((a, b) => (a.data()['name'] as String).compareTo(b.data()['name'] as String));

        for (final doc in activeStudents) {
          final s = doc.data();
          final studentId = doc.id;
          final studentName = s['name'] as String? ?? '';
          final school = s['school'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';

          final recs = allRecords.where((rDoc) {
            final r = rDoc.data();
            return r['examId'] == examId && r['studentId'] == studentId;
          }).toList();

          if (recs.isEmpty) {
            list.add(StudentExamScoreItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              recordId: null,
              score: 0,
            ));
          } else {
            final recDoc = recs.first;
            final rec = recDoc.data();
            list.add(StudentExamScoreItem(
              studentId: studentId,
              studentName: studentName,
              school: school,
              grade: grade,
              className: className,
              recordId: recDoc.id,
              score: rec['score'] as int? ?? 0,
            ));
          }
        }

        return list;
      },
    );
  }

  @override
  Future<String> addExam(String title, String date, int grade) async {
    final targetTimestamp = _parseDate(date);
    final docRef = await FirebaseFirestore.instance.collection('exams').add({
      'title': title,
      'date': targetTimestamp,
      'grade': grade,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateExamScore({
    required String examId,
    required String studentId,
    required int score,
    String? recordId,
  }) async {
    if (recordId != null) {
      await FirebaseFirestore.instance.collection('exam_records').doc(recordId).update({
        'score': score,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final query = await FirebaseFirestore.instance
          .collection('exam_records')
          .where('examId', isEqualTo: examId)
          .where('studentId', isEqualTo: studentId)
          .get();

      if (query.docs.isNotEmpty) {
        for (final doc in query.docs) {
          await doc.reference.update({
            'score': score,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('exam_records').add({
          'examId': examId,
          'studentId': studentId,
          'score': score,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> updateExam(String id, String title, String date) async {
    final targetTimestamp = _parseDate(date);
    await FirebaseFirestore.instance.collection('exams').doc(id).update({
      'title': title,
      'date': targetTimestamp,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteExam(String examId) async {
    await FirebaseFirestore.instance.collection('exams').doc(examId).delete();

    final query = await FirebaseFirestore.instance
        .collection('exam_records')
        .where('examId', isEqualTo: examId)
        .get();

    for (final doc in query.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Future<ExamBackup> deleteExamWithBackup(String examId) async {
    final doc = await FirebaseFirestore.instance.collection('exams').doc(examId).get();
    if (!doc.exists) {
      throw Exception('시험을 찾을 수 없습니다.');
    }
    final map = doc.data()!;
    map['docId'] = doc.id;

    final recordsQuery = await FirebaseFirestore.instance
        .collection('exam_records')
        .where('examId', isEqualTo: examId)
        .get();

    final List<Map<String, dynamic>> recordsList = [];
    for (final rDoc in recordsQuery.docs) {
      final rMap = rDoc.data();
      rMap['docId'] = rDoc.id;
      recordsList.add(rMap);
    }

    await deleteExam(examId);

    return ExamBackup(
      exam: map,
      examRecords: recordsList,
    );
  }

  @override
  Future<void> restoreExamBackup(ExamBackup backup) async {
    final examId = backup.exam['docId'] as String;
    final dateTs = backup.exam['date'] as Timestamp?;
    
    await FirebaseFirestore.instance.collection('exams').doc(examId).set({
      'title': backup.exam['title'],
      'date': dateTs,
      'grade': backup.exam['grade'],
      'createdAt': backup.exam['createdAt'] ?? FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    for (final record in backup.examRecords) {
      final recordId = record['docId'] as String;
      await FirebaseFirestore.instance.collection('exam_records').doc(recordId).set({
        'examId': examId,
        'studentId': record['studentId'],
        'score': record['score'],
        'createdAt': record['createdAt'] ?? FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}
