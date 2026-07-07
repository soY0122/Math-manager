import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/homework_providers.dart';
import '../domain/models/student_homework_item.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/math_loader.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Synchronize text controller with provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleController.text = ref.read(homeworkAssignmentTitleProvider);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedDate = ref.watch(homeworkDateProvider);
    final dateStr = selectedDate.toIso8601String().split('T')[0];
    final assignmentTitle = ref.watch(homeworkAssignmentTitleProvider);
    final homeworkAsync = ref.watch(homeworkStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('과제 관리'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('전체 완료'),
            onPressed: () => _markAllAsCompleted(context, dateStr, assignmentTitle),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Date Picker & Global Assignment Title Input Card
          Container(
            padding: const EdgeInsets.all(16.0),
            color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2E3135) : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '과제 날짜: $dateStr',
                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 20),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '오늘의 과제 명칭',
                    hintText: '예: 쎈 수학 C단계 풀이 및 오답 노트',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) {
                    ref.read(homeworkAssignmentTitleProvider.notifier).state = val;
                  },
                ),
              ],
            ),
          ),

          // 2. Homework Statistics Summary
          Expanded(
            child: homeworkAsync.when(
              data: (list) {
                final total = list.length;
                final completed = list.where((item) => item.status == 'COMPLETED').length;
                final partial = list.where((item) => item.status == 'PARTIAL').length;
                final incomplete = list.where((item) => item.status == 'INCOMPLETE').length;

                final rate = total > 0 ? (completed + (partial * 0.5)) / total : 1.0;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '대상인원: $total명',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '과제 완료율: ${(rate * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildStatusLabel(context, label: '완료(○)', count: completed, color: const Color(0xFF4CAF50)),
                              const SizedBox(width: 12),
                              _buildStatusLabel(context, label: '일부(△)', count: partial, color: const Color(0xFFFF9800)),
                              const SizedBox(width: 12),
                              _buildStatusLabel(context, label: '미완료(×)', count: incomplete, color: const Color(0xFFEF5350)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Students List with completion toggles & inline notes
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                '재원 중인 학생이 없습니다.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(16.0),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildHomeworkItemCard(context, list[index], assignmentTitle),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const MathLoader(message: '과제 현황을 조회하는 중...'),
              error: (err, stack) => Center(child: Text('데이터 조회 중 오류 발생: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLabel(
    BuildContext context, {
    required String label,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
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
          '$count',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildHomeworkItemCard(BuildContext context, StudentHomeworkItem item, String globalTitle) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final TextEditingController _memoController = TextEditingController(text: item.memo);

    return MathCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name, school, class + Status selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.studentName,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatGrade(item.grade),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.school} • ${item.className}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Status selectors (Completed ○ / Partial △ / Incomplete ×)
              Row(
                children: [
                  _buildStatusButton(
                    context,
                    label: '○',
                    isSelected: item.status == 'COMPLETED',
                    activeColor: const Color(0xFF4CAF50),
                    onTap: () => _updateStatus(item, 'COMPLETED', globalTitle),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusButton(
                    context,
                    label: '△',
                    isSelected: item.status == 'PARTIAL',
                    activeColor: const Color(0xFFFF9800),
                    onTap: () => _updateStatus(item, 'PARTIAL', globalTitle),
                  ),
                  const SizedBox(width: 6),
                  _buildStatusButton(
                    context,
                    label: '×',
                    isSelected: item.status == 'INCOMPLETE',
                    activeColor: const Color(0xFFEF5350),
                    onTap: () => _updateStatus(item, 'INCOMPLETE', globalTitle),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Inline Memo TextField with Save checkmark icon
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    controller: _memoController,
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '특이사항 메모 입력 (예: 오답 노트 미흡)',
                      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      suffixIcon: IconButton(
                        icon: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary, size: 18),
                        onPressed: () {
                          _updateMemo(item, _memoController.text.trim(), globalTitle);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${item.studentName} 메모를 저장했습니다.'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                    onFieldSubmitted: (val) {
                      _updateMemo(item, val.trim(), globalTitle);
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusButton(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: isSelected ? 2.0 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: ref.read(homeworkDateProvider),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ref.read(homeworkDateProvider.notifier).state = picked;
    }
  }

  void _updateStatus(StudentHomeworkItem item, String status, String globalTitle) {
    ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
          studentId: item.studentId,
          date: item.date,
          status: status,
          title: globalTitle.isEmpty ? item.title : globalTitle,
          memo: item.memo,
          homeworkId: item.homeworkId,
        );
  }

  void _updateMemo(StudentHomeworkItem item, String memo, String globalTitle) {
    ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
          studentId: item.studentId,
          date: item.date,
          status: item.status,
          title: globalTitle.isEmpty ? item.title : globalTitle,
          memo: memo.isEmpty ? null : memo,
          homeworkId: item.homeworkId,
        );
  }

  Future<void> _markAllAsCompleted(BuildContext context, String date, String title) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final grade = ref.read(globalGradeFilterProvider);
    try {
      await ref.read(homeworkRepositoryProvider).markAllAsCompleted(date, title, gradeFilter: grade);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            grade != null 
                ? '해당 학년의 모든 활성 학생 과제를 완료로 처리했습니다.' 
                : '모든 활성 학생의 과제를 완료로 처리했습니다.'
          )
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('일괄 과제 처리 실패: $e')),
      );
    }
  }

  String _formatGrade(int grade) {
    if (grade >= 1 && grade <= 6) {
      return '초$grade';
    } else if (grade >= 7 && grade <= 9) {
      return '중${grade - 6}';
    }
    return '$grade학년';
  }
}
