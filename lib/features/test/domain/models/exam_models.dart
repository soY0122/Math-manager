import 'package:cloud_firestore/cloud_firestore.dart';

class ExamOverview {
  final String id;
  final String title;
  final String date;
  final int grade;
  final double averageScore;
  final int maxScore;
  final int minScore;
  final int studentCount;
  final String examGroupId;
  final String examGroupName;
  final String examGroupColorHex;
  final int maxPossibleScore;

  const ExamOverview({
    required this.id,
    required this.title,
    required this.date,
    required this.grade,
    required this.averageScore,
    required this.maxScore,
    required this.minScore,
    required this.studentCount,
    required this.examGroupId,
    required this.examGroupName,
    required this.examGroupColorHex,
    this.maxPossibleScore = 100,
  });
}

class StudentExamScoreItem {
  final String studentId;
  final String studentName;
  final String school;
  final int grade;
  final String className;
  final String? recordId;
  final int score;

  const StudentExamScoreItem({
    required this.studentId,
    required this.studentName,
    required this.school,
    required this.grade,
    required this.className,
    this.recordId,
    required this.score,
  });

  StudentExamScoreItem copyWith({
    String? studentId,
    String? studentName,
    String? school,
    int? grade,
    String? className,
    String? recordId,
    int? score,
  }) {
    return StudentExamScoreItem(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      school: school ?? this.school,
      grade: grade ?? this.grade,
      className: className ?? this.className,
      recordId: recordId ?? this.recordId,
      score: score ?? this.score,
    );
  }
}

class ExamParticipantCalculator {
  /// Cleans and filters a list of raw records to remove duplicate studentId-examId
  /// pairs, null/empty scores, and invalid score ranges.
  static List<Map<String, dynamic>> cleanRawRecords(
    List<Map<String, dynamic>> rawRecords, {
    Map<String, int>? examMaxScores,
  }) {
    final List<Map<String, dynamic>> clean = [];
    final Set<String> seen = {};
    for (final r in rawRecords) {
      final examId = r['examId'] as String?;
      final studentId = r['studentId'] as String?;
      if (examId == null || studentId == null || studentId.trim().isEmpty) continue;
      
      final scoreVal = r['score'];
      if (scoreVal == null) continue;
      
      int? parsedScore;
      if (scoreVal is int) {
        parsedScore = scoreVal;
      } else if (scoreVal is String) {
        parsedScore = int.tryParse(scoreVal.trim());
      }
      
      if (parsedScore == null || parsedScore < 0) continue;
      
      final limit = examMaxScores?[examId] ?? 100;
      if (parsedScore > limit) continue;
      
      final key = '${examId}_$studentId';
      if (!seen.contains(key)) {
        seen.add(key);
        final Map<String, dynamic> copy = Map<String, dynamic>.from(r);
        copy['score'] = parsedScore;
        clean.add(copy);
      }
    }
    return clean;
  }

  /// Counts the actual number of unique students who have a valid score recorded
  /// for a specific exam from raw Firestore exam_records documents.
  static int count({
    required String examId,
    required List<Map<String, dynamic>> rawRecords,
    int maxPossibleScore = 100,
  }) {
    final clean = cleanRawRecords(rawRecords, examMaxScores: {examId: maxPossibleScore});
    return clean.where((r) => r['examId'] == examId).length;
  }

  /// Calculates the average, max, and min scores for a specific exam
  /// using only the valid unique student scores.
  static Map<String, dynamic> calculateStats({
    required String examId,
    required List<Map<String, dynamic>> rawRecords,
    int maxPossibleScore = 100,
  }) {
    final clean = cleanRawRecords(rawRecords, examMaxScores: {examId: maxPossibleScore})
        .where((r) => r['examId'] == examId)
        .toList();

    if (clean.isEmpty) {
      return {
        'count': 0,
        'average': 0.0,
        'max': 0,
        'min': 0,
      };
    }

    final percentagesList = clean.map((r) => (r['score'] as int) / maxPossibleScore * 100).toList();
    final averagePct = percentagesList.reduce((a, b) => a + b) / percentagesList.length;

    final scoresList = clean.map((r) => r['score'] as int).toList();
    final max = scoresList.reduce((a, b) => a > b ? a : b);
    final min = scoresList.reduce((a, b) => a < b ? a : b);

    return {
      'count': scoresList.length,
      'average': averagePct,
      'max': max,
      'min': min,
    };
  }
}

class ExamScoreFormatter {
  static double calculatePercentage(num score, num maxPossibleScore) {
    if (maxPossibleScore <= 0) return 0.0;
    return (score / maxPossibleScore) * 100;
  }

  static String formatPercentage(double pct) {
    return pct % 1 == 0 ? '${pct.toStringAsFixed(0)}%' : '${pct.toStringAsFixed(1)}%';
  }

  static String formatRaw(double val) {
    return val % 1 == 0 ? val.toStringAsFixed(0) : val.toStringAsFixed(1);
  }

  static String formatScore(num score, num maxPossibleScore) {
    final pct = calculatePercentage(score, maxPossibleScore);
    return '${formatRaw(score.toDouble())} / ${maxPossibleScore.toStringAsFixed(0)} (${formatPercentage(pct)})';
  }

  static String formatStats(double percentage, double rawScore, num maxPossibleScore) {
    return '${formatPercentage(percentage)} (${formatRaw(rawScore)} / ${maxPossibleScore.toStringAsFixed(0)})';
  }
}

class StudentComparisonResult {
  final double studentAveragePct;
  final double classAveragePct;
  final double difference;
  final int rank;
  final int percentile;
  final int totalParticipants;
  final String trend; // 'improving', 'falling', 'maintaining'

  const StudentComparisonResult({
    required this.studentAveragePct,
    required this.classAveragePct,
    required this.difference,
    required this.rank,
    required this.percentile,
    required this.totalParticipants,
    required this.trend,
  });
}

class ExamGroupComparisonCalculator {
  static StudentComparisonResult? calculate({
    required String studentId,
    required String examGroupId,
    required List<Map<String, dynamic>> rawRecords,
    required List<Map<String, dynamic>> allExams,
  }) {
    final groupExams = allExams.where((e) => e['examGroupId'] == examGroupId).toList();
    if (groupExams.isEmpty) return null;
    final groupExamIds = groupExams.map((e) => e['docId'] as String).toSet();

    final Map<String, int> examMaxScores = {
      for (final e in groupExams) e['docId'] as String: e['maxPossibleScore'] as int? ?? 100
    };

    final cleanRecords = ExamParticipantCalculator.cleanRawRecords(rawRecords, examMaxScores: examMaxScores)
        .where((r) => groupExamIds.contains(r['examId'] as String))
        .toList();

    final Map<String, List<Map<String, dynamic>>> studentMap = {};
    for (final r in cleanRecords) {
      final sId = r['studentId'] as String;
      studentMap.putIfAbsent(sId, () => []).add(r);
    }

    final Map<String, double> studentAverages = {};
    for (final sId in studentMap.keys) {
      final records = studentMap[sId]!;
      final pcts = records.map((r) {
        final examId = r['examId'] as String;
        final maxScore = examMaxScores[examId] ?? 100;
        return (r['score'] as int) / maxScore * 100;
      }).toList();
      studentAverages[sId] = pcts.reduce((a, b) => a + b) / pcts.length;
    }

    if (!studentAverages.containsKey(studentId)) return null;

    final sortedStudents = studentAverages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalParticipants = sortedStudents.length;
    final studentIndex = sortedStudents.indexWhere((entry) => entry.key == studentId);
    final rank = studentIndex + 1;
    final percentile = totalParticipants > 0 ? ((rank / totalParticipants) * 100).round() : 100;

    final classAveragePct = studentAverages.values.reduce((a, b) => a + b) / studentAverages.length;
    final studentAveragePct = studentAverages[studentId]!;
    final difference = studentAveragePct - classAveragePct;

    // Trend calculation
    String trend = 'maintaining';
    final sortedGroupExams = List<Map<String, dynamic>>.from(groupExams)
      ..sort((a, b) {
        final da = a['date'] as Timestamp?;
        final db = b['date'] as Timestamp?;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });

    final studentGroupRecords = cleanRecords.where((r) => r['studentId'] == studentId).toList();
    final Map<String, DateTime> examDates = {
      for (final e in sortedGroupExams)
        e['docId'] as String: (e['date'] as Timestamp?)?.toDate() ?? DateTime.now()
    };
    studentGroupRecords.sort((a, b) => (examDates[a['examId']] ?? DateTime.now()).compareTo(examDates[b['examId']] ?? DateTime.now()));

    if (studentGroupRecords.length >= 2) {
      final latestRec = studentGroupRecords.last;
      final latestExamId = latestRec['examId'] as String;
      final latestMaxScore = examMaxScores[latestExamId] ?? 100;
      final latestStudentPct = (latestRec['score'] as int) / latestMaxScore * 100;

      final latestExamRecs = cleanRecords.where((r) => r['examId'] == latestExamId).toList();
      final latestClassAvg = latestExamRecs.map((r) => (r['score'] as int) / latestMaxScore * 100).reduce((a, b) => a + b) / latestExamRecs.length;
      final latestDiff = latestStudentPct - latestClassAvg;

      final priorRecs = studentGroupRecords.sublist(0, studentGroupRecords.length - 1);
      double priorDiffSum = 0.0;
      int count = 0;
      for (final pr in priorRecs) {
        final pExamId = pr['examId'] as String;
        final pMaxScore = examMaxScores[pExamId] ?? 100;
        final pStudentPct = (pr['score'] as int) / pMaxScore * 100;

        final pExamRecs = cleanRecords.where((r) => r['examId'] == pExamId).toList();
        if (pExamRecs.isEmpty) continue;
        final pClassAvg = pExamRecs.map((r) => (r['score'] as int) / pMaxScore * 100).reduce((a, b) => a + b) / pExamRecs.length;
        priorDiffSum += (pStudentPct - pClassAvg);
        count++;
      }

      final priorDiffAvg = count > 0 ? priorDiffSum / count : latestDiff;

      if (latestDiff > priorDiffAvg + 2.0) {
        trend = 'improving';
      } else if (latestDiff < priorDiffAvg - 2.0) {
        trend = 'falling';
      } else {
        trend = 'maintaining';
      }
    }

    return StudentComparisonResult(
      studentAveragePct: studentAveragePct,
      classAveragePct: classAveragePct,
      difference: difference,
      rank: rank,
      percentile: percentile,
      totalParticipants: totalParticipants,
      trend: trend,
    );
  }
}
