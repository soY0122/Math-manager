import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/settings_models.dart';
import '../../domain/repositories/settings_repository.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl();



  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  @override
  Stream<List<ScheduleItem>> watchSchedulesForDate(String dateStr) {
    final targetTimestamp = _parseDate(dateStr);
    return FirebaseFirestore.instance
        .collection('schedules')
        .where('date', isEqualTo: targetTimestamp)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              return ScheduleItem(
                id: doc.id,
                title: data['title'] as String? ?? '',
                date: dateStr,
                type: data['type'] as String? ?? 'EXAM',
                memo: data['memo'] as String?,
              );
            }).toList());
  }

  @override
  Stream<List<ScheduleItem>> watchAllSchedules() {
    return FirebaseFirestore.instance.collection('schedules').snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              final dateTs = data['date'] as Timestamp?;
              final dateStr = dateTs != null ? DateFormat('yyyy-MM-dd').format(dateTs.toDate()) : '';
              return ScheduleItem(
                id: doc.id,
                title: data['title'] as String? ?? '',
                date: dateStr,
                type: data['type'] as String? ?? 'EXAM',
                memo: data['memo'] as String?,
              );
            }).toList());
  }

  @override
  Future<void> addSchedule({
    required String title,
    required String date,
    required String type,
    String? memo,
    String? studentId,
  }) async {
    final targetTimestamp = _parseDate(date);
    await FirebaseFirestore.instance.collection('schedules').add({
      'title': title,
      'date': targetTimestamp,
      'type': type,
      'memo': memo ?? '',
      'studentId': studentId,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateSchedule({
    required String id,
    required String title,
    required String date,
    String? memo,
  }) async {
    final targetTimestamp = _parseDate(date);
    await FirebaseFirestore.instance.collection('schedules').doc(id).update({
      'title': title,
      'date': targetTimestamp,
      'memo': memo ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteSchedule(String id) async {
    await FirebaseFirestore.instance.collection('schedules').doc(id).delete();
  }

  @override
  Stream<AcademyStats> watchAcademyStats({int? gradeFilter}) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();
    final attendancesStream = FirebaseFirestore.instance.collection('attendances').snapshots();
    final homeworksStream = FirebaseFirestore.instance.collection('homeworks').snapshots();

    return Rx.combineLatest4<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        AcademyStats>(
      studentsStream,
      examRecordsStream,
      attendancesStream,
      homeworksStream,
      (studentsSnap, examRecordsSnap, attendancesSnap, homeworksSnap) {
        final allStudentsDocs = studentsSnap.docs;
        final allStudents = allStudentsDocs.map((doc) => doc.data()..['docId'] = doc.id).toList();
        final allRecords = examRecordsSnap.docs.map((doc) => doc.data()).toList();
        final allAttendances = attendancesSnap.docs.map((doc) => doc.data()).toList();
        final allHomeworks = homeworksSnap.docs.map((doc) => doc.data()).toList();

        final activeStudents = allStudents.where((s) => s['isActive'] == true).toList();

        final List<GradeStats> gradeStatsList = [];
        for (int grade = 1; grade <= 9; grade++) {
          final gradeStudents = activeStudents.where((s) => s['grade'] == grade).toList();
          if (gradeStudents.isEmpty) {
            gradeStatsList.add(GradeStats(
              grade: grade,
              averageScore: 0.0,
              attendanceRate: 1.0,
              homeworkRate: 1.0,
            ));
            continue;
          }

          final gradeStudentIds = gradeStudents.map((s) => s['docId'] as String).toSet();

          final gradeRecords = allRecords.where((r) => gradeStudentIds.contains(r['studentId'])).toList();
          final double avgScore = gradeRecords.isNotEmpty
              ? gradeRecords.map((r) => r['score'] as int).reduce((a, b) => a + b) / gradeRecords.length
              : 0.0;

          final gradeAtts = allAttendances.where((a) => gradeStudentIds.contains(a['studentId'])).toList();
          int present = 0;
          int late = 0;
          for (final a in gradeAtts) {
            if (a['status'] == 'ATTENDANCE') present++;
            if (a['status'] == 'LATE') late++;
          }
          final double attRate = gradeAtts.isNotEmpty ? (present + late) / gradeAtts.length : 1.0;

          final gradeHws = allHomeworks.where((h) => gradeStudentIds.contains(h['studentId'])).toList();
          int completed = 0;
          int partial = 0;
          for (final h in gradeHws) {
            if (h['status'] == 'COMPLETED') completed++;
            if (h['status'] == 'PARTIAL') partial++;
          }
          final double hwRate = gradeHws.isNotEmpty ? (completed + (partial * 0.5)) / gradeHws.length : 1.0;

          gradeStatsList.add(GradeStats(
            grade: grade,
            averageScore: avgScore,
            attendanceRate: attRate,
            homeworkRate: hwRate,
          ));
        }

        final List<RankingItem> scoreRankings = [];
        final List<RankingItem> growthRankings = [];

        var targetStudents = activeStudents;
        if (gradeFilter != null) {
          targetStudents = targetStudents.where((s) => s['grade'] == gradeFilter).toList();
        }

        for (final s in targetStudents) {
          final studentId = s['docId'] as String;
          final name = s['name'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';

          final studentScores = allRecords
              .where((r) => r['studentId'] == studentId)
              .toList();
          studentScores.sort((a, b) => (a['examId'] as String).compareTo(b['examId'] as String));
          final scoresList = studentScores.map((r) => r['score'] as int).toList();

          final double avgScore = scoresList.isNotEmpty
              ? scoresList.reduce((a, b) => a + b) / scoresList.length
              : 0.0;

          double growthRate = 0.0;
          if (scoresList.length >= 2) {
            final latest = scoresList[scoresList.length - 1];
            final previous = scoresList[scoresList.length - 2];
            if (previous > 0) {
              growthRate = ((latest - previous) / previous) * 100;
            }
          }

          scoreRankings.add(RankingItem(
            studentId: studentId,
            name: name,
            grade: grade,
            className: className,
            value: avgScore,
          ));

          growthRankings.add(RankingItem(
            studentId: studentId,
            name: name,
            grade: grade,
            className: className,
            value: growthRate,
          ));
        }

        scoreRankings.sort((a, b) => b.value.compareTo(a.value));
        growthRankings.sort((a, b) => b.value.compareTo(a.value));

        return AcademyStats(
          gradeStats: gradeStatsList,
          scoreRankings: scoreRankings,
          growthRankings: growthRankings,
        );
      },
    );
  }
}
