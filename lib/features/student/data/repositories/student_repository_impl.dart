import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/student_stats.dart';
import '../../domain/models/student_detail_data.dart';
import '../../domain/repositories/student_repository.dart';
import '../../../test/domain/models/exam_group_models.dart';
import '../../../test/domain/models/exam_models.dart';
import '../../../../core/utils/student_evaluator.dart';

class StudentRepositoryImpl implements StudentRepository {
  StudentRepositoryImpl();

  @override
  Stream<List<StudentStats>> watchStudents({String? search, int? gradeFilter}) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final examRecordsStream = FirebaseFirestore.instance.collection('exam_records').snapshots();
    final attendancesStream = FirebaseFirestore.instance.collection('attendances').snapshots();
    final homeworksStream = FirebaseFirestore.instance.collection('homeworks').snapshots();
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();

    return Rx.combineLatest5<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<StudentStats>>(
      studentsStream,
      examRecordsStream,
      attendancesStream,
      homeworksStream,
      examsStream,
      (studentsSnap, recordsSnap, attendancesSnap, homeworksSnap, examsSnap) {
        final List<StudentStats> list = [];

        final allStudents = studentsSnap.docs;
        final Map<String, int> examMaxScores = {};
        for (final doc in examsSnap.docs) {
          final data = doc.data();
          final maxScore = data['maxPossibleScore'] as int? ?? 100;
          examMaxScores[doc.id] = maxScore;
        }
        final rawRecords = recordsSnap.docs.map((doc) => doc.data()).toList();
        final allRecords = ExamParticipantCalculator.cleanRawRecords(rawRecords, examMaxScores: examMaxScores);
        final allAttendances = attendancesSnap.docs.map((doc) => doc.data()).toList();
        final allHomeworks = homeworksSnap.docs.map((doc) => doc.data()).toList();
        final allExams = examsSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();

        for (final doc in allStudents) {
          final s = doc.data();
          final String id = doc.id; // Document ID is the String identifier
          final name = s['name'] as String? ?? '';
          final photoPath = s['photoPath'] as String?;
          final school = s['school'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';
          final parentPhone = s['parentPhone'] as String? ?? '';
          
          final regTimestamp = s['registrationDate'] as Timestamp?;
          final registrationDate = regTimestamp != null 
              ? DateFormat('yyyy-MM-dd').format(regTimestamp.toDate()) 
              : '';
              
          final memo = s['memo'] as String?;
          final isActive = s['isActive'] as bool? ?? true;

          // Apply soft delete filter
          if (!isActive) continue;

          // Apply search & grade filters
          if (search != null && search.trim().isNotEmpty) {
            if (!name.contains(search) && !school.contains(search) && !className.contains(search)) {
              continue;
            }
          }
          if (gradeFilter != null) {
            if (grade != gradeFilter) {
              continue;
            }
          }

          // Calculate stats
          // 1. Exam scores (chronological order)
          final studentScores = allRecords
              .where((r) => r['studentId'] == id)
              .toList();
          studentScores.sort((a, b) => (a['examId'] as String).compareTo(b['examId'] as String));
          
          final percentagesList = studentScores.map((r) {
            final examId = r['examId'] as String;
            final exam = allExams.firstWhere((e) => e['docId'] == examId, orElse: () => <String, dynamic>{});
            final maxScore = exam['maxPossibleScore'] as int? ?? 100;
            return (r['score'] as int) / maxScore * 100;
          }).toList();
          
          final double avgScore = percentagesList.isNotEmpty
              ? percentagesList.reduce((a, b) => a + b) / percentagesList.length
              : 0.0;

          // 2. Attendance rate
          final studentAttsAll = allAttendances.where((a) => a['studentId'] == id).toList();
          final Map<String, String> uniqueAtts = {};
          for (final a in studentAttsAll) {
            final dateTs = a['date'] as Timestamp?;
            if (dateTs == null) continue;
            final dateStr = DateFormat('yyyy-MM-dd').format(dateTs.toDate());
            uniqueAtts[dateStr] = a['status'] as String? ?? 'ATTENDANCE';
          }
          int presentCount = 0;
          int lateCount = 0;
          int earlyLeaveCount = 0;
          for (final status in uniqueAtts.values) {
            if (status == 'ATTENDANCE') presentCount++;
            if (status == 'LATE') lateCount++;
            if (status == 'EARLY_LEAVE') earlyLeaveCount++;
          }
          final double attendanceRate = uniqueAtts.isNotEmpty
              ? (presentCount + lateCount + earlyLeaveCount) / uniqueAtts.length
              : 1.0;

          // 3. Homework rate
          final studentHws = allHomeworks.where((h) => h['studentId'] == id).toList();
          int completedCount = 0;
          int partialCount = 0;
          for (final hw in studentHws) {
            final status = hw['status'] as String;
            if (status == 'COMPLETED') completedCount++;
            if (status == 'PARTIAL') partialCount++;
          }
          final double homeworkRate = studentHws.isNotEmpty
              ? (completedCount + (partialCount * 0.5)) / studentHws.length
              : 1.0;

          // 4. Growth indicator
          final growthRes = StudentGrowthCalculator.calculate(
            studentRecords: studentScores,
            allExams: allExams,
          );
          final double growthRate = growthRes['rate'] as double;
          final String trendText = growthRes['trend'] as String;
          String growthTrend = '유지';
          if (trendText == '상승 중') {
            growthTrend = '▲ 상승 중';
          } else if (trendText == '하락 중') {
            growthTrend = '▼ 하락 중';
          }

          // Calculate riskScore
          final List<Map<String, dynamic>> attLogsForRisk = [];
          for (final a in studentAttsAll) {
            final dateTs = a['date'] as Timestamp?;
            if (dateTs == null) continue;
            attLogsForRisk.add({
              'date': dateTs.toDate(),
              'status': a['status'] as String? ?? 'ATTENDANCE',
            });
          }

          final List<Map<String, dynamic>> hwLogsForRisk = [];
          for (final h in studentHws) {
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
              'maxPossibleScore': examDoc['maxPossibleScore'] as int? ?? 100,
            });
          }

          final DateTime? regDate = regTimestamp?.toDate();
          final riskRes = StudentRiskCalculator.calculate(
            evaluationDate: DateTime.now(),
            registrationDate: regDate,
            attendanceLogs: attLogsForRisk,
            homeworkLogs: hwLogsForRisk,
            examLogs: examLogsForRisk,
          );
          final riskScore = riskRes.score;

          list.add(StudentStats(
            id: id,
            name: name,
            photoPath: photoPath,
            school: school,
            grade: grade,
            className: className,
            parentPhone: parentPhone,
            registrationDate: registrationDate,
            memo: memo,
            isActive: isActive,
            averageScore: avgScore,
            growthRate: growthRate,
            growthTrend: growthTrend,
            attendanceRate: attendanceRate,
            homeworkCompletionRate: homeworkRate,
            riskScore: riskScore,
          ));
        }

        // Sort by grade, then Korean alphabetical name order
        list.sort((a, b) {
          final gradeCompare = a.grade.compareTo(b.grade);
          if (gradeCompare != 0) return gradeCompare;
          return a.name.compareTo(b.name);
        });

        return list;
      },
    );
  }

  @override
  Stream<StudentDetailData> watchStudentDetail(String studentId) {
    final studentStream = FirebaseFirestore.instance.collection('students').doc(studentId).snapshots();
    final examRecordsStream = FirebaseFirestore.instance
        .collection('exam_records')
        .where('studentId', isEqualTo: studentId)
        .snapshots();
    final attendancesStream = FirebaseFirestore.instance
        .collection('attendances')
        .where('studentId', isEqualTo: studentId)
        .snapshots();
    final homeworksStream = FirebaseFirestore.instance
        .collection('homeworks')
        .where('studentId', isEqualTo: studentId)
        .snapshots();
    final examsStream = FirebaseFirestore.instance.collection('exams').snapshots();
    final schedulesStream = FirebaseFirestore.instance
        .collection('schedules')
        .where('type', isEqualTo: 'CONSULT')
        .snapshots();
    final examGroupsStream = FirebaseFirestore.instance.collection('exam_groups').snapshots();

    return Rx.combineLatest7<
        DocumentSnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        StudentDetailData>(
      studentStream,
      examRecordsStream,
      attendancesStream,
      homeworksStream,
      examsStream,
      schedulesStream,
      examGroupsStream,
      (studentSnap, recordsSnap, attendancesSnap, homeworksSnap, examsSnap, schedulesSnap, groupsSnap) {
        if (!studentSnap.exists) {
          throw Exception('Student not found: $studentId');
        }
        final sVal = studentSnap.data()!;

        final name = sVal['name'] as String? ?? '';
        final photoPath = sVal['photoPath'] as String?;
        final school = sVal['school'] as String? ?? '';
        final grade = sVal['grade'] as int? ?? 1;
        final className = sVal['className'] as String? ?? '';
        final parentPhone = sVal['parentPhone'] as String? ?? '';
        
        final regTimestamp = sVal['registrationDate'] as Timestamp?;
        final registrationDate = regTimestamp != null 
            ? DateFormat('yyyy-MM-dd').format(regTimestamp.toDate()) 
            : '';
            
        final memo = sVal['memo'] as String?;
        final isActive = sVal['isActive'] as bool? ?? true;

        final allExams = examsSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();
        final Map<String, int> examMaxScores = {};
        for (final doc in examsSnap.docs) {
          final data = doc.data();
          final maxScore = data['maxPossibleScore'] as int? ?? 100;
          examMaxScores[doc.id] = maxScore;
        }
        final rawRecords = recordsSnap.docs.map((doc) => doc.data()).toList();
        final allRecords = ExamParticipantCalculator.cleanRawRecords(rawRecords, examMaxScores: examMaxScores);
        final allGroups = groupsSnap.docs
            .map((doc) => ExamGroup.fromMap(doc.id, doc.data()))
            .toList();
        final allAttendances = attendancesSnap.docs.map((doc) {
          final data = doc.data();
          final sId = data['studentId'] as String?;
          final dateTs = data['date'] as Timestamp?;
          if (sId != null && dateTs != null) {
            final dateStr = DateFormat('yyyy-MM-dd').format(dateTs.toDate());
            final expectedId = '${sId}_${dateStr.replaceAll('-', '')}';
            if (doc.id != expectedId) {
              _migrateLegacyDoc(doc, expectedId);
            }
          }
          return data;
        }).toList();
        final allHomeworks = homeworksSnap.docs.map((doc) => doc.data()).toList();
        final allSchedules = schedulesSnap.docs.map((doc) => doc.data()..['docId'] = doc.id).toList();

        // 1. Fetch exams history
        final studentRecords = allRecords.where((r) => r['studentId'] == studentId).toList();
        final List<StudentExamLog> examLogs = [];
        for (final rec in studentRecords) {
          final examId = rec['examId'] as String;
          final score = rec['score'] as int;
          final exam = allExams.firstWhere((e) => e['docId'] == examId, orElse: () => <String, dynamic>{});
          if (exam.isNotEmpty) {
            final examDateTs = exam['date'] as Timestamp?;
            final examGroupId = exam['examGroupId'] as String? ?? '';
            final group = allGroups.firstWhere(
              (g) => g.id == examGroupId,
              orElse: () => const ExamGroup(id: '', name: '미지정', colorHex: '#9E9E9E', orderIndex: 9999),
            );
            examLogs.add(StudentExamLog(
              title: exam['title'] as String? ?? '',
              date: examDateTs != null ? DateFormat('yyyy-MM-dd').format(examDateTs.toDate()) : '',
              score: score,
              examGroupId: examGroupId,
              examGroupName: group.name,
              examGroupColorHex: group.colorHex,
              maxPossibleScore: exam['maxPossibleScore'] as int? ?? 100,
            ));
          }
        }
        examLogs.sort((a, b) => b.date.compareTo(a.date));

        // 2. Fetch attendance logs
        final studentAtts = allAttendances.where((a) => a['studentId'] == studentId).toList();
        studentAtts.sort((a, b) {
          final aUp = a['updatedAt'] as Timestamp?;
          final bUp = b['updatedAt'] as Timestamp?;
          if (aUp == null && bUp == null) return 0;
          if (aUp == null) return -1;
          if (bUp == null) return 1;
          return aUp.compareTo(bUp);
        });
        final Map<String, StudentAttendanceLog> attendanceMap = {};
        for (final a in studentAtts) {
          final attDateTs = a['date'] as Timestamp?;
          if (attDateTs == null) continue;
          final dateStr = DateFormat('yyyy-MM-dd').format(attDateTs.toDate());
          attendanceMap[dateStr] = StudentAttendanceLog(
            date: dateStr,
            status: a['status'] as String? ?? 'ATTENDANCE',
          );
        }
        final List<StudentAttendanceLog> attendanceLogs = attendanceMap.values.toList();
        attendanceLogs.sort((a, b) => b.date.compareTo(a.date));

        // 3. Fetch homework logs
        final studentHws = allHomeworks.where((h) => h['studentId'] == studentId).toList();
        final List<StudentHomeworkLog> homeworkLogs = studentHws.map<StudentHomeworkLog>((h) {
          final hwDateTs = h['date'] as Timestamp?;
          return StudentHomeworkLog(
            title: h['title'] as String? ?? '',
            date: hwDateTs != null ? DateFormat('yyyy-MM-dd').format(hwDateTs.toDate()) : '',
            status: h['status'] as String? ?? 'INCOMPLETE',
            memo: h['memo'] as String?,
          );
        }).toList();
        homeworkLogs.sort((a, b) => b.date.compareTo(a.date));

        // 4. Fetch counseling notes
        final List<StudentConsultingLog> consultingLogs = [];
        for (final s in allSchedules) {
          if (s['type'] == 'CONSULT' && (s['studentId'] == studentId || s['studentId'] == null)) {
            final sDateTs = s['date'] as Timestamp?;
            consultingLogs.add(StudentConsultingLog(
              id: s['docId'] as String?,
              title: s['title'] as String? ?? '',
              date: sDateTs != null ? DateFormat('yyyy-MM-dd').format(sDateTs.toDate()) : '',
              memo: s['memo'] ?? '정기 상담 기록',
            ));
          }
        }
        if (memo != null && memo.trim().isNotEmpty) {
          consultingLogs.add(StudentConsultingLog(
            title: '학원 등록 상담',
            date: registrationDate,
            memo: memo,
          ));
        }
        consultingLogs.sort((a, b) => b.date.compareTo(a.date));

        // 5. Evaluate AI
        final List<Map<String, dynamic>> attLogsForRisk = [];
        for (final a in studentAtts) {
          final dateTs = a['date'] as Timestamp?;
          if (dateTs == null) continue;
          attLogsForRisk.add({
            'date': dateTs.toDate(),
            'status': a['status'] as String? ?? 'ATTENDANCE',
          });
        }

        final List<Map<String, dynamic>> hwLogsForRisk = [];
        for (final h in studentHws) {
          final dateTs = h['date'] as Timestamp?;
          if (dateTs == null) continue;
          hwLogsForRisk.add({
            'date': dateTs.toDate(),
            'status': h['status'] as String? ?? 'INCOMPLETE',
          });
        }

        final List<Map<String, dynamic>> examLogsForRisk = [];
        for (final r in studentRecords) {
          final examId = r['examId'] as String?;
          final score = r['score'] as int? ?? 0;
          final examDoc = allExams.firstWhere((e) => e['docId'] == examId, orElse: () => <String, dynamic>{});
          final examDateTs = examDoc['date'] as Timestamp?;
          if (examDateTs == null) continue;
          examLogsForRisk.add({
            'date': examDateTs.toDate(),
            'score': score,
            'maxPossibleScore': examDoc['maxPossibleScore'] as int? ?? 100,
          });
        }

        final DateTime? regDate = regTimestamp?.toDate();
        final riskRes = StudentRiskCalculator.calculate(
          evaluationDate: DateTime.now(),
          registrationDate: regDate,
          attendanceLogs: attLogsForRisk,
          homeworkLogs: hwLogsForRisk,
          examLogs: examLogsForRisk,
        );
        final Map<String, StudentComparisonResult> groupComparisons = {};
        final uniqueGroupIds = examLogs.map((e) => e.examGroupId).where((id) => id.isNotEmpty).toSet();
        for (final gId in uniqueGroupIds) {
          final comp = ExamGroupComparisonCalculator.calculate(
            studentId: studentId,
            examGroupId: gId,
            rawRecords: rawRecords,
            allExams: allExams,
          );
          if (comp != null) {
            groupComparisons[gId] = comp;
          }
        }

        final percentagesList = examLogs.reversed.map((e) => (e.score / e.maxPossibleScore) * 100).toList();
        final ai = StudentEvaluator.evaluateWithRisk(
          scorePercentages: percentagesList,
          attendanceStatuses: attendanceLogs.reversed.map((a) => a.status).toList(),
          homeworkStatuses: homeworkLogs.reversed.map((h) => h.status).toList(),
          riskScore: riskRes.score,
          triggers: riskRes.triggers,
        );

        int presentCount = 0;
        int lateCount = 0;
        int earlyLeaveCount = 0;
        for (final log in attendanceLogs) {
          final status = log.status;
          if (status == 'ATTENDANCE') presentCount++;
          if (status == 'LATE') lateCount++;
          if (status == 'EARLY_LEAVE') earlyLeaveCount++;
        }
        final double attendanceRate = attendanceLogs.isNotEmpty
            ? (presentCount + lateCount + earlyLeaveCount) / attendanceLogs.length
            : 1.0;

        int completedCount = 0;
        int partialCount = 0;
        for (final hw in studentHws) {
          final status = hw['status'] as String;
          if (status == 'COMPLETED') completedCount++;
          if (status == 'PARTIAL') partialCount++;
        }
        final double homeworkRate = studentHws.isNotEmpty
            ? (completedCount + (partialCount * 0.5)) / studentHws.length
            : 1.0;

        final growthRes = StudentGrowthCalculator.calculate(
          studentRecords: studentRecords,
          allExams: allExams,
        );
        final growthRate = growthRes['rate'] as double;
        final trendText = growthRes['trend'] as String;
        String growthTrend = '유지';
        if (trendText == '상승 중') {
          growthTrend = '▲ 상승 중';
        } else if (trendText == '하락 중') {
          growthTrend = '▼ 하락 중';
        }

        final studentStats = StudentStats(
          id: studentId,
          name: name,
          photoPath: photoPath,
          school: school,
          grade: grade,
          className: className,
          parentPhone: parentPhone,
          registrationDate: registrationDate,
          memo: memo,
          isActive: isActive,
          averageScore: percentagesList.isNotEmpty ? percentagesList.reduce((a, b) => a + b) / percentagesList.length : 0.0,
          growthRate: growthRate,
          growthTrend: growthTrend,
          attendanceRate: attendanceRate,
          homeworkCompletionRate: homeworkRate,
          riskScore: riskRes.score,
        );

        return StudentDetailData(
          stats: studentStats,
          examLogs: examLogs,
          attendanceLogs: attendanceLogs,
          homeworkLogs: homeworkLogs,
          consultingLogs: consultingLogs,
          aiEvaluation: ai,
          groupComparisons: groupComparisons,
        );
      },
    );
  }

  @override
  Future<String> addStudent({
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  }) async {
    final parsedRegDate = DateTime.tryParse(registrationDate) ?? DateTime.now();
    final regTimestamp = Timestamp.fromDate(DateTime(parsedRegDate.year, parsedRegDate.month, parsedRegDate.day));

    final docRef = await FirebaseFirestore.instance.collection('students').add({
      'name': name,
      'photoPath': photoPath,
      'school': school,
      'grade': grade,
      'className': className,
      'parentPhone': parentPhone,
      'registrationDate': regTimestamp,
      'memo': memo,
      'isActive': isActive,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return docRef.id;
  }

  @override
  Future<void> updateStudent({
    required String id,
    required String name,
    String? photoPath,
    required String school,
    required int grade,
    required String className,
    required String parentPhone,
    required String registrationDate,
    String? memo,
    required bool isActive,
  }) async {
    final parsedRegDate = DateTime.tryParse(registrationDate) ?? DateTime.now();
    final regTimestamp = Timestamp.fromDate(DateTime(parsedRegDate.year, parsedRegDate.month, parsedRegDate.day));

    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'name': name,
      'photoPath': photoPath,
      'school': school,
      'grade': grade,
      'className': className,
      'parentPhone': parentPhone,
      'registrationDate': regTimestamp,
      'memo': memo,
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteStudent(String id) async {
    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStudentMemo(String id, String memo) async {
    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'memo': memo,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
  @override
  Future<StudentBackup> deleteStudentWithBackup(String id) async {
    final doc = await FirebaseFirestore.instance.collection('students').doc(id).get();
    if (!doc.exists) {
      throw Exception('학생을 찾을 수 없습니다.');
    }
    final map = doc.data()!;
    map['docId'] = doc.id;

    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return StudentBackup(
      student: map,
      attendances: [],
      homeworks: [],
      examRecords: [],
    );
  }

  @override
  Future<void> restoreStudentBackup(StudentBackup backup) async {
    final id = backup.student['docId'] as String;
    await FirebaseFirestore.instance.collection('students').doc(id).update({
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  void _migrateLegacyDoc(DocumentSnapshot doc, String expectedId) {
    final docRef = FirebaseFirestore.instance.collection('attendances').doc(doc.id);
    final newDocRef = FirebaseFirestore.instance.collection('attendances').doc(expectedId);
    
    FirebaseFirestore.instance.runTransaction((transaction) async {
      final newDocSnap = await transaction.get(newDocRef);
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return;
      
      if (!newDocSnap.exists) {
        transaction.set(newDocRef, {
          ...data,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        final legacyUp = data['updatedAt'] as Timestamp?;
        final newUp = newDocSnap.data()?['updatedAt'] as Timestamp?;
        bool useLegacy = true;
        if (legacyUp != null && newUp != null) {
          useLegacy = legacyUp.compareTo(newUp) > 0;
        }
        if (useLegacy) {
          transaction.update(newDocRef, {
            ...data,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
      transaction.delete(docRef);
    }).catchError((_) {});
  }
}
