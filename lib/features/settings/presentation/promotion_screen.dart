import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../student/presentation/providers/student_list_provider.dart';
import '../../student/domain/models/student_stats.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';

class PromotionScreen extends ConsumerStatefulWidget {
  const PromotionScreen({super.key});

  @override
  ConsumerState<PromotionScreen> createState() => _PromotionScreenState();
}

class _PromotionScreenState extends ConsumerState<PromotionScreen> {
  String _graduationOption = 'inactive'; // 'inactive' or 'high_school'

  String _formatGradeLabel(int grade) {
    if (grade >= 1 && grade <= 6) {
      return '초등학교 $grade학년';
    } else if (grade >= 7 && grade <= 9) {
      return '중학교 ${grade - 6}학년';
    } else if (grade == 10) {
      return '고등학교 1학년';
    }
    return '$grade학년';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsAsync = ref.watch(studentsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('학년 일괄 진급'),
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return const Center(
              child: Text('진급을 진행할 활성 상태의 학생이 없습니다.'),
            );
          }

          return SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Feature Description Card
                        MathCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                                  const SizedBox(width: 8),
                                  Text(
                                    '안내사항',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '새 학년을 맞아 모든 학생들의 학년을 일괄적으로 한 단계씩 상승시킵니다.\n이 작업은 학생 정보의 학년(Grade) 필드만 수정하며, 기존의 출결 기록, 과제 내역, 시험 성적, 상담 기록 등의 과거 데이터는 변경하지 않고 안전하게 보관합니다.',
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 2. Graduation Handling Option Card
                        MathCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '중학교 3학년 (최고 학년) 처리 설정',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              RadioListTile<String>(
                                title: const Text('졸업 / 관리 종료'),
                                subtitle: const Text('비활성화 처리하여 목록에서 숨기고 기록을 보관합니다.'),
                                value: 'inactive',
                                groupValue: _graduationOption,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _graduationOption = val;
                                    });
                                  }
                                },
                              ),
                              RadioListTile<String>(
                                title: const Text('고등학교 1학년으로 진급'),
                                subtitle: const Text('학년 값을 10(고1)으로 변경하여 학원에 유지합니다.'),
                                value: 'high_school',
                                groupValue: _graduationOption,
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _graduationOption = val;
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. Preview Section
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '진급 대상자 미리보기',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '총 ${students.length}명',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),

                        // List of students showing before/after grade
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: students.length,
                          itemBuilder: (context, index) {
                            final student = students[index];
                            final currentGradeLabel = _formatGradeLabel(student.grade);
                            String nextGradeLabel;

                            if (student.grade < 9) {
                              nextGradeLabel = _formatGradeLabel(student.grade + 1);
                            } else {
                              nextGradeLabel = _graduationOption == 'inactive' ? '졸업/관리 종료' : '고등학교 1학년';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                                  child: Text(
                                    student.name.substring(0, 1),
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  student.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  student.school,
                                  style: theme.textTheme.bodySmall,
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      currentGradeLabel,
                                      style: const TextStyle(color: Colors.grey),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                                      child: Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                                    ),
                                    Text(
                                      nextGradeLabel,
                                      style: TextStyle(
                                        color: nextGradeLabel == '졸업/관리 종료'
                                            ? Colors.red
                                            : theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // 4. Apply Button Section
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => _confirmAndApplyPromotion(context, students),
                      child: const Text(
                        '진급 적용하기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const MathLoader(message: '학생 목록을 불러오는 중...'),
        error: (err, stack) => Center(child: Text('데이터 로드 실패: $err')),
      ),
    );
  }

  void _confirmAndApplyPromotion(BuildContext context, List<StudentStats> students) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('학년 일괄 진급 확인'),
          content: Text('총 ${students.length}명의 학생이 진급됩니다. 진행하시겠습니까?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close confirm dialog
                _applyPromotion(context, students);
              },
              child: const Text('진급 진행', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _applyPromotion(BuildContext context, List<StudentStats> students) async {
    final messenger = ScaffoldMessenger.of(context);
    
    // Show Loading Dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const MathLoader(message: '일괄 진급 처리를 진행 중입니다...'),
    );

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final student in students) {
        final docRef = FirebaseFirestore.instance.collection('students').doc(student.id);
        if (student.grade < 9) {
          batch.update(docRef, {
            'grade': student.grade + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else if (student.grade == 9) {
          if (_graduationOption == 'inactive') {
            batch.update(docRef, {
              'isActive': false,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            batch.update(docRef, {
              'grade': 10,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }
      await batch.commit();

      // Invalidate stream
      ref.invalidate(studentsStreamProvider);

      // Pop loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }

      // Show Success Dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('진급 완료'),
              content: Text('총 ${students.length}명의 학생이 성공적으로 진급되었습니다.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close success dialog
                    Navigator.pop(context); // Go back to Settings screen
                  },
                  child: const Text('확인', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      // Pop loading dialog
      if (context.mounted) {
        Navigator.pop(context);
      }
      
      messenger.showSnackBar(
        SnackBar(content: Text('진급 진행 중 오류가 발생했습니다: $e')),
      );
    }
  }
}
