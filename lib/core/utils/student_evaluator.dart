import 'package:cloud_firestore/cloud_firestore.dart';
import '../../features/test/domain/models/exam_models.dart';

class AIEvaluation {
  final String examText;
  final String homeworkText;
  final String attendanceText;
  final String growthText;
  final String warningText;
  final String recommendationText;
  final bool isSufficient;

  const AIEvaluation({
    required this.examText,
    required this.homeworkText,
    required this.attendanceText,
    required this.growthText,
    required this.warningText,
    required this.recommendationText,
    required this.isSufficient,
  });
}

class StudentEvaluator {
  static AIEvaluation evaluate({
    required List<double> scorePercentages,
    required List<String> attendanceStatuses,
    required List<String> homeworkStatuses,
    StudentComparisonResult? comparison,
  }) {
    final bool isSufficient = scorePercentages.length >= 2 || homeworkStatuses.isNotEmpty || attendanceStatuses.isNotEmpty;

    if (!isSufficient) {
      return const AIEvaluation(
        examText: '분석할 데이터가 충분하지 않습니다.',
        homeworkText: '분석할 데이터가 충분하지 않습니다.',
        attendanceText: '분석할 데이터가 충분하지 않습니다.',
        growthText: '분석할 데이터가 충분하지 않습니다.',
        warningText: '분석할 데이터가 충분하지 않습니다.',
        recommendationText: '분석할 데이터가 충분하지 않습니다.',
        isSufficient: false,
      );
    }

    // 1. Exams Section
    String examText = '분석할 데이터가 충분하지 않습니다.';
    if (scorePercentages.isNotEmpty) {
      final last4 = scorePercentages.length > 4 ? scorePercentages.sublist(scorePercentages.length - 4) : scorePercentages;
      final avgLast4 = last4.reduce((a, b) => a + b) / last4.length;

      String comparisonStr = '';
      if (scorePercentages.length > 4) {
        final prev = scorePercentages.sublist(0, scorePercentages.length - 4);
        final avgPrev = prev.reduce((a, b) => a + b) / prev.length;
        final diff = (avgLast4 - avgPrev).round();
        comparisonStr = diff >= 0 
            ? ' (이전 평균 대비 +${diff}%)' 
            : ' (이전 평균 대비 ${diff}%)';
      } else if (scorePercentages.length >= 2) {
        final latest = scorePercentages.last;
        final prev = scorePercentages[scorePercentages.length - 2];
        final diff = (latest - prev).round();
        comparisonStr = diff >= 0 
            ? ' (직전 시험 대비 +${diff}%)' 
            : ' (직전 시험 대비 ${diff}%)';
      }
      examText = '최근 ${last4.length}회 평균 ${avgLast4.toStringAsFixed(1)}%$comparisonStr';
    }

    // 2. Homework Section
    String homeworkText = '분석할 데이터가 충분하지 않습니다.';
    if (homeworkStatuses.isNotEmpty) {
      final completed = homeworkStatuses.where((s) => s == 'COMPLETED').length;
      final partial = homeworkStatuses.where((s) => s == 'PARTIAL').length;
      final rate = (completed + (partial * 0.5)) / homeworkStatuses.length;
      homeworkText = '완료율 ${(rate * 100).toStringAsFixed(0)}%';
    }

    // 3. Attendance Section
    String attendanceText = '분석할 데이터가 충분하지 않습니다.';
    if (attendanceStatuses.isNotEmpty) {
      final present = attendanceStatuses.where((s) => s == 'ATTENDANCE').length;
      final late = attendanceStatuses.where((s) => s == 'LATE').length;
      final earlyLeave = attendanceStatuses.where((s) => s == 'EARLY_LEAVE').length;
      final rate = (present + late + earlyLeave) / attendanceStatuses.length;
      attendanceText = '출석률 ${(rate * 100).toStringAsFixed(0)}%';
    }

    // 4. Growth Section
    String growthText = '분석할 데이터가 충분하지 않습니다.';
    if (scorePercentages.length >= 2) {
      final growthRate = StudentGrowthCalculator.calculateFromScores(scorePercentages);
      final growthPct = growthRate.round();
      growthText = growthPct >= 0 ? '+$growthPct%' : '$growthPct%';
    }

    // 5. Warnings Section
    String warningText = '특이사항 없음 (출결 및 과제 상태 양호)';
    
    bool consecutiveHwMiss = false;
    if (homeworkStatuses.length >= 3) {
      final len = homeworkStatuses.length;
      if (homeworkStatuses[len - 1] == 'INCOMPLETE' &&
          homeworkStatuses[len - 2] == 'INCOMPLETE' &&
          homeworkStatuses[len - 3] == 'INCOMPLETE') {
        consecutiveHwMiss = true;
      }
    }

    bool consecutiveAbsent = false;
    if (attendanceStatuses.length >= 3) {
      final len = attendanceStatuses.length;
      if (attendanceStatuses[len - 1] == 'ABSENT' &&
          attendanceStatuses[len - 2] == 'ABSENT' &&
          attendanceStatuses[len - 3] == 'ABSENT') {
        consecutiveAbsent = true;
      }
    }

    if (consecutiveHwMiss && consecutiveAbsent) {
      warningText = '최근 3회 숙제 미완료 및 3회 연속 결석 발생';
    } else if (consecutiveHwMiss) {
      warningText = '최근 3회 숙제 미완료';
    } else if (consecutiveAbsent) {
      warningText = '최근 3회 연속 결석';
    } else {
      if (homeworkStatuses.isNotEmpty) {
        final completed = homeworkStatuses.where((s) => s == 'COMPLETED').length;
        final partial = homeworkStatuses.where((s) => s == 'PARTIAL').length;
        final rate = (completed + (partial * 0.5)) / homeworkStatuses.length;
        if (rate < 0.70) {
          warningText = '과제 완료율 저조 (70% 미만)';
        }
      }
    }

    if (comparison != null) {
      if (comparison.difference < -5.0) {
        warningText = '최근 성취도가 반 평균 대비 ${comparison.difference.abs().toStringAsFixed(1)}% 낮아 주의 깊은 모니터링이 필요합니다.';
      }
    }

    // 6. Recommendation Section
    String recommendationText = '현재 수준의 성실도를 유지하며 학원 학습 일정을 충실히 따르기를 권장합니다.';
    if (scorePercentages.isNotEmpty) {
      recommendationText = '현재 수준의 성실도 유지 및 심화 오답 클리닉 참가 권장';
    }
    if (warningText.contains('숙제 미완료')) {
      recommendationText = '과제 미완료 누적 해소를 위해 보강 클리닉 필수 참석 및 학습 일지 작성 권장';
    } else if (warningText.contains('결석')) {
      recommendationText = '결석으로 인한 학습 단절 해소를 위한 개념 보강 동영상 수강 권장';
    } else if (scorePercentages.length >= 2) {
      final latest = scorePercentages.last;
      final prev = scorePercentages[scorePercentages.length - 2];
      if (latest < prev) {
        recommendationText = '다음 시험 전 오답률 높은 단원의 기초 개념 다지기 및 유사 유형 오답 복습 권장';
      }
    }

    if (comparison != null) {
      final diffText = comparison.difference >= 0 ? '+' : '';
      final comparisonInsight = '\n[반내 비교] 석차: ${comparison.rank}/${comparison.totalParticipants} (상위 ${comparison.percentile}%), 평균 대비 ${diffText}${comparison.difference.toStringAsFixed(1)}%';
      recommendationText += comparisonInsight;
      
      if (comparison.trend == 'improving') {
        recommendationText += '\n★ 다른 학생들보다 빠르게 성적이 향상되고 있으므로 칭찬과 격려를 부탁드립니다.';
      } else if (comparison.trend == 'falling') {
        recommendationText += '\n⚠️ 최근 성적이 반 평균 대비 하락하는 추세이므로 추가적인 개별 학습 지원이 필요할 수 있습니다.';
      }
    }

    return AIEvaluation(
      examText: examText,
      homeworkText: homeworkText,
      attendanceText: attendanceText,
      growthText: growthText,
      warningText: warningText,
      recommendationText: recommendationText,
      isSufficient: true,
    );
  }

  static AIEvaluation evaluateWithRisk({
    required List<double> scorePercentages,
    required List<String> attendanceStatuses,
    required List<String> homeworkStatuses,
    required int riskScore,
    required List<String> triggers,
    StudentComparisonResult? comparison,
  }) {
    final base = evaluate(
      scorePercentages: scorePercentages,
      attendanceStatuses: attendanceStatuses,
      homeworkStatuses: homeworkStatuses,
      comparison: comparison,
    );

    if (!base.isSufficient) return base;

    String warningText = base.warningText;
    String recommendationText = base.recommendationText;

    if (riskScore >= 4) {
      warningText = '출결 및 학습 패턴의 상당한 변화가 감지되었습니다.\n'
          '[위험 등급] 집중 관리 필요 학생\n'
          '[위험 점수] $riskScore점\n\n'
          '감지 요인:\n- ' + triggers.join('\n- ');
      recommendationText = '최근 학습 데이터 분석에 기반하여 추가적인 개별 학습 지원이 유용할 수 있습니다.';
    } else if (riskScore >= 2) {
      warningText = '출결 및 과제 수행 상황에 보완이 필요한 패턴이 일부 감지되었습니다.\n'
          '[위험 등급] 주의 필요 학생\n'
          '[위험 점수] $riskScore점\n\n'
          '감지 요인:\n- ' + triggers.join('\n- ');
      recommendationText = '학습 습관 개선을 위한 과제 완료율 모니터링 및 개별 상담을 권장합니다.';
    }

    return AIEvaluation(
      examText: base.examText,
      homeworkText: base.homeworkText,
      attendanceText: base.attendanceText,
      growthText: base.growthText,
      warningText: warningText,
      recommendationText: recommendationText,
      isSufficient: true,
    );
  }
}

class StudentRiskResult {
  final int score;
  final String classification;
  final List<String> triggers;

  const StudentRiskResult({
    required this.score,
    required this.classification,
    required this.triggers,
  });
}

class StudentRiskCalculator {
  static StudentRiskResult calculate({
    required DateTime evaluationDate,
    required DateTime? registrationDate,
    required List<Map<String, dynamic>> attendanceLogs,
    required List<Map<String, dynamic>> homeworkLogs,
    required List<Map<String, dynamic>> examLogs,
  }) {
    int score = 0;
    final List<String> triggers = [];

    // --- 1. Attendance Issues ---
    final last30DaysLimit = evaluationDate.subtract(const Duration(days: 30));
    final attsLast30 = attendanceLogs.where((a) {
      final date = a['date'] as DateTime?;
      return date != null && date.isAfter(last30DaysLimit);
    }).toList();
    
    final absencesLast30 = attsLast30.where((a) => a['status'] == 'ABSENT').length;
    if (absencesLast30 >= 3) {
      score += 1;
      triggers.add('최근 30일 이내 결석 3회 이상 ($absencesLast30회) (+1)');
    }

    final latesLast30 = attsLast30.where((a) => a['status'] == 'LATE').length;
    if (latesLast30 >= 5) {
      score += 1;
      triggers.add('최근 30일 이내 지각 5회 이상 ($latesLast30회) (+1)');
    }

    // --- 2. Academic Performance Decline ---
    final sortedExams = List<Map<String, dynamic>>.from(examLogs)
      ..sort((a, b) {
        final da = a['date'] as DateTime?;
        final db = b['date'] as DateTime?;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    
    final percentages = sortedExams.map((e) {
      final scoreVal = e['score'] as int;
      final maxScore = e['maxPossibleScore'] as int? ?? 100;
      return (scoreVal / maxScore) * 100;
    }).toList();

    if (percentages.length >= 2) {
      final latestPct = percentages.last;
      final prevPcts = percentages.sublist(0, percentages.length - 1);
      final prevAvg = prevPcts.reduce((a, b) => a + b) / prevPcts.length;
      if (latestPct <= prevAvg - 20) {
        score += 1;
        triggers.add('최근 성적이 이전 평균 대비 20% 이상 하락 (이전 평균: ${prevAvg.toStringAsFixed(1)}%, 최근: ${latestPct.toStringAsFixed(1)}%) (+1)');
      }
    }

    if (percentages.length >= 3) {
      final len = percentages.length;
      if (percentages[len - 1] < percentages[len - 2] && percentages[len - 2] < percentages[len - 3]) {
        score += 1;
        triggers.add('최근 3회 시험 성적 연속 하락 (+1)');
      }
    }

    // --- 3. Homework Performance Issues ---
    final last4WeeksLimit = evaluationDate.subtract(const Duration(days: 28));
    final hwsLast28 = homeworkLogs.where((h) {
      final date = h['date'] as DateTime?;
      return date != null && date.isAfter(last4WeeksLimit);
    }).toList();
    if (hwsLast28.isNotEmpty) {
      final completed = hwsLast28.where((h) => h['status'] == 'COMPLETED').length;
      final partial = hwsLast28.where((h) => h['status'] == 'PARTIAL').length;
      final rate = (completed + (partial * 0.5)) / hwsLast28.length;
      if (rate < 0.50) {
        score += 1;
        triggers.add('최근 4주 과제 완료율 50% 미만 (${(rate * 100).toStringAsFixed(0)}%) (+1)');
      }
    }

    final sortedHws = List<Map<String, dynamic>>.from(homeworkLogs)
      ..sort((a, b) {
        final da = a['date'] as DateTime?;
        final db = b['date'] as DateTime?;
        if (da == null || db == null) return 0;
        return da.compareTo(db);
      });
    if (sortedHws.length >= 3) {
      final len = sortedHws.length;
      if (sortedHws[len - 1]['status'] == 'INCOMPLETE' &&
          sortedHws[len - 2]['status'] == 'INCOMPLETE' &&
          sortedHws[len - 3]['status'] == 'INCOMPLETE') {
        score += 1;
        triggers.add('최근 3회 연속 과제 미제출 (+1)');
      }
    }

    // --- 4. Learning Progress Stagnation ---
    final last60DaysLimit = evaluationDate.subtract(const Duration(days: 60));
    final recentExams = sortedExams.where((e) {
      final date = e['date'] as DateTime?;
      return date != null && date.isAfter(last60DaysLimit);
    }).toList();
    final olderExams = sortedExams.where((e) {
      final date = e['date'] as DateTime?;
      return date != null && date.isBefore(last60DaysLimit);
    }).toList();

    bool hasStagnation = false;
    if (recentExams.isNotEmpty && olderExams.isNotEmpty) {
      final recentAvg = recentExams.map((e) {
        final scoreVal = e['score'] as int;
        final maxScore = e['maxPossibleScore'] as int? ?? 100;
        return (scoreVal / maxScore) * 100;
      }).reduce((a, b) => a + b) / recentExams.length;

      final olderAvg = olderExams.map((e) {
        final scoreVal = e['score'] as int;
        final maxScore = e['maxPossibleScore'] as int? ?? 100;
        return (scoreVal / maxScore) * 100;
      }).reduce((a, b) => a + b) / olderExams.length;

      if (recentAvg <= olderAvg) {
        hasStagnation = true;
      }
    } else if (registrationDate != null && evaluationDate.difference(registrationDate).inDays > 60 && examLogs.isEmpty) {
      double overallAttRate = 1.0;
      if (attendanceLogs.isNotEmpty) {
        final present = attendanceLogs.where((a) => a['status'] == 'ATTENDANCE').length;
        final late = attendanceLogs.where((a) => a['status'] == 'LATE').length;
        final earlyLeave = attendanceLogs.where((a) => a['status'] == 'EARLY_LEAVE').length;
        overallAttRate = (present + late + earlyLeave) / attendanceLogs.length;
      }
      double overallHwRate = 1.0;
      if (homeworkLogs.isNotEmpty) {
        final completed = homeworkLogs.where((h) => h['status'] == 'COMPLETED').length;
        final partial = homeworkLogs.where((h) => h['status'] == 'PARTIAL').length;
        overallHwRate = (completed + (partial * 0.5)) / homeworkLogs.length;
      }

      final hasConcerns = overallAttRate < 0.90 || overallHwRate < 0.80;
      if (hasConcerns) {
        hasStagnation = true;
      }
    }
    
    if (hasStagnation) {
      score += 1;
      if (examLogs.isEmpty) {
        triggers.add('등록 후 2달간 평가 기록이 없으며 출결 또는 과제 성실도 저조 감지 (+1)');
      } else {
        triggers.add('최근 2달간 학습 성취도 향상 없음 (+1)');
      }
    }

    String classification;
    if (score >= 4) {
      classification = '집중 관리 필요 학생';
    } else if (score >= 2) {
      classification = '주의 필요 학생';
    } else {
      classification = '정상';
    }

    return StudentRiskResult(
      score: score,
      classification: classification,
      triggers: triggers,
    );
  }
}

class StudentGrowthCalculator {
  static Map<String, dynamic> calculate({
    required List<Map<String, dynamic>> studentRecords,
    required List<Map<String, dynamic>> allExams,
  }) {
    final List<Map<String, dynamic>> examDatesAndPercentages = [];
    for (final r in studentRecords) {
      final examId = r['examId'] as String?;
      final score = r['score'] as int? ?? 0;
      final examDoc = allExams.firstWhere(
        (e) => e['docId'] == examId,
        orElse: () => <String, dynamic>{},
      );
      final examDateTs = examDoc['date'] as Timestamp?;
      if (examDateTs == null) continue;
      
      final maxPossibleScore = examDoc['maxPossibleScore'] as int? ?? 100;
      final percentage = (score / maxPossibleScore) * 100;
      
      examDatesAndPercentages.add({
        'date': examDateTs.toDate(),
        'percentage': percentage,
      });
    }

    examDatesAndPercentages.sort((a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));
    final percentages = examDatesAndPercentages.map((item) => item['percentage'] as double).toList();

    if (percentages.length < 2) {
      return {
        'rate': 0.0,
        'trend': '유지',
      };
    }

    final double recent = percentages.last;
    final priorPercentages = percentages.sublist(0, percentages.length - 1);
    if (priorPercentages.isEmpty) {
      return {
        'rate': 0.0,
        'trend': '유지',
      };
    }

    final double previousAverage = priorPercentages.reduce((a, b) => a + b) / priorPercentages.length;
    final double rate = recent - previousAverage;
    String trend = '유지';
    if (rate > 5.0) {
      trend = '상승 중';
    } else if (rate < -5.0) {
      trend = '하락 중';
    }

    return {
      'rate': rate,
      'trend': trend,
    };
  }

  static double calculateFromScores(List<double> chronologicalPercentageScores) {
    if (chronologicalPercentageScores.length < 2) {
      return 0.0;
    }
    final double recent = chronologicalPercentageScores.last;
    final priorScores = chronologicalPercentageScores.sublist(0, chronologicalPercentageScores.length - 1);
    if (priorScores.isEmpty) {
      return 0.0;
    }
    final double previousAverage = priorScores.reduce((a, b) => a + b) / priorScores.length;
    return recent - previousAverage;
  }
}
