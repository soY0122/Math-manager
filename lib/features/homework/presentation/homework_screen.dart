import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/homework_providers.dart';
import '../domain/models/student_homework_item.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';

class HomeworkScreen extends ConsumerStatefulWidget {
  const HomeworkScreen({super.key});

  @override
  ConsumerState<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends ConsumerState<HomeworkScreen> {
  final TextEditingController _titleController = TextEditingController();

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
    final homeworkAsync = ref.watch(homeworkStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('과제 관리'),
        actions: [
          homeworkAsync.maybeWhen(
            data: (list) => TextButton.icon(
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('전체 완료'),
              onPressed: () => _markAllAsCompleted(context, dateStr, list),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Date Picker & Add Homework Card
          Container(
            padding: const EdgeInsets.all(16.0),
            color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                
                // Grade Selector Label & Chips
                Text(
                  '학년 선택',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildGradeChip(context, ref, '전체', null),
                      ...List.generate(9, (index) {
                        final gradeVal = index + 1;
                        final label = gradeVal <= 6 ? '초$gradeVal' : '중${gradeVal - 6}';
                        return Padding(
                          padding: const EdgeInsets.only(left: 6.0),
                          child: _buildGradeChip(context, ref, label, gradeVal),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Add Homework Title Input & Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: '오늘의 과제 명칭',
                          hintText: '예: 쎈 수학 C단계 풀이',
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final title = _titleController.text.trim();
                        if (title.isEmpty) return;
                        await ref.read(homeworkRepositoryProvider).addHomeworkAssignment(
                          date: dateStr,
                          title: title,
                          gradeFilter: ref.read(homeworkGradeFilterProvider),
                        );
                        _titleController.clear();
                        ref.invalidate(homeworkStreamProvider);
                      },
                      child: const Text('추가'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Homework Checklist Summary & List
          Expanded(
            child: homeworkAsync.when(
              data: (list) {
                final Map<String, List<StudentHomeworkItem>> grouped = {};
                final Map<String, String> studentNames = {};
                final Map<String, String> studentSchools = {};
                final Map<String, int> studentGrades = {};
                final Map<String, String> studentClasses = {};

                for (final item in list) {
                  grouped.putIfAbsent(item.studentId, () => []).add(item);
                  studentNames[item.studentId] = item.studentName;
                  studentSchools[item.studentId] = item.school;
                  studentGrades[item.studentId] = item.grade;
                  studentClasses[item.studentId] = item.className;
                }

                final studentIds = grouped.keys.toList();
                final total = studentIds.length;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '대상 인원: $total명',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: total == 0
                          ? Center(
                              child: Text(
                                '해당 학년에 등록된 과제가 없습니다.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: const EdgeInsets.all(16.0),
                              itemCount: total,
                              itemBuilder: (context, index) {
                                final sId = studentIds[index];
                                final studentHws = grouped[sId] ?? [];
                                final name = studentNames[sId] ?? '';
                                final school = studentSchools[sId] ?? '';
                                final grade = studentGrades[sId] ?? 1;
                                final className = studentClasses[sId] ?? '';

                                return Padding(
                                  key: ValueKey('homework_student_$sId'),
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: _buildStudentHomeworkCard(
                                    context,
                                    studentId: sId,
                                    name: name,
                                    school: school,
                                    grade: grade,
                                    className: className,
                                    hws: studentHws,
                                    dateStr: dateStr,
                                  ),
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

  Widget _buildGradeChip(BuildContext context, WidgetRef ref, String label, int? value) {
    final selectedGrade = ref.watch(homeworkGradeFilterProvider);
    final isSelected = selectedGrade == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          ref.read(homeworkGradeFilterProvider.notifier).state = value;
        }
      },
    );
  }

  Widget _buildStudentHomeworkCard(
    BuildContext context, {
    required String studentId,
    required String name,
    required String school,
    required int grade,
    required String className,
    required List<StudentHomeworkItem> hws,
    required String dateStr,
  }) {
    final theme = Theme.of(context);

    return MathCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name & School
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatGrade(grade),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$school • $className',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Divider(height: 16),
          // Checklist of homework items with three-state status badges
          ...hws.map((hw) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hw.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: hw.status == 'COMPLETED' ? TextDecoration.lineThrough : null,
                        color: hw.status == 'COMPLETED' ? Colors.grey : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(
                    context,
                    label: '완료',
                    isSelected: hw.status == 'COMPLETED',
                    color: const Color(0xFF4CAF50),
                    onTap: () async {
                      await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                        studentId: studentId,
                        date: dateStr,
                        status: 'COMPLETED',
                        title: hw.title,
                        memo: hw.memo,
                      );
                      ref.invalidate(homeworkStreamProvider);
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildStatusBadge(
                    context,
                    label: '일부',
                    isSelected: hw.status == 'PARTIAL',
                    color: const Color(0xFFFF9800),
                    onTap: () async {
                      await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                        studentId: studentId,
                        date: dateStr,
                        status: 'PARTIAL',
                        title: hw.title,
                        memo: hw.memo,
                      );
                      ref.invalidate(homeworkStreamProvider);
                    },
                  ),
                  const SizedBox(width: 4),
                  _buildStatusBadge(
                    context,
                    label: '미완료',
                    isSelected: hw.status == 'INCOMPLETE',
                    color: const Color(0xFFEF5350),
                    onTap: () async {
                      await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                        studentId: studentId,
                        date: dateStr,
                        status: 'INCOMPLETE',
                        title: hw.title,
                        memo: hw.memo,
                      );
                      ref.invalidate(homeworkStreamProvider);
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350), size: 20),
                    onPressed: () async {
                      await ref.read(homeworkRepositoryProvider).deleteHomeworkAssignment(
                        date: dateStr,
                        title: hw.title,
                        gradeFilter: ref.read(homeworkGradeFilterProvider),
                      );
                      ref.invalidate(homeworkStreamProvider);
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isSelected ? color : theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
            fontWeight: FontWeight.bold,
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

  void _markAllAsCompleted(BuildContext context, String date, List<StudentHomeworkItem> list) async {
    final messenger = ScaffoldMessenger.of(context);
    for (final item in list) {
      await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
        studentId: item.studentId,
        date: date,
        status: 'COMPLETED',
        title: item.title,
        memo: item.memo,
      );
    }
    ref.invalidate(homeworkStreamProvider);
    
    messenger.clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('모든 학생의 과제가 완료 처리되었습니다.'), duration: Duration(seconds: 2)),
    );
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
