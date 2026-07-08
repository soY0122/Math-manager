import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../domain/repositories/home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  HomeRepositoryImpl();



  @override
  Stream<DashboardStats> watchDashboardStats(int? gradeFilter) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final attendancesStream = FirebaseFirestore.instance.collection('attendances').snapshots();
    final homeworksStream = FirebaseFirestore.instance.collection('homeworks').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();

    return Rx.combineLatest4<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        DashboardStats>(
      studentsStream,
      attendancesStream,
      homeworksStream,
      examRecordsStream,
      (studentsSnap, attendancesSnap, homeworksSnap, examRecordsSnap) {
        final today = DateTime.now();
        final targetTimestamp = Timestamp.fromDate(DateTime(today.year, today.month, today.day));
        final todayStr = DateFormat('yyyy-MM-dd').format(today);

        final allStudents = studentsSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();
        final allAttendances = attendancesSnap.docs.map((doc) => doc.data()).toList();
        final allHomeworks = homeworksSnap.docs.map((doc) => doc.data()).toList();
        final allRecords = examRecordsSnap.docs.map((doc) => doc.data()).toList();

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
          studentScores.sort((a, b) => (a['examId'] as String? ?? '').compareTo(b['examId'] as String? ?? ''));
          final scoresList = studentScores.map((r) => r['score'] as int).toList();

          double growthRate = 0.0;
          String growthTrend = '유지';
          if (scoresList.length >= 2) {
            final latest = scoresList[scoresList.length - 1];
            final previous = scoresList[scoresList.length - 2];
            if (previous > 0) {
              growthRate = ((latest - previous) / previous) * 100;
            }
            if (growthRate > 5.0) {
              growthTrend = '상승 중';
              risingCount++;
            } else if (growthRate < -5.0) {
              growthTrend = '하락 중';
            }
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
          final studentAttsLog = allAttendances.where((a) => a['studentId'] == id).toList();
          int sPresent = 0;
          int sLate = 0;
          for (final att in studentAttsLog) {
            final status = att['status'] as String;
            if (status == 'ATTENDANCE') sPresent++;
            if (status == 'LATE') sLate++;
          }
          final double sAttRate = studentAttsLog.isNotEmpty ? (sPresent + sLate) / studentAttsLog.length : 1.0;

          final studentHwsLog = allHomeworks.where((h) => h['studentId'] == id).toList();
          int sCompleted = 0;
          int sPartial = 0;
          for (final hw in studentHwsLog) {
            final status = hw['status'] as String;
            if (status == 'COMPLETED') sCompleted++;
            if (status == 'PARTIAL') sPartial++;
          }
          final double sHwRate = studentHwsLog.isNotEmpty ? (sCompleted + (sPartial * 0.5)) / studentHwsLog.length : 1.0;

          if (growthRate < -5.0 || sAttRate < 0.85 || sHwRate < 0.70) {
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
            ? '최근 시험 성적 분석 결과, 성적이 고속 상승 중인 학생이 ${risingCount}명 관찰되었으나, 최근 과제 미완료 및 지각 누적으로 출결/학습 리스크가 높은 학생이 ${dangerCount}명 존재합니다. 개별 클리닉을 권장합니다.'
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
