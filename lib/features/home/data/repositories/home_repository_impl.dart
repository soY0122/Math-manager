import 'dart:async';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../domain/repositories/home_repository.dart';
import '../../../../core/database/database.dart';

class HomeRepositoryImpl implements HomeRepository {
  final AppDatabase db;

  HomeRepositoryImpl(this.db);

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
  Stream<DashboardStats> watchDashboardStats(int? gradeFilter) {
    return _watchMulti([
      db.studentsBox,
      db.attendancesBox,
      db.homeworksBox,
      db.examsBox,
      db.examRecordsBox,
    ]).asyncMap((_) async {
      final todayStr = DateTime.now().toIso8601String().split('T')[0];

      // 1. Fetch data from boxes
      final allStudents = db.studentsBox.values.toList();
      final allAttendances = db.attendancesBox.values.toList();
      final allHomeworks = db.homeworksBox.values.toList();
      final allRecords = db.examRecordsBox.values.toList();

      var activeStudents = allStudents.where((s) => s['is_active'] == true).toList();
      if (gradeFilter != null) {
        activeStudents = activeStudents.where((s) => s['grade'] == gradeFilter).toList();
      }
      final activeStudentIds = activeStudents.map((s) => s['id'] as int).toSet();

      // 2. Today's attendance counts
      final todayAtts = allAttendances
          .where((a) => a['date'] == todayStr && activeStudentIds.contains(a['student_id']))
          .toList();

      int todayPresent = 0;
      int todayLate = 0;
      int todayAbsent = 0;

      for (final att in todayAtts) {
        final status = att['status'] as String;
        if (status == 'ATTENDANCE') todayPresent++;
        if (status == 'LATE') todayLate++;
        if (status == 'ABSENT') todayAbsent++;
      }

      // 3. Today's homework incomplete counts
      final todayHws = allHomeworks
          .where((h) => h['date'] == todayStr && activeStudentIds.contains(h['student_id']))
          .toList();

      int todayHwIncomplete = 0;
      for (final hw in todayHws) {
        final status = hw['status'] as String;
        if (status == 'INCOMPLETE') todayHwIncomplete++;
      }

      // 4. Monthly averages / rates
      // Average score
      final activeStudentRecords = allRecords
          .where((r) => activeStudentIds.contains(r['student_id']))
          .toList();
      final double monthlyAvgScore = activeStudentRecords.isNotEmpty
          ? activeStudentRecords.map((r) => r['score'] as int).reduce((a, b) => a + b) / activeStudentRecords.length
          : 0.0;

      // Attendance rate
      final activeStudentAtts = allAttendances
          .where((a) => activeStudentIds.contains(a['student_id']))
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

      // Homework rate
      final activeStudentHws = allHomeworks
          .where((h) => activeStudentIds.contains(h['student_id']))
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

      for (final student in activeStudents) {
        final id = student['id'] as int;
        final name = student['name'] as String;
        final grade = student['grade'] as int;
        final className = student['class_name'] as String;

        // Student scores (sorted by exam date/id)
        final studentScores = allRecords
            .where((r) => r['student_id'] == id)
            .toList();
        studentScores.sort((a, b) => (a['exam_id'] as int).compareTo(b['exam_id'] as int));
        final scoresList = studentScores.map((r) => r['score'] as int).toList();

        // Growth rate
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
        final studentAttsLog = allAttendances.where((a) => a['student_id'] == id).toList();
        int sPresent = 0;
        int sLate = 0;
        for (final att in studentAttsLog) {
          final status = att['status'] as String;
          if (status == 'ATTENDANCE') sPresent++;
          if (status == 'LATE') sLate++;
        }
        final double sAttRate = studentAttsLog.isNotEmpty ? (sPresent + sLate) / studentAttsLog.length : 1.0;

        final studentHwsLog = allHomeworks.where((h) => h['student_id'] == id).toList();
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

      // Sort leaderboard by growth rate descending
      leaderboard.sort((a, b) => b.growthRate.compareTo(a.growthRate));

      // 6. Recent activity (Latest logs)
      final List<RecentActivityItem> recent = [];

      // Combine logs
      // Add attendances today/yesterday
      for (final att in allAttendances) {
        final sId = att['student_id'] as int;
        if (!activeStudentIds.contains(sId)) continue;
        final studentName = allStudents.firstWhere((s) => s['id'] == sId, orElse: () => null)?['name'] ?? '학생';
        final date = att['date'] as String;
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
        final sId = hw['student_id'] as int;
        if (!activeStudentIds.contains(sId)) continue;
        final studentName = allStudents.firstWhere((s) => s['id'] == sId, orElse: () => null)?['name'] ?? '학생';
        final date = hw['date'] as String;
        final status = hw['status'] as String;
        String statusText = status == 'COMPLETED' ? '과제 완료' : (status == 'PARTIAL' ? '과제 일부완료' : '과제 미완료');

        recent.add(RecentActivityItem(
          title: '$studentName $statusText',
          description: '${hw['title']} - $statusText 처리되었습니다.',
          timestamp: date == todayStr ? '오늘' : date,
          type: 'HOMEWORK',
        ));
      }

      // Sort recent activities chronologically (newest first)
      recent.sort((a, b) => b.description.compareTo(a.description));

      // AI Summary
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
    });
  }
}
