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
    required List<int> scores,
    required List<String> attendanceStatuses,
    required List<String> homeworkStatuses,
  }) {
    // Determine overall sufficiency (requires at least some basic records to produce analysis)
    final bool isSufficient = scores.length >= 2 || homeworkStatuses.isNotEmpty || attendanceStatuses.isNotEmpty;

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
    if (scores.length >= 2) {
      final last4 = scores.length > 4 ? scores.sublist(scores.length - 4) : scores;
      final avgLast4 = last4.reduce((a, b) => a + b) / last4.length;

      String comparison = '';
      if (scores.length > 4) {
        final prev = scores.sublist(0, scores.length - 4);
        final avgPrev = prev.reduce((a, b) => a + b) / prev.length;
        final diff = (avgLast4 - avgPrev).round();
        comparison = diff >= 0 
            ? ' (이전 평균 대비 +${diff}점)' 
            : ' (이전 평균 대비 ${diff}점)';
      } else {
        final latest = scores.last;
        final prev = scores[scores.length - 2];
        final diff = latest - prev;
        comparison = diff >= 0 
            ? ' (직전 시험 대비 +${diff}점)' 
            : ' (직전 시험 대비 ${diff}점)';
      }
      examText = '최근 ${last4.length}회 평균 ${avgLast4.toStringAsFixed(0)}점$comparison';
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
      final rate = (present + late) / attendanceStatuses.length;
      attendanceText = '출석률 ${(rate * 100).toStringAsFixed(0)}%';
    }

    // 4. Growth Section
    String growthText = '분석할 데이터가 충분하지 않습니다.';
    if (scores.length >= 2) {
      final latest = scores.last;
      final first = scores.first;
      final growthPct = first > 0 ? (((latest - first) / first) * 100).round() : 0;
      growthText = growthPct >= 0 ? '+$growthPct%' : '$growthPct%';
    }

    // 5. Warnings Section
    String warningText = '특이사항 없음 (출결 및 과제 상태 양호)';
    
    // Check for 3 consecutive homework misses
    bool consecutiveHwMiss = false;
    if (homeworkStatuses.length >= 3) {
      // homeworkStatuses are in chronological order (latest is last)
      final len = homeworkStatuses.length;
      if (homeworkStatuses[len - 1] == 'INCOMPLETE' &&
          homeworkStatuses[len - 2] == 'INCOMPLETE' &&
          homeworkStatuses[len - 3] == 'INCOMPLETE') {
        consecutiveHwMiss = true;
      }
    }

    // Check for 3 consecutive absences
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
      // Check for low averages
      if (homeworkStatuses.isNotEmpty) {
        final completed = homeworkStatuses.where((s) => s == 'COMPLETED').length;
        final partial = homeworkStatuses.where((s) => s == 'PARTIAL').length;
        final rate = (completed + (partial * 0.5)) / homeworkStatuses.length;
        if (rate < 0.70) {
          warningText = '과제 완료율 저조 (70% 미만)';
        }
      }
    }

    // 6. Recommendation Section
    String recommendationText = '현재 수준의 성실도를 유지하며 학원 학습 일정을 충실히 따르기를 권장합니다.';
    if (scores.isNotEmpty) {
      recommendationText = '현재 수준의 성실도 유지 및 심화 오답 클리닉 참가 권장';
    }
    if (warningText.contains('숙제 미완료')) {
      recommendationText = '과제 미완료 누적 해소를 위해 보강 클리닉 필수 참석 및 학습 일지 작성 권장';
    } else if (warningText.contains('결석')) {
      recommendationText = '결석으로 인한 학습 단절 해소를 위한 개념 보강 동영상 수강 권장';
    } else if (scores.length >= 2) {
      final latest = scores.last;
      final prev = scores[scores.length - 2];
      if (latest < prev) {
        recommendationText = '다음 시험 전 오답률 높은 단원의 기초 개념 다지기 및 유사 유형 오답 복습 권장';
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
}
