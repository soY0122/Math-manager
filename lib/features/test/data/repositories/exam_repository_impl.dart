import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/exam_models.dart';
import '../../domain/models/exam_group_models.dart';
import '../../domain/repositories/exam_repository.dart';

class ExamRepositoryImpl implements ExamRepository {
  ExamRepositoryImpl();

  @override
  Stream<List<ExamGroup>> watchExamGroups() {
    return FirebaseFirestore.instance
        .collection('exam_groups')
        .orderBy('orderIndex')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => ExamGroup.fromMap(doc.id, doc.data()))
            .toList());
  }

  @override
  Future<String> addExamGroup(String name, String colorHex) async {
    final query = await FirebaseFirestore.instance.collection('exam_groups').get();
    int maxIndex = -1;
    for (final doc in query.docs) {
      final index = doc.data()['orderIndex'] as int? ?? -1;
      if (index > maxIndex) {
        maxIndex = index;
      }
    }
    final docRef = await FirebaseFirestore.instance.collection('exam_groups').add({
      'name': name,
      'colorHex': colorHex,
      'orderIndex': maxIndex + 1,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateExamGroup(String id, String name, String colorHex) async {
    await FirebaseFirestore.instance.collection('exam_groups').doc(id).update({
      'name': name,
      'colorHex': colorHex,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reorderExamGroups(List<ExamGroup> orderedGroups) async {
    final batch = FirebaseFirestore.instance.batch();
    for (int i = 0; i < orderedGroups.length; i++) {
      final group = orderedGroups[i];
      final docRef = FirebaseFirestore.instance.collection('exam_groups').doc(group.id);
      batch.update(docRef, {'orderIndex': i});
    }
    await batch.commit();
  }

  @override
  Future<void> deleteExamGroup(
    String id, {
    required bool deleteExams,
    String? moveGroupId,
  }) async {
    final examsQuery = await FirebaseFirestore.instance
        .collection('exams')
        .where('examGroupId', isEqualTo: id)
        .get();

    if (examsQuery.docs.isNotEmpty) {
      if (deleteExams) {
        for (final doc in examsQuery.docs) {
          await deleteExam(doc.id);
        }
      } else if (moveGroupId != null) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in examsQuery.docs) {
          batch.update(doc.reference, {'examGroupId': moveGroupId});
        }
        await batch.commit();
      } else {
        throw Exception('그룹에 시험이 존재하여 삭제할 수 없습니다.');
      }
    }

    await FirebaseFirestore.instance.collection('exam_groups').doc(id).delete();
  }



  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  @override
  Stream<List<ExamOverview>> watchExams() {
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();
    final examGroupsStream = FirebaseFirestore.instance.collection('exam_groups').snapshots();

    return Rx.combineLatest3<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<ExamOverview>>(
      examsStream,
      examRecordsStream,
      examGroupsStream,
      (examsSnap, recordsSnap, groupsSnap) {
        final List<ExamOverview> list = [];

        final allExams = examsSnap.docs;
        final allRecords = recordsSnap.docs.map((doc) => doc.data()).toList();
        final allGroups = groupsSnap.docs
            .map((doc) => ExamGroup.fromMap(doc.id, doc.data()))
            .toList();

        for (final doc in allExams) {
          final e = doc.data();
          final id = doc.id;
          final title = e['title'] as String? ?? '';
          final dateTs = e['date'] as Timestamp?;
          final date = dateTs != null ? DateFormat('yyyy-MM-dd').format(dateTs.toDate()) : '';
          final grade = e['grade'] as int? ?? 1;
          final examGroupId = e['examGroupId'] as String? ?? '';

          final group = allGroups.firstWhere(
            (g) => g.id == examGroupId,
            orElse: () => const ExamGroup(id: '', name: '미지정', colorHex: '#9E9E9E', orderIndex: 9999),
          );
          final examGroupName = group.name;
          final examGroupColorHex = group.colorHex;
          final maxPossibleScore = e['maxPossibleScore'] as int? ?? 100;

          final stats = ExamParticipantCalculator.calculateStats(
            examId: id,
            rawRecords: allRecords,
            maxPossibleScore: maxPossibleScore,
          );

          list.add(ExamOverview(
            id: id,
            title: title,
            date: date,
            grade: grade,
            averageScore: stats['average'] as double,
            maxScore: stats['max'] as int,
            minScore: stats['min'] as int,
            studentCount: stats['count'] as int,
            examGroupId: examGroupId,
            examGroupName: examGroupName,
            examGroupColorHex: examGroupColorHex,
            maxPossibleScore: maxPossibleScore,
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
  Future<String> addExam(String title, String date, int grade, String examGroupId, {int maxPossibleScore = 100}) async {
    final targetTimestamp = _parseDate(date);
    final docRef = await FirebaseFirestore.instance.collection('exams').add({
      'title': title,
      'date': targetTimestamp,
      'grade': grade,
      'examGroupId': examGroupId,
      'maxPossibleScore': maxPossibleScore,
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
  Future<void> updateExam(String id, String title, String date, String examGroupId, {int maxPossibleScore = 100}) async {
    final targetTimestamp = _parseDate(date);
    await FirebaseFirestore.instance.collection('exams').doc(id).update({
      'title': title,
      'date': targetTimestamp,
      'examGroupId': examGroupId,
      'maxPossibleScore': maxPossibleScore,
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
      'examGroupId': backup.exam['examGroupId'] ?? '',
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
