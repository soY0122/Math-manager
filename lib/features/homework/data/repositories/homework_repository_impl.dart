import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/models/student_homework_item.dart';
import '../../domain/repositories/homework_repository.dart';

class HomeworkRepositoryImpl implements HomeworkRepository {
  HomeworkRepositoryImpl();



  Timestamp _parseDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr) ?? DateTime.now();
    return Timestamp.fromDate(DateTime(parsed.year, parsed.month, parsed.day));
  }

  @override
  Stream<List<StudentHomeworkItem>> watchHomeworkForDate(String date, {int? gradeFilter}) {
    final studentsStream = FirebaseFirestore.instance.collection('students').snapshots();
    final homeworksStream = FirebaseFirestore.instance.collection('homeworks').snapshots();

    return Rx.combineLatest2<
        QuerySnapshot<Map<String, dynamic>>,
        QuerySnapshot<Map<String, dynamic>>,
        List<StudentHomeworkItem>>(
      studentsStream,
      homeworksStream,
      (studentsSnap, homeworksSnap) {
        final List<StudentHomeworkItem> list = [];

        final allStudents = studentsSnap.docs;
        final allHomeworks = homeworksSnap.docs;

        var activeStudents = allStudents.where((doc) => doc.data()['isActive'] == true).toList();
        if (gradeFilter != null) {
          activeStudents = activeStudents.where((doc) => doc.data()['grade'] == gradeFilter).toList();
        }
        activeStudents.sort((a, b) => (a.data()['name'] as String).compareTo(b.data()['name'] as String));

        final targetTimestamp = _parseDate(date);

        for (final doc in activeStudents) {
          final s = doc.data();
          final studentId = doc.id; // String ID
          final studentName = s['name'] as String? ?? '';
          final school = s['school'] as String? ?? '';
          final grade = s['grade'] as int? ?? 1;
          final className = s['className'] as String? ?? '';

          final studentHwRecords = allHomeworks.where((hDoc) {
            final h = hDoc.data();
            final hStudentId = h['studentId'] as String;
            final hDateTs = h['date'] as Timestamp?;
            return hStudentId == studentId && hDateTs != null && hDateTs.seconds == targetTimestamp.seconds;
          }).toList();

          if (studentHwRecords.isEmpty) {
            final dateHws = allHomeworks.where((hDoc) {
              final h = hDoc.data();
              final hDateTs = h['date'] as Timestamp?;
              return hDateTs != null && hDateTs.seconds == targetTimestamp.seconds;
            }).toList();

            final uniqueTitles = dateHws.map((hDoc) => hDoc.data()['title'] as String).toSet().toList();

            for (final title in uniqueTitles) {
              final isTargetGrade = dateHws.any((hDoc) {
                final h = hDoc.data();
                if (h['title'] == title) {
                  final otherStudentId = h['studentId'] as String;
                  final otherStudentDoc = allStudents.where((stDoc) => stDoc.id == otherStudentId).firstOrNull;
                  if (otherStudentDoc != null && (otherStudentDoc.data() as Map<String, dynamic>)['grade'] == grade) {
                    return true;
                  }
                }
                return false;
              });

              if (isTargetGrade || gradeFilter == null) {
                list.add(StudentHomeworkItem(
                  studentId: studentId,
                  studentName: studentName,
                  school: school,
                  grade: grade,
                  className: className,
                  homeworkId: null,
                  title: title,
                  date: date,
                  status: 'INCOMPLETE',
                  memo: '',
                ));
              }
            }
          } else {
            for (final hwDoc in studentHwRecords) {
              final hw = hwDoc.data();
              list.add(StudentHomeworkItem(
                studentId: studentId,
                studentName: studentName,
                school: school,
                grade: grade,
                className: className,
                homeworkId: hwDoc.id,
                title: hw['title'] as String? ?? '',
                date: date,
                status: hw['status'] as String? ?? 'INCOMPLETE',
                memo: hw['memo'] as String? ?? '',
              ));
            }
          }
        }

        return list;
      },
    );
  }

  @override
  Future<void> updateHomeworkStatus({
    required String studentId,
    required String date,
    required String status,
    required String title,
    String? memo,
    String? homeworkId,
  }) async {
    final targetTimestamp = _parseDate(date);
    if (homeworkId != null) {
      await FirebaseFirestore.instance.collection('homeworks').doc(homeworkId).update({
        'status': status,
        'memo': memo ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final query = await FirebaseFirestore.instance
          .collection('homeworks')
          .where('studentId', isEqualTo: studentId)
          .where('title', isEqualTo: title)
          .where('date', isEqualTo: targetTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        for (final doc in query.docs) {
          await doc.reference.update({
            'status': status,
            'memo': memo ?? '',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('homeworks').add({
          'studentId': studentId,
          'date': targetTimestamp,
          'status': status,
          'title': title,
          'memo': memo ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> markAllAsCompleted(String date, String title, {int? gradeFilter}) async {
    final targetTimestamp = _parseDate(date);
    final studentsSnap = await FirebaseFirestore.instance.collection('students').get();
    var targets = studentsSnap.docs.where((doc) => doc.data()['isActive'] == true).toList();
    if (gradeFilter != null) {
      targets = targets.where((doc) => doc.data()['grade'] == gradeFilter).toList();
    }

    for (final doc in targets) {
      final studentId = doc.id;
      final query = await FirebaseFirestore.instance
          .collection('homeworks')
          .where('studentId', isEqualTo: studentId)
          .where('title', isEqualTo: title)
          .where('date', isEqualTo: targetTimestamp)
          .get();

      if (query.docs.isNotEmpty) {
        for (final hwDoc in query.docs) {
          await hwDoc.reference.update({
            'status': 'COMPLETED',
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('homeworks').add({
          'studentId': studentId,
          'date': targetTimestamp,
          'status': 'COMPLETED',
          'title': title,
          'memo': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> addHomeworkAssignment({
    required String date,
    required String title,
    required int? gradeFilter,
  }) async {
    final targetTimestamp = _parseDate(date);
    final studentsSnap = await FirebaseFirestore.instance.collection('students').get();
    var targets = studentsSnap.docs.where((doc) => doc.data()['isActive'] == true).toList();
    if (gradeFilter != null) {
      targets = targets.where((doc) => doc.data()['grade'] == gradeFilter).toList();
    }

    for (final doc in targets) {
      final studentId = doc.id;
      final query = await FirebaseFirestore.instance
          .collection('homeworks')
          .where('studentId', isEqualTo: studentId)
          .where('title', isEqualTo: title)
          .where('date', isEqualTo: targetTimestamp)
          .get();

      if (query.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('homeworks').add({
          'studentId': studentId,
          'date': targetTimestamp,
          'title': title,
          'status': 'INCOMPLETE',
          'memo': '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  @override
  Future<void> deleteHomeworkAssignment({
    required String date,
    required String title,
    required int? gradeFilter,
  }) async {
    final targetTimestamp = _parseDate(date);

    final query = await FirebaseFirestore.instance
        .collection('homeworks')
        .where('title', isEqualTo: title)
        .where('date', isEqualTo: targetTimestamp)
        .get();

    for (final doc in query.docs) {
      if (gradeFilter != null) {
        final studentId = doc.data()['studentId'] as String;
        final stDoc = await FirebaseFirestore.instance.collection('students').doc(studentId).get();
        if (stDoc.exists && stDoc.data()?['grade'] == gradeFilter) {
          await doc.reference.delete();
        }
      } else {
        await doc.reference.delete();
      }
    }
  }
}
