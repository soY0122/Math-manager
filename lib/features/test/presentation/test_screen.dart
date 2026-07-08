import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/exam_providers.dart';
import '../domain/models/exam_models.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';
import '../../../core/providers/global_providers.dart';
import 'package:fl_chart/fl_chart.dart';

final graphGradeFilterProvider = StateProvider<int>((ref) => 3);

class TestScreen extends ConsumerWidget {
  const TestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(examsListStreamProvider);
    final theme = Theme.of(context);
    final globalGrade = ref.watch(globalGradeFilterProvider);
    final int selectedGraphGrade = globalGrade ?? ref.watch(graphGradeFilterProvider);
    final sortNewest = ref.watch(examSortNewestProvider);

    final gradeChoices = [
      _GradeChoice(label: '초1', value: 1),
      _GradeChoice(label: '초2', value: 2),
      _GradeChoice(label: '초3', value: 3),
      _GradeChoice(label: '초4', value: 4),
      _GradeChoice(label: '초5', value: 5),
      _GradeChoice(label: '초6', value: 6),
      _GradeChoice(label: '중1', value: 7),
      _GradeChoice(label: '중2', value: 8),
      _GradeChoice(label: '중3', value: 9),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('성적 관리 (시험)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add_outlined),
            onPressed: () => context.push('/grades/add-exam'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: examsAsync.when(
        data: (exams) {
          // Filter exams for the selected graph grade, sorted chronologically ascending
          final graphExams = exams
              .where((e) => e.grade == selectedGraphGrade)
              .toList();
          graphExams.sort((a, b) => a.date.compareTo(b.date)); // Chronological ascending for line chart

          final List<FlSpot> spots = [];
          for (int i = 0; i < graphExams.length; i++) {
            spots.add(FlSpot(i.toDouble(), graphExams[i].averageScore));
          }

          // Build listExams for the list view below the graph
          final listExams = List<ExamOverview>.from(graphExams);
          if (sortNewest) {
            listExams.sort((a, b) => b.date.compareTo(a.date));
          } else {
            listExams.sort((a, b) => a.date.compareTo(b.date));
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Graph Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Text(
                      '학년별 시험 평균 추이',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Grade Selector ChoiceChips for Graph - ONLY show if global filter is "전체" (null)
                  if (globalGrade == null) ...[
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: gradeChoices.length,
                        itemBuilder: (context, index) {
                          final choice = gradeChoices[index];
                          final isSelected = selectedGraphGrade == choice.value;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(choice.label),
                              selected: isSelected,
                              onSelected: (selected) {
                                if (selected) {
                                  ref.read(graphGradeFilterProvider.notifier).state = choice.value;
                                }
                              },
                              selectedColor: theme.colorScheme.primary,
                              showCheckmark: false,
                              labelStyle: TextStyle(
                                color: isSelected ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                fontSize: 12,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Chart Card
                  if (spots.length >= 2)
                    MathCard(
                      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 12, right: 24),
                      child: SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            gridData: const FlGridData(show: false),
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (touchedSpot) => theme.colorScheme.surface.withOpacity(0.95),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((LineBarSpot touchedSpot) {
                                    final idx = touchedSpot.x.toInt();
                                    if (idx >= 0 && idx < graphExams.length) {
                                      final exam = graphExams[idx];
                                      return LineTooltipItem(
                                        '시험명: ${exam.title}\n날짜: ${exam.date}\n평균: ${exam.averageScore.toStringAsFixed(1)}점\n인원: ${exam.studentCount}명',
                                        TextStyle(
                                          color: theme.textTheme.bodyLarge?.color,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          height: 1.5,
                                        ),
                                      );
                                    }
                                    return null;
                                  }).toList();
                                },
                              ),
                            ),
                            titlesData: FlTitlesData(
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  // Automatically reduce label density if there are many exams
                                  interval: graphExams.length > 12 ? 3.0 : (graphExams.length > 6 ? 2.0 : 1.0),
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx >= 0 && idx < graphExams.length) {
                                      final dateStr = graphExams[idx].date;
                                      // Format Date: Show only short dates (MM/DD)
                                      String displayDate = dateStr;
                                      if (dateStr.length >= 10) {
                                        final parts = dateStr.split('-');
                                        if (parts.length == 3) {
                                          displayDate = '${parts[1]}/${parts[2]}';
                                        }
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6.0),
                                        child: Text(
                                          displayDate,
                                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                        ),
                                      );
                                    }
                                    return const Text('');
                                  },
                                  reservedSize: 22,
                                ),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      '${value.toInt()}점',
                                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                                    );
                                  },
                                  reservedSize: 36,
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                color: theme.colorScheme.primary,
                                barWidth: 4,
                                dotData: const FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                ),
                              ),
                            ],
                            minY: 0,
                            maxY: 100,
                          ),
                        ),
                      ),
                    )
                  else
                    MathCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          '${_formatGradeLabel(selectedGraphGrade)}학년의 시험 데이터가 2회 미만입니다.\n추이를 확인하려면 성적을 추가 등록해주세요.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),

                  // 2. Exams List Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          '시험 기록 목록',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      // Sort toggle button
                      TextButton.icon(
                        icon: Icon(sortNewest ? Icons.arrow_downward : Icons.arrow_upward, size: 16),
                        label: Text(sortNewest ? '최신순' : '과거순'),
                        onPressed: () {
                          ref.read(examSortNewestProvider.notifier).state = !sortNewest;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (listExams.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 36.0),
                      child: Center(
                        child: Text('선택한 학년에 기록된 시험이 없습니다.'),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: listExams.length,
                      itemBuilder: (context, index) {
                        final exam = listExams[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: _buildExamCard(context, ref, exam),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const MathLoader(message: '시험 정보를 불러오는 중...'),
        error: (err, stack) => Center(child: Text('데이터 조회 오류: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/grades/add-exam'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExamCard(BuildContext context, WidgetRef ref, ExamOverview exam) {
    final theme = Theme.of(context);

    return MathCard(
      onTap: () => context.push('/grades/score-input/${exam.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      exam.title,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _formatGradeLabel(exam.grade),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary, size: 20),
                    onPressed: () => _showEditDialog(context, ref, exam),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350), size: 20),
                    onPressed: () => _confirmDelete(context, ref, exam),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '시험 날짜: ${exam.date} • 참여 인원: ${exam.studentCount}명',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniIndicator(context, label: '평균 점수', value: '${exam.averageScore.toStringAsFixed(1)}점', color: theme.colorScheme.primary),
              _buildMiniIndicator(context, label: '최고 점수', value: '${exam.maxScore}점', color: const Color(0xFF4CAF50)),
              _buildMiniIndicator(context, label: '최저 점수', value: '${exam.minScore}점', color: const Color(0xFFEF5350)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniIndicator(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ExamOverview exam) {
    final titleController = TextEditingController(text: exam.title);
    final dateController = TextEditingController(text: exam.date);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('시험 정보 수정'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '시험명 *'),
                  validator: (val) => (val == null || val.trim().isEmpty) ? '시험명을 입력하세요' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: dateController,
                  decoration: const InputDecoration(
                    labelText: '시험 날짜 *',
                    hintText: 'YYYY-MM-DD',
                  ),
                  validator: (val) => (val == null || val.trim().isEmpty) ? '날짜를 입력하세요' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  await ref.read(examRepositoryProvider).updateExam(
                    exam.id,
                    titleController.text.trim(),
                    dateController.text.trim(),
                  );
                  ref.invalidate(examsListStreamProvider);
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: const Text('수정 완료'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, ExamOverview exam) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('시험 삭제'),
          content: Text('"${exam.title}" 시험을 삭제하시겠습니까?\n이 시험의 모든 학생 성적 기록이 함께 영구 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final backup = await ref.read(examRepositoryProvider).deleteExamWithBackup(exam.id);
                ref.invalidate(examsListStreamProvider);

                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('"${exam.title}" 시험이 삭제되었습니다.'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: '실행 취소',
                      onPressed: () async {
                        try {
                          messenger.hideCurrentSnackBar();
                          await ref.read(examRepositoryProvider).restoreExamBackup(backup);
                          ref.invalidate(examsListStreamProvider);
                        } catch (e) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('실행취소 중 오류가 발생했습니다.')),
                          );
                        }
                      },
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFF44336)),
              child: const Text('삭제'),
            ),
          ],
        );
      },
    );
  }

  String _formatGradeLabel(int grade) {
    if (grade >= 1 && grade <= 6) {
      return '초$grade';
    } else if (grade >= 7 && grade <= 9) {
      return '중${grade - 6}';
    }
    return '$grade학년';
  }
}

class _GradeChoice {
  final String label;
  final int value;

  _GradeChoice({required this.label, required this.value});
}
