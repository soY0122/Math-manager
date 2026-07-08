import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../domain/repositories/home_repository.dart';
import '../../../../core/utils/student_evaluator.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl();



  @override
  Stream<DashboardStats> watchDashboardStats(int? gradeFilter) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final attendancesStream = FirebaseFirestore.instance.collection('attendances').snapshots();
    final homeworksStream = FirebaseFirestore.instance.collection('homeworks').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();

    return Rx.combineLatest5<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        DashboardStats>(
      studentsStream,
      attendancesStream,
      homeworksStream,
      examRecordsStream,
      examsStream,
      (studentsSnap, attendancesSnap, homeworksSnap, examRecordsSnap, examsSnap) {
        final today = DateTime.now();
        final targetTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
        final todayStr = DateFormat('yyyy-MM-dd').format(today);

        final allStudents = studentsSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();
        final allAttendances = attendancesSnap.docs.map((doc) => doc.data()).toList();
        final allHomeworks = homeworksSnap.docs.map((doc) => doc.data()).toList();
        final allRecords = examRecordsSnap.docs.map((doc) => doc.data()).toList();
        final allExams = examsSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();

        var activeStudents = allStudents.where((s) => s['isActive'] == true).toList();
        if (gradeFilter != null) {
          activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
        }
        final activeStudentIds = activeStudents.map((s) => s['docId'] as String).toSet();

        // 2. Today's attendance counts
        final todayAtts = allAttendances
            .where((a) {
              final aStudentId = a['studentId'] as String? ?? '';
              final aDateTs = a['date'] as Timestamp?;
              if (aDateTs == null) return false;
              final aDateStr = DateFormat('yyyy-MM-dd').format(aDateTs.toDate());
              return aDateStr == todayStr && activeStudentIds.contains(aStudentId);
            })
            .toList();

        int todayPresent = 0;
        int todayLate = 0;
        int todayAbsent = 0;

        for (final att in todayAtts) {
          final status = att['status'] as String;
          if (status == 'ATTENDANCE' || status == 'EARLY_LEAVE') todayPresent++;
          if (status == 'LATE') todayLate++;
          if (status == 'ABSENT') todayAbsent++;
        }

        // 3. Today's homework incomplete counts
        final todayHws = allHomeworks
            .where((h) {
              final hStudentId = h['studentId'] as String? ?? '';
              final hDateTs = h['date'] as Timestamp?;
              return hDateTs != null && hDateTs.seconds == targetTimestamp.seconds && activeStudentIds.contains(hStudentId);
            })
            .toList();

        int todayHwIncomplete = 0;
        for (final hw in todayHws) {
          final status = hw['status'] as String;
          if (status == 'INCOMPLETE') todayHwIncomplete++;
        }

        // 4. Monthly averages / rates
        final activeStudentRecords = allRecords
            .where((r) => activeStudentIds.contains(r['studentId'] as String? ?? ''))
            .toList();
        final double monthlyAvgScore = activeStudentRecords.isNotEmpty
            ? activeStudentRecords.map((r) => r['score'] as int).reduce((a, b) => a + b) / activeStudentRecords.length
            : 0.0;

        final activeStudentAtts = allAttendances
            .where((a) => activeStudentIds.contains(a['studentId'] as String? ?? ''))
            .toList();
        int totalAttPresent = 0;
        int totalAttLate = 0;
        for (final att in activeStudentAtts) {
          final status = att['status'] as String;
          if (status == 'ATTENDANCE') totalAttPresent++;
          if (status == 'LATE') totalAttLate++;
        }
        final double monthlyAttendanceRate = activeStudentAtts.isNotEmpty
            ? (totalAttPresent + totalAttLate) / activeStudentAtts.length
            : 1.0;

        final activeStudentHws = allHomeworks
            .where((h) => activeStudentIds.contains(h['studentId'] as String? ?? ''))
            .toList();
        int totalHwCompleted = 0;
        int totalHwPartial = 0;
        for (final hw in activeStudentHws) {
          final status = hw['status'] as String;
          if (status == 'COMPLETED') totalHwCompleted++;
          if (status == 'PARTIAL') totalHwPartial++;
        }
        final double monthlyHomeworkRate = activeStudentHws.isNotEmpty
            ? (totalHwCompleted + (totalHwPartial * 0.5)) / activeStudentHws.length
            : 1.0;

        // 5. Growth Leaderboard & Risk evaluation
        final List<GrowthLeaderboardItem> leaderboard = [];
        int dangerCount = 0;
        int risingCount = 0;

        for (final s in activeStudents) {
          final id = s['docId'] as String;
          final name = s['name'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';

          final studentScores = allRecords
              .where((r) => r['studentId'] == id)
              .toList();

          final growthRes = StudentGrowthCalculator.calculate(
            studentRecords: studentScores,
            allExams: allExams,
          );
          final double growthRate = growthRes['rate'] as double;
          final String growthTrend = growthRes['trend'] as String;
          if (growthTrend == '상승 중') {
            risingCount++;
          }

          leaderboard.add(GrowthLeaderboardItem(
            studentId: id,
            studentName: name,
            grade: grade,
            className: className,
            growthRate: growthRate,
            growthTrend: growthTrend,
          ));

          // Evaluate risk
          final regTimestamp = s['registrationDate'] as Timestamp?;
          final DateTime? regDate = regTimestamp?.toDate();

          final studentAttsLog = allAttendances.where((a) => a['studentId'] == id).toList();
          final List<Map<String, dynamic>> attLogsForRisk = [];
          for (final a in studentAttsLog) {
            final dateTs = a['date'] as Timestamp?;
            if (dateTs == null) continue;
            attLogsForRisk.add({
              'date': dateTs.toDate(),
              'status': a['status'] as String? ?? 'ATTENDANCE',
            });
          }

          final studentHwsLog = allHomeworks.where((h) => h['studentId'] == id).toList();
          final List<Map<String, dynamic>> hwLogsForRisk = [];
          for (final h in studentHwsLog) {
            final dateTs = h['date'] as Timestamp?;
            if (dateTs == null) continue;
            hwLogsForRisk.add({
              'date': dateTs.toDate(),
              'status': h['status'] as String? ?? 'INCOMPLETE',
            });
          }

          final List<Map<String, dynamic>> examLogsForRisk = [];
          for (final r in studentScores) {
            final examId = r['examId'] as String?;
            final score = r['score'] as int? ?? 0;
            final examDoc = allExams.firstWhere((e) => e['docId'] == examId, orElse: () => <String, dynamic>{});
            final examDateTs = examDoc['date'] as Timestamp?;
            if (examDateTs == null) continue;
            examLogsForRisk.add({
              'date': examDateTs.toDate(),
              'score': score,
            });
          }

          final riskRes = StudentRiskCalculator.calculate(
            evaluationDate: DateTime.now(),
            registrationDate: regDate,
            attendanceLogs: attLogsForRisk,
            homeworkLogs: hwLogsForRisk,
            examLogs: examLogsForRisk,
          );

          if (riskRes.score >= 4) {
            dangerCount++;
          }
        }

        leaderboard.sort((a, b) => b.growthRate.compareTo(a.growthRate));

        // 6. Recent activity (Latest logs)
        final List<RecentActivityItem> recent = [];

        // Add attendances today/yesterday
        for (final att in allAttendances) {
          final sId = att['studentId'] as String? ?? '';
          if (!activeStudentIds.contains(sId)) continue;
          final sDoc = allStudents.where((s) => s['docId'] == sId).firstOrNull;
          final studentName = sDoc != null ? sDoc['name'] as String : '학생';
          final dateTs = att['date'] as Timestamp?;
          final date = dateTs != null ? DateFormat('yyyy-MM-dd').format(dateTs.toDate()) : '';
          final status = att['status'] as String;
          String statusText = status == 'ATTENDANCE' ? '출석' : (status == 'LATE' ? '지각' : '결석');

          recent.add(RecentActivityItem(
            title: '$studentName 학생 $statusText 등록',
            description: '$date $statusText 처리되었습니다.',
            timestamp: date == todayStr ? '오늘' : date,
            type: 'ATTENDANCE',
          ));
        }

        // Add homework logs
        for (final hw in allHomeworks) {
          final sId = hw['studentId'] as String? ?? '';
          if (!activeStudentIds.contains(sId)) continue;
          final sDoc = allStudents.where((s) => s['docId'] == sId).firstOrNull;
          final studentName = sDoc != null ? sDoc['name'] as String : '학생';
          final dateTs = hw['date'] as Timestamp?;
          final date = dateTs != null ? DateFormat('yyyy-MM-dd').format(dateTs.toDate()) : '';
          final status = hw['status'] as String;
          String statusText = status == 'COMPLETED' ? '과제 완료' : (status == 'PARTIAL' ? '과제 일부완료' : '과제 미완료');

          recent.add(RecentActivityItem(
            title: '$studentName $statusText',
            description: '${hw['title']} - $statusText 처리되었습니다.',
            timestamp: date == todayStr ? '오늘' : date,
            type: 'HOMEWORK',
          ));
        }

        recent.sort((a, b) => b.description.compareTo(a.description));

        final String aiSummary = dangerCount > 0
            ? '최근 시험 성적 분석 결과 성적이 고속 상승 중인 학생이 ${risingCount}명 관찰되었으나, 최근 출결 및 학습 패턴에 변화가 감지되어 추가 모니터링 및 개별 보강 지도 지원이 권장되는 집중 관리 학생이 ${dangerCount}명 존재합니다.'
            : '전체 재원생들의 평균 성적이 안정적으로 상승하고 있으며, 이번 달 출석률 ${(monthlyAttendanceRate * 100).toStringAsFixed(0)}%로 양호합니다. 과제 완료 상태도 성실히 유지되고 있습니다.';

        return DashboardStats(
          todayPresentCount: todayPresent,
          todayLateCount: todayLate,
          todayAbsentCount: todayAbsent,
          todayHomeworkIncompleteCount: todayHwIncomplete,
          monthlyAverageScore: monthlyAvgScore,
          monthlyAttendanceRate: monthlyAttendanceRate,
          monthlyHomeworkCompletionRate: monthlyHomeworkRate,
          dangerStudentCount: dangerCount,
          aiAnalysisSummary: aiSummary,
          growthLeaderboard: leaderboard.take(5).toList(),
          recentActivity: recent.take(5).toList(),
        );
      },
    );
  }
}
