import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/student_list_provider.dart';
import '../domain/models/student_stats.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';

class StudentListScreen extends ConsumerStatefulWidget {
  final String? filter;

  const StudentListScreen({super.key, this.filter});

  @override
  ConsumerState<StudentListScreen> createState() => _StudentListScreenState();
}

class _StudentListScreenState extends ConsumerState<StudentListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(studentFilterProvider.notifier).state = widget.filter;
      }
    });
  }

  @override
  void didUpdateWidget(covariant StudentListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filter != oldWidget.filter) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(studentFilterProvider.notifier).state = widget.filter;
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final studentsAsync = ref.watch(studentsStreamProvider);
    final activeFilter = ref.watch(studentFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('학생 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => context.push('/student/add'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                ref.read(studentSearchProvider.notifier).state = val;
              },
              decoration: InputDecoration(
                hintText: '이름으로 검색...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(studentSearchProvider.notifier).state = '';
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          if (activeFilter != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  InputChip(
                    label: Text(_getFilterLabel(activeFilter)),
                    onDeleted: () {
                      ref.read(studentFilterProvider.notifier).state = null;
                      context.go('/student');
                    },
                    deleteIconColor: theme.colorScheme.error,
                  ),
                ],
              ),
            ),

          // 3. Students Count Header & List
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                final activeCount = students.where((s) => s.isActive).length;
                final inactiveCount = students.where((s) => !s.isActive).length;

                final searchActive = ref.watch(studentSearchProvider).isNotEmpty;
                final collapsedGrades = ref.watch(collapsedGradesProvider);

                // Group students by grade
                final Map<int, List<StudentStats>> grouped = {};
                for (final s in students) {
                  grouped.putIfAbsent(s.grade, () => []).add(s);
                }

                // Build flat items list
                final List<dynamic> flatItems = [];
                final gradeOrder = [1, 2, 3, 4, 5, 6, 7, 8, 9];

                for (final g in gradeOrder) {
                  final gradeStudents = grouped[g] ?? [];
                  if (gradeStudents.isEmpty) continue;

                  final isCollapsed = !searchActive && collapsedGrades.contains(g);
                  flatItems.add(_GradeHeaderItem(
                    grade: g,
                    count: gradeStudents.length,
                    isCollapsed: isCollapsed,
                  ));

                  if (!isCollapsed) {
                    for (final s in gradeStudents) {
                      flatItems.add(s);
                    }
                  }
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          Text(
                            '재원생: $activeCount명',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '|',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '휴원생: $inactiveCount명',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: flatItems.isEmpty
                          ? Center(
                              child: Text(
                                '조건에 맞는 학생이 없습니다.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: flatItems.length,
                              itemBuilder: (context, index) {
                                final item = flatItems[index];
                                if (item is _GradeHeaderItem) {
                                  return _buildGradeHeader(context, ref, item, key: ValueKey('grade_${item.grade}'));
                                } else if (item is StudentStats) {
                                  return Padding(
                                    key: ValueKey('student_${item.id}'),
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: _buildStudentCard(context, item),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const MathLoader(message: '학생 목록을 불러오는 중...'),
              error: (error, stack) => Center(child: Text('에러 발생: $error')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/student/add'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add),
      ),
    );
  }


  Widget _buildStudentCard(BuildContext context, StudentStats student) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Growth Icon
    String growthIcon = '➖';
    Color growthColor = Colors.grey.shade600;
    if (student.growthTrend == '상승 중') {
      growthIcon = '📈';
      growthColor = const Color(0xFF2E7D32);
    } else if (student.growthTrend == '하락 중') {
      growthIcon = '📉';
      growthColor = const Color(0xFFC62828);
    }

    return MathCard(
      onTap: () => context.push('/student/${student.id}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Photo (or Avatar) + Name/School + Active Tag
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  student.name.substring(0, 1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          student.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatGrade(student.grade),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student.school,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: student.isActive
                      ? const Color(0xFFE8F5E9)
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  student.isActive ? '재원' : '휴원',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: student.isActive 
                        ? const Color(0xFF2E7D32) 
                        : const Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12.0),
            child: Divider(height: 1),
          ),
          // Statistics Grid inside Card
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(
                context,
                label: '평균 성적',
                value: student.averageScore > 0 
                    ? '${student.averageScore.toStringAsFixed(0)}점' 
                    : '-',
              ),
              _buildMiniStat(
                context,
                label: '성장도',
                value: '$growthIcon ${student.growthTrend}',
                valueColor: isDark ? null : growthColor,
              ),
              _buildMiniStat(
                context,
                label: '출석률',
                value: '${(student.attendanceRate * 100).toStringAsFixed(0)}%',
              ),
              _buildMiniStat(
                context,
                label: '과제율',
                value: '${(student.homeworkCompletionRate * 100).toStringAsFixed(0)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
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
            color: valueColor,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _getFilterLabel(String filter) {
    switch (filter) {
      case 'attendance_present':
        return '오늘 출석한 학생';
      case 'attendance_late':
        return '오늘 지각한 학생';
      case 'attendance_absent':
        return '오늘 결석한 학생';
      case 'homework_incomplete':
        return '오늘 숙제 미완료 학생';
      case 'at_risk':
        return '위험 학생군';
      default:
        return '필터링 적용 중';
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

  Widget _buildGradeHeader(BuildContext context, WidgetRef ref, _GradeHeaderItem item, {Key? key}) {
    final theme = Theme.of(context);
    final gradeName = _formatGrade(item.grade);

    return InkWell(
      key: key,
      onTap: () {
        final notifier = ref.read(collapsedGradesProvider.notifier);
        final current = notifier.state;
        if (current.contains(item.grade)) {
          notifier.state = current.difference({item.grade});
        } else {
          notifier.state = current.union({item.grade});
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Row(
          children: [
            Icon(
              item.isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 6),
            Text(
              gradeName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${item.count}명',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradeHeaderItem {
  final int grade;
  final int count;
  final bool isCollapsed;

  const _GradeHeaderItem({
    required this.grade,
    required this.count,
    required this.isCollapsed,
  });
}

