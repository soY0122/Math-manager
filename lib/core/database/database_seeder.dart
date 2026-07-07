import 'database.dart';

Future<void> seedDatabase(AppDatabase db) async {
  if (db.settingsBox.get('database_seeded', defaultValue: false) == true) {
    return; // Already seeded
  }

  // 1. Seed Students
  final students = [
    {
      'id': 1,
      'name': '김민준',
      'photo_path': null,
      'school': '서울초등학교',
      'grade': 3,
      'class_name': 'A반',
      'parent_phone': '010-1234-5678',
      'registration_date': '2026-03-02',
      'memo': '수학적 사고력이 뛰어남',
      'is_active': true,
    },
    {
      'id': 2,
      'name': '이서연',
      'photo_path': null,
      'school': '서울초등학교',
      'grade': 6,
      'class_name': 'B반',
      'parent_phone': '010-9876-5432',
      'registration_date': '2026-03-02',
      'memo': '최근 집중력이 흐트러짐',
      'is_active': true,
    },
    {
      'id': 3,
      'name': '박지우',
      'photo_path': null,
      'school': '한국중학교',
      'grade': 8,
      'class_name': 'A반',
      'parent_phone': '010-1111-2222',
      'registration_date': '2026-03-10',
      'memo': '과제를 매우 성실히 수행함',
      'is_active': true,
    },
    {
      'id': 4,
      'name': '최현우',
      'photo_path': null,
      'school': '서울초등학교',
      'grade': 5,
      'class_name': 'A반',
      'parent_phone': '010-3333-4444',
      'registration_date': '2026-04-01',
      'memo': '기본 개념 학습이 필요함',
      'is_active': true,
    },
    {
      'id': 5,
      'name': '정예은',
      'photo_path': null,
      'school': '한국중학교',
      'grade': 9,
      'class_name': 'B반',
      'parent_phone': '010-5555-6666',
      'registration_date': '2026-04-15',
      'memo': '심화 문제 중심 클리닉 진행',
      'is_active': true,
    },
  ];

  for (final s in students) {
    await db.studentsBox.put(s['id'], s);
  }

  // 2. Seed Exams
  final exams = [
    {'id': 1, 'title': '3월 단원평가', 'date': '2026-03-25'},
    {'id': 2, 'title': '4월 중간고사 대비', 'date': '2026-04-22'},
    {'id': 3, 'title': '5월 단원평가', 'date': '2026-05-27'},
    {'id': 4, 'title': '6월 기말고사', 'date': '2026-06-24'},
  ];

  for (final e in exams) {
    await db.examsBox.put(e['id'], e);
  }

  // 3. Seed Exam Records
  final examRecords = [
    // 김민준 (Student 1) - 성장: 82 -> 88 -> 92 -> 98
    {'id': 1, 'exam_id': 1, 'student_id': 1, 'score': 82},
    {'id': 2, 'exam_id': 2, 'student_id': 1, 'score': 88},
    {'id': 3, 'exam_id': 3, 'student_id': 1, 'score': 92},
    {'id': 4, 'exam_id': 4, 'student_id': 1, 'score': 98},
    // 이서연 (Student 2) - 하락: 85 -> 78 -> 70 -> 58
    {'id': 5, 'exam_id': 1, 'student_id': 2, 'score': 85},
    {'id': 6, 'exam_id': 2, 'student_id': 2, 'score': 78},
    {'id': 7, 'exam_id': 3, 'student_id': 2, 'score': 70},
    {'id': 8, 'exam_id': 4, 'student_id': 2, 'score': 58},
    // 박지우 (Student 3) - 유지: 92 -> 92 -> 95 -> 95
    {'id': 9, 'exam_id': 1, 'student_id': 3, 'score': 92},
    {'id': 10, 'exam_id': 2, 'student_id': 3, 'score': 92},
    {'id': 11, 'exam_id': 3, 'student_id': 3, 'score': 95},
    {'id': 12, 'exam_id': 4, 'student_id': 3, 'score': 95},
    // 최현우 (Student 4) - 성장: 60 -> 65 -> 72 -> 82
    {'id': 13, 'exam_id': 1, 'student_id': 4, 'score': 60},
    {'id': 14, 'exam_id': 2, 'student_id': 4, 'score': 65},
    {'id': 15, 'exam_id': 3, 'student_id': 4, 'score': 72},
    {'id': 16, 'exam_id': 4, 'student_id': 4, 'score': 82},
    // 정예은 (Student 5) - 하락: 88 -> 85 -> 80 -> 76
    {'id': 17, 'exam_id': 1, 'student_id': 5, 'score': 88},
    {'id': 18, 'exam_id': 2, 'student_id': 5, 'score': 85},
    {'id': 19, 'exam_id': 3, 'student_id': 5, 'score': 80},
    {'id': 20, 'exam_id': 4, 'student_id': 5, 'score': 76},
  ];

  for (final er in examRecords) {
    await db.examRecordsBox.put('${er['exam_id']}_${er['student_id']}', er);
  }

  // 4. Seed Attendances (Key: studentId_date)
  final attendances = [
    {'student_id': 1, 'date': '2026-07-07', 'status': 'ATTENDANCE'},
    {'student_id': 2, 'date': '2026-07-07', 'status': 'ABSENT'},
    {'student_id': 3, 'date': '2026-07-07', 'status': 'ATTENDANCE'},
    {'student_id': 4, 'date': '2026-07-07', 'status': 'LATE'},
    {'student_id': 5, 'date': '2026-07-07', 'status': 'ATTENDANCE'},
  ];

  for (final att in attendances) {
    await db.attendancesBox.put('${att['student_id']}_${att['date']}', att);
  }

  // Seed Historical Attendances
  final dates = ['2026-07-01', '2026-07-02', '2026-07-03', '2026-07-06'];
  for (final date in dates) {
    for (int studentId = 1; studentId <= 5; studentId++) {
      await db.attendancesBox.put('${studentId}_$date', {
        'student_id': studentId,
        'date': date,
        'status': 'ATTENDANCE',
      });
    }
  }
  // Extra absence for Student 2 on 2026-07-05
  await db.attendancesBox.put('2_2026-07-05', {
    'student_id': 2,
    'date': '2026-07-05',
    'status': 'ABSENT',
  });

  // 5. Seed Homeworks (Key: studentId_date)
  final homeworks = [
    {'student_id': 1, 'title': '쎈 수학 C단계 풀이', 'date': '2026-07-07', 'status': 'COMPLETED', 'memo': ''},
    {'student_id': 2, 'title': '쎈 수학 C단계 풀이', 'date': '2026-07-07', 'status': 'INCOMPLETE', 'memo': '아예 안 해옴'},
    {'student_id': 3, 'title': '쎈 수학 C단계 풀이', 'date': '2026-07-07', 'status': 'COMPLETED', 'memo': ''},
    {'student_id': 4, 'title': '쎈 수학 C단계 풀이', 'date': '2026-07-07', 'status': 'PARTIAL', 'memo': '절반만 완료'},
    {'student_id': 5, 'title': '쎈 수학 C단계 풀이', 'date': '2026-07-07', 'status': 'INCOMPLETE', 'memo': '워크북 미작성'},
  ];

  for (final hw in homeworks) {
    await db.homeworksBox.put('${hw['student_id']}_${hw['date']}', hw);
  }

  // 6. Seed Schedules
  final schedules = [
    {
      'id': 1,
      'title': '7월 전국 수학 학력평가',
      'date': '2026-07-15',
      'type': 'EXAM',
      'memo': '오전 10시 시행',
    },
    {
      'id': 2,
      'title': '여름 방학 특강 휴원',
      'date': '2026-07-30',
      'type': 'LEAVE',
      'memo': '정규 수업 없음',
    },
    {
      'id': 3,
      'title': '학부모 초청 정기 상담회',
      'date': '2026-07-20',
      'type': 'CONSULT',
      'memo': '개별 시간 사전 예약',
    },
  ];

  for (final s in schedules) {
    await db.schedulesBox.put(s['id'], s);
  }

  await db.settingsBox.put('database_seeded', true);
}
