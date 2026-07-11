import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/student_detail_provider.dart';
import 'providers/student_list_provider.dart';
import '../domain/models/student_detail_data.dart';
import '../../test/domain/models/exam_group_models.dart';
import '../../test/domain/models/exam_models.dart';
import '../../test/presentation/providers/exam_providers.dart';
import '../../../core/utils/student_evaluator.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';
import '../../settings/presentation/providers/settings_providers.dart';
import '../../attendance/presentation/providers/attendance_providers.dart';
import '../../homework/presentation/providers/homework_providers.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class StudentDetailScreen extends ConsumerWidget {
  final String studentId;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(studentDetailStreamProvider(studentId));
    final activeIdsAsync = ref.watch(sortedActiveStudentIdsProvider);
    final theme = Theme.of(context);

    return detailAsync.when(
      data: (detail) {
        final stats = detail.stats;

        return DefaultTabController(
          length: 5,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('학생 상세 정보'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/student/edit/$studentId'),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350)),
                  onPressed: () => _showDeleteDialog(context, ref, stats.name),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Column(
              children: [
                activeIdsAsync.maybeWhen(
                  data: (ids) => _buildQuickNavigationRow(context, ref, ids),
                  orElse: () => const SizedBox.shrink(),
                ),
                // 1. Profile Header Section
                _buildProfileHeader(context, ref, stats),
                
                // 2. Tab Bar
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: theme.colorScheme.primary,
                  unselectedLabelColor: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                  indicatorColor: theme.colorScheme.primary,
                  tabs: const [
                    Tab(text: '출결'),
                    Tab(text: '과제'),
                    Tab(text: '시험'),
                    Tab(text: 'AI 분석'),
                    Tab(text: '상담 일지'),
                  ],
                ),
                
                // 3. Tab Bar View
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAttendanceTab(context, ref, studentId, detail.attendanceLogs),
                      _buildHomeworkTab(context, ref, studentId, detail.homeworkLogs),
                      _buildExamsTab(context, ref, detail),
                      _buildAITab(context, ref, detail),
                      _buildConsultingTab(context, ref, studentId, detail.consultingLogs),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: MathLoader(message: '학생 데이터를 분석하는 중...')),
      error: (err, stack) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text('학생 정보를 찾을 수 없습니다: $err')),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String studentName) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('학생 삭제'),
          content: Text('$studentName 학생을 삭제하시겠습니까?\n이 학생의 출결, 과제, 성적 기록이 모두 영구 삭제됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                Navigator.pop(context); // close dialog
                final router = GoRouter.of(context);
                final backup = await ref.read(studentRepositoryProvider).deleteStudentWithBackup(studentId);
                router.go('/student'); // Go back to list

                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('$studentName 학생 정보가 삭제되었습니다.'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: '실행 취소',
                      onPressed: () async {
                        try {
                          messenger.hideCurrentSnackBar();
                          await ref.read(studentRepositoryProvider).restoreStudentBackup(backup);
                          ref.invalidate(studentsStreamProvider);
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

  Widget _buildProfileHeader(BuildContext context, WidgetRef ref, stats) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16.0),
      color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  stats.name.substring(0, 1),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          stats.name,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatGrade(stats.grade),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '학교: ${stats.school}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '부모 연락처: ${stats.parentPhone}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '등록일: ${stats.registrationDate}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: stats.isActive 
                      ? const Color(0xFFE8F5E9) 
                      : const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  stats.isActive ? '재원 중' : '휴원 상태',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: stats.isActive 
                        ? const Color(0xFF2E7D32) 
                        : const Color(0xFFC62828),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InlineTeacherMemoEditor(
            studentId: stats.id,
            initialMemo: stats.memo,
            ref: ref,
          ),
        ],
      ),
    );
  }  Widget _buildAttendanceTab(BuildContext context, WidgetRef ref, String studentId, List<StudentAttendanceLog> logs) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return Center(child: Text('기록된 출결이 없습니다.', style: theme.textTheme.bodyMedium));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        Color badgeColor;
        String statusKr;

        if (log.status == 'ATTENDANCE') {
          badgeColor = const Color(0xFF4CAF50);
          statusKr = '출석';
        } else if (log.status == 'LATE') {
          badgeColor = const Color(0xFFFF9800);
          statusKr = '지각';
        } else if (log.status == 'EARLY_LEAVE') {
          badgeColor = const Color(0xFF03A9F4);
          statusKr = '조퇴';
        } else if (log.status == 'ABSENT') {
          badgeColor = const Color(0xFFF44336);
          statusKr = '결석';
        } else {
          badgeColor = const Color(0xFF9C27B0);
          statusKr = '휴원';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              log.date,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            trailing: InkWell(
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final prevStatus = log.status;
                String nextStatus;
                if (log.status == 'ATTENDANCE') {
                  nextStatus = 'ABSENT';
                } else if (log.status == 'ABSENT') {
                  nextStatus = 'LATE';
                } else if (log.status == 'LATE') {
                  nextStatus = 'EARLY_LEAVE';
                } else {
                  nextStatus = 'ATTENDANCE';
                }
                await ref.read(attendanceRepositoryProvider).updateAttendanceStatus(
                  studentId: studentId,
                  date: log.date,
                  status: nextStatus,
                );
                ref.invalidate(studentDetailStreamProvider(studentId));
                ref.invalidate(attendanceStreamProvider);

                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('출결 상태가 변경되었습니다.'),
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: '실행 취소',
                      onPressed: () async {
                        try {
                          messenger.hideCurrentSnackBar();
                          await ref.read(attendanceRepositoryProvider).updateAttendanceStatus(
                            studentId: studentId,
                            date: log.date,
                            status: prevStatus,
                          );
                          ref.invalidate(studentDetailStreamProvider(studentId));
                          ref.invalidate(attendanceStreamProvider);
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
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), // Larger tap target
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withOpacity(0.3)),
                ),
                child: Text(
                  statusKr,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildHomeworkTab(BuildContext context, WidgetRef ref, String studentId, List<StudentHomeworkLog> logs) {
    final theme = Theme.of(context);
    if (logs.isEmpty) {
      return Center(child: Text('기록된 과제가 없습니다.', style: theme.textTheme.bodyMedium));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        Color statusColor;
        String statusText;

        if (log.status == 'COMPLETED') {
          statusColor = const Color(0xFF4CAF50);
          statusText = '완료';
        } else if (log.status == 'PARTIAL') {
          statusColor = const Color(0xFFFF9800);
          statusText = '일부 완료';
        } else {
          statusColor = const Color(0xFFF44336);
          statusText = '미완료';
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        log.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    InkWell(
                      onTap: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final prevStatus = log.status;
                        String nextStatus;
                        if (log.status == 'COMPLETED') {
                          nextStatus = 'PARTIAL';
                        } else if (log.status == 'PARTIAL') {
                          nextStatus = 'INCOMPLETE';
                        } else {
                          nextStatus = 'COMPLETED';
                        }
                        await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                          studentId: studentId,
                          date: log.date,
                          status: nextStatus,
                          title: log.title,
                          memo: log.memo,
                        );
                        ref.invalidate(studentDetailStreamProvider(studentId));
                        ref.invalidate(homeworkStreamProvider);

                        messenger.clearSnackBars();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text('과제 상태가 변경되었습니다.'),
                            duration: const Duration(seconds: 5),
                            action: SnackBarAction(
                              label: '실행 취소',
                              onPressed: () async {
                                try {
                                  messenger.hideCurrentSnackBar();
                                  await ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                                    studentId: studentId,
                                    date: log.date,
                                    status: prevStatus,
                                    title: log.title,
                                    memo: log.memo,
                                  );
                                  ref.invalidate(studentDetailStreamProvider(studentId));
                                  ref.invalidate(homeworkStreamProvider);
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
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Larger touch target
                        child: Text(
                          statusText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '날짜: ${log.date}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 8),
                _InlineHomeworkMemoEditor(
                  studentId: studentId,
                  log: log,
                  ref: ref,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _parseColor(String hex) {
    try {
      final buffer = StringBuffer();
      if (hex.length == 6 || hex.length == 7) buffer.write('ff');
      buffer.write(hex.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return const Color(0xFF3F51B5);
    }
  }

  Widget _buildDetailGroupFilterChip(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final selectedGroupId = ref.watch(studentDetailGroupFilterProvider(studentId));
    final theme = Theme.of(context);

    return groupsAsync.maybeWhen(
      data: (groups) {
        return SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: const Text('전체'),
                  selected: selectedGroupId == null,
                  onSelected: (selected) {
                    if (selected) {
                      ref.read(studentDetailGroupFilterProvider(studentId).notifier).state = null;
                    }
                  },
                  selectedColor: theme.colorScheme.primary,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selectedGroupId == null ? theme.colorScheme.onPrimary : theme.textTheme.bodyMedium?.color,
                    fontWeight: selectedGroupId == null ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ),
              ...groups.map((g) {
                final isSelected = selectedGroupId == g.id;
                final gColor = _parseColor(g.colorHex);
                final chipTextColor = isSelected
                    ? (gColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white)
                    : theme.textTheme.bodyMedium?.color;

                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(g.name),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(studentDetailGroupFilterProvider(studentId).notifier).state = g.id;
                      }
                    },
                    selectedColor: gColor,
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      color: chipTextColor,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    avatar: isSelected
                        ? null
                        : Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: gColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                  ),
                );
              }),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildExamsTab(BuildContext context, WidgetRef ref, StudentDetailData detail) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final logs = detail.examLogs;
    final selectedGroupId = ref.watch(studentDetailGroupFilterProvider(studentId));
    final filteredLogs = selectedGroupId == null
        ? logs
        : logs.where((log) => log.examGroupId == selectedGroupId).toList();

    final allGroups = ref.watch(examGroupsStreamProvider).value ?? [];
    final selectedGroup = allGroups.firstWhere(
      (g) => g.id == selectedGroupId,
      orElse: () => const ExamGroup(id: '', name: '', colorHex: '', orderIndex: 0),
    );
    final chartColor = selectedGroupId != null && selectedGroup.colorHex.isNotEmpty
        ? _parseColor(selectedGroup.colorHex)
        : theme.colorScheme.primary;

    Widget graphWidget;
    if (filteredLogs.length < 2) {
      graphWidget = Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart, color: Colors.grey.shade400, size: 40),
              const SizedBox(height: 8),
              Text(
                '성적 추이 그래프를 보려면\n시험 데이터를 2회 이상 등록해주세요.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Calculate Stats using score percentages
      final percentages = filteredLogs.map((log) => (log.score / log.maxPossibleScore) * 100).toList();
      final double avgScore = percentages.reduce((a, b) => a + b) / percentages.length;
      
      var highestLog = filteredLogs[0];
      var lowestLog = filteredLogs[0];
      for (final log in filteredLogs) {
        final pct = (log.score / log.maxPossibleScore) * 100;
        final hiPct = (highestLog.score / highestLog.maxPossibleScore) * 100;
        final loPct = (lowestLog.score / lowestLog.maxPossibleScore) * 100;
        if (pct > hiPct) highestLog = log;
        if (pct < loPct) lowestLog = log;
      }
      
      String recentChangeText = '';
      Color recentChangeColor = theme.textTheme.bodyMedium?.color ?? Colors.black;
      if (filteredLogs.length >= 2) {
        final latestPct = (filteredLogs[0].score / filteredLogs[0].maxPossibleScore) * 100;
        final previousPct = (filteredLogs[1].score / filteredLogs[1].maxPossibleScore) * 100;
        final difference = latestPct - previousPct;
        final diffStr = difference % 1 == 0 ? difference.toStringAsFixed(0) : difference.toStringAsFixed(1);
        if (difference > 0) {
          recentChangeText = '+$diffStr% (직전 시험 대비)';
          recentChangeColor = const Color(0xFF2E7D32); // Green
        } else if (difference < 0) {
          recentChangeText = '$diffStr% (직전 시험 대비)';
          recentChangeColor = const Color(0xFFC62828); // Red
        } else {
          recentChangeText = '0% 변동 없음 (직전 시험 대비)';
          recentChangeColor = Colors.grey.shade600;
        }
      }

      final chronologicalLogs = filteredLogs.reversed.toList();
      final spots = chronologicalLogs.asMap().entries.map((entry) {
        final pct = (entry.value.score / entry.value.maxPossibleScore) * 100;
        return FlSpot(entry.key.toDouble(), pct);
      }).toList();

      final barData = LineChartBarData(
        spots: spots,
        isCurved: false,
        color: chartColor,
        barWidth: 3,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
            radius: 4.5,
            color: chartColor,
            strokeWidth: 2,
            strokeColor: Colors.white,
          ),
        ),
        belowBarData: BarAreaData(
          show: true,
          color: chartColor.withOpacity(0.08),
        ),
      );

      graphWidget = Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MathCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '성적 추이 그래프',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: 20,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: isDark ? Colors.white10 : Colors.black12,
                        strokeWidth: 0.8,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 20,
                          getTitlesWidget: (value, meta) => SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${value.toInt()}%',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                            ),
                          ),
                          reservedSize: 28,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final idx = value.toInt();
                            if (idx >= 0 && idx < chronologicalLogs.length) {
                              final title = chronologicalLogs[idx].title;
                              final shortenedTitle = title.length > 5 ? '${title.substring(0, 4)}..' : title;
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  shortenedTitle,
                                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 9),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                          reservedSize: 22,
                          interval: 1,
                        ),
                      ),
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                        left: BorderSide(color: isDark ? Colors.white10 : Colors.black12, width: 1),
                      ),
                    ),
                    minX: 0,
                    maxX: (chronologicalLogs.length - 1).toDouble(),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [barData],
                    lineTouchData: LineTouchData(
                      enabled: false,
                      handleBuiltInTouches: false,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (spot) => Colors.transparent,
                        tooltipRoundedRadius: 0,
                        tooltipPadding: EdgeInsets.zero,
                        tooltipMargin: 8,
                        getTooltipItems: (List<LineBarSpot> touchedSpots) {
                          return touchedSpots.map((spot) {
                            final idx = spot.x.toInt();
                            if (idx >= 0 && idx < chronologicalLogs.length) {
                              final log = chronologicalLogs[idx];
                              return LineTooltipItem(
                                ExamScoreFormatter.formatScore(log.score, log.maxPossibleScore),
                                TextStyle(
                                  color: chartColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              );
                            }
                            return LineTooltipItem(
                              '${spot.y.toInt()}%',
                              TextStyle(color: chartColor),
                            );
                          }).toList();
                        },
                      ),
                    ),
                    showingTooltipIndicators: spots.map((spot) {
                      return ShowingTooltipIndicators([
                        LineBarSpot(barData, 0, spot),
                      ]);
                    }).toList(),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(
                          y: avgScore,
                          color: chartColor.withOpacity(0.5),
                          strokeWidth: 1.2,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: chartColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            labelResolver: (line) => '평균: ${ExamScoreFormatter.formatPercentage(avgScore)}',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(context, '평균 점수', ExamScoreFormatter.formatPercentage(avgScore)),
                  _buildStatItem(
                    context,
                    '최고 점수',
                    ExamScoreFormatter.formatStats(
                      (highestLog.score / highestLog.maxPossibleScore) * 100,
                      highestLog.score.toDouble(),
                      highestLog.maxPossibleScore,
                    ),
                  ),
                  _buildStatItem(
                    context,
                    '최저 점수',
                    ExamScoreFormatter.formatStats(
                      (lowestLog.score / lowestLog.maxPossibleScore) * 100,
                      lowestLog.score.toDouble(),
                      lowestLog.maxPossibleScore,
                    ),
                  ),
                ],
              ),
              if (recentChangeText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: recentChangeColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      recentChangeText,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: recentChangeColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final comparison = selectedGroupId != null ? detail.groupComparisons[selectedGroupId] : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDetailGroupFilterChip(context, ref),
        const SizedBox(height: 16),
        graphWidget,
        
        // 4.2 Performance Comparison Card
        if (comparison != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
            child: Text(
              '반내 성취도 비교 분석',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          MathCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('내 평균 성적', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      ExamScoreFormatter.formatPercentage(comparison.studentAveragePct),
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('반 평균 성적', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      ExamScoreFormatter.formatPercentage(comparison.classAveragePct),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('반 평균과의 차이', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${comparison.difference >= 0 ? '+' : ''}${comparison.difference.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: comparison.difference >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('반 석차', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '${comparison.rank}등 / ${comparison.totalParticipants}명',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('백분위', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '상위 ${comparison.percentile}%',
                      style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('성적 향상 추이', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      comparison.trend == 'improving'
                          ? '▲ 빠르게 향상 중'
                          : (comparison.trend == 'falling' ? '▼ 하락 우려' : '유지 중'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: comparison.trend == 'improving'
                            ? const Color(0xFF2E7D32)
                            : (comparison.trend == 'falling' ? const Color(0xFFC62828) : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0, top: 8.0),
          child: Text(
            '시험 기록 목록',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (filteredLogs.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(child: Text('해당 그룹에 기록된 시험이 없습니다.')),
            ),
          )
        else
          ...filteredLogs.map((log) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  log.title,
                  style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('날짜: ${log.date}'),
                trailing: Text(
                  ExamScoreFormatter.formatScore(log.score, log.maxPossibleScore),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: chartColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildAITab(BuildContext context, WidgetRef ref, StudentDetailData detail) {
    final theme = Theme.of(context);
    final selectedGroupId = ref.watch(studentDetailGroupFilterProvider(studentId));
    
    // Recalculate AI evaluation based on selected group exams
    final filteredExamLogs = selectedGroupId == null
        ? detail.examLogs
        : detail.examLogs.where((log) => log.examGroupId == selectedGroupId).toList();
    final filteredPercentagesList = filteredExamLogs.reversed.map((e) => (e.score / e.maxPossibleScore) * 100).toList();
    final comparison = selectedGroupId != null ? detail.groupComparisons[selectedGroupId] : null;
    
    final ai = StudentEvaluator.evaluateWithRisk(
      scorePercentages: filteredPercentagesList,
      attendanceStatuses: detail.attendanceLogs.reversed.map((a) => a.status).toList(),
      homeworkStatuses: detail.homeworkLogs.reversed.map((h) => h.status).toList(),
      riskScore: detail.stats.riskScore,
      triggers: [],
      comparison: comparison,
    );

    final allGroups = ref.watch(examGroupsStreamProvider).value ?? [];
    final selectedGroup = allGroups.firstWhere(
      (g) => g.id == selectedGroupId,
      orElse: () => const ExamGroup(id: '', name: '', colorHex: '', orderIndex: 0),
    );
    final groupColor = selectedGroupId != null && selectedGroup.colorHex.isNotEmpty
        ? _parseColor(selectedGroup.colorHex)
        : theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter Chips
          _buildDetailGroupFilterChip(context, ref),
          const SizedBox(height: 16),

          // Check sufficiency
          if (!ai.isSufficient) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.analytics_outlined, size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      '분석할 데이터가 충분하지 않습니다.',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '정확한 분석을 위해 시험 성적, 과제 완료 여부, 출결 기록을 먼저 입력해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            // Subtitle
            Padding(
              padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
              child: Text(
                selectedGroupId != null 
                    ? '"${selectedGroup.name}" 그룹 맞춤 학습 분석 보고서'
                    : '데이터 기반 맞춤 종합 학습 분석 보고서',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: groupColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            _buildLearningCard(
              context,
              title: '시험',
              content: ai.examText,
              icon: Icons.assessment_outlined,
              color: groupColor,
            ),
            const SizedBox(height: 12),
            _buildLearningCard(
              context,
              title: '과제',
              content: ai.homeworkText,
              icon: Icons.assignment_outlined,
              color: const Color(0xFFFF9800),
            ),
            const SizedBox(height: 12),
            _buildLearningCard(
              context,
              title: '출결',
              content: ai.attendanceText,
              icon: Icons.calendar_today_outlined,
              color: const Color(0xFF4CAF50),
            ),
            const SizedBox(height: 12),
            _buildLearningCard(
              context,
              title: '성장률',
              content: ai.growthText,
              icon: Icons.trending_up_outlined,
              color: selectedGroupId != null ? groupColor : const Color(0xFF9C27B0),
            ),
            const SizedBox(height: 12),
            _buildLearningCard(
              context,
              title: '주의사항',
              content: ai.warningText,
              icon: Icons.warning_amber_rounded,
              color: const Color(0xFFEF5350),
            ),
            const SizedBox(height: 12),
            _buildLearningCard(
              context,
              title: '추천',
              content: ai.recommendationText,
              icon: Icons.lightbulb_outline,
              color: const Color(0xFF2E7D32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLearningCard(
    BuildContext context, {
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return MathCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsultingTab(BuildContext context, WidgetRef ref, String studentId, List<StudentConsultingLog> logs) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () => _showAddConsultingDialog(context, ref, studentId),
            icon: const Icon(Icons.add),
            label: const Text('상담 일지 추가'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48), // Large touch target
            ),
          ),
        ),
        Expanded(
          child: logs.isEmpty
              ? Center(child: Text('등록된 상담 일지가 없습니다.', style: theme.textTheme.bodyMedium))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) {
                    final log = logs[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    log.title,
                                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                Text(
                                  log.date,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                                  ),
                                ),
                              ],
                            ),
                            if (log.memo != null && log.memo!.trim().isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8.0),
                                child: Divider(height: 1),
                              ),
                              Text(
                                log.memo!,
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                              ),
                            ],
                            if (log.id != null) ...[
                              const Divider(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _showEditConsultingDialog(context, ref, studentId, log),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('수정'),
                                    style: TextButton.styleFrom(minimumSize: const Size(60, 40)),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () async {
                                      await ref.read(settingsRepositoryProvider).deleteSchedule(log.id!);
                                      ref.invalidate(studentDetailStreamProvider(studentId));
                                      ref.invalidate(allSchedulesStreamProvider);
                                    },
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF5350)),
                                    label: const Text('삭제', style: TextStyle(color: Color(0xFFEF5350))),
                                    style: TextButton.styleFrom(minimumSize: const Size(60, 40)),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showAddConsultingDialog(BuildContext context, WidgetRef ref, String studentId) {
    final titleController = TextEditingController(text: '개별 상담');
    final memoController = TextEditingController();
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상담 일지 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '상담 제목 *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: '날짜 (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '상담 내용 (메모)'),
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
                final title = titleController.text.trim();
                final date = dateController.text.trim();
                final memo = memoController.text.trim();
                if (title.isEmpty || date.isEmpty) return;

                final navigator = Navigator.of(context);
                await ref.read(settingsRepositoryProvider).addSchedule(
                  title: title,
                  date: date,
                  type: 'CONSULT',
                  memo: memo.isEmpty ? null : memo,
                  studentId: studentId,
                );

                ref.invalidate(studentDetailStreamProvider(studentId));
                ref.invalidate(allSchedulesStreamProvider);
                navigator.pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
    );
  }

  void _showEditConsultingDialog(BuildContext context, WidgetRef ref, String studentId, StudentConsultingLog log) {
    final titleController = TextEditingController(text: log.title);
    final memoController = TextEditingController(text: log.memo ?? '');
    final dateController = TextEditingController(text: log.date);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('상담 일지 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: '상담 제목 *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: dateController,
                  decoration: const InputDecoration(labelText: '날짜 (YYYY-MM-DD) *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: memoController,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: '상담 내용 (메모)'),
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
                final title = titleController.text.trim();
                final date = dateController.text.trim();
                final memo = memoController.text.trim();
                if (title.isEmpty || date.isEmpty) return;

                final navigator = Navigator.of(context);
                await ref.read(settingsRepositoryProvider).updateSchedule(
                  id: log.id!,
                  title: title,
                  date: date,
                  memo: memo.isEmpty ? null : memo,
                );

                ref.invalidate(studentDetailStreamProvider(studentId));
                ref.invalidate(allSchedulesStreamProvider);
                navigator.pop();
              },
              child: const Text('저장'),
            ),
          ],
        );
      },
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

  Widget _buildQuickNavigationRow(BuildContext context, WidgetRef ref, List<String> ids) {
    final idx = ids.indexOf(studentId);
    if (idx == -1) return const SizedBox.shrink();

    final prevId = idx > 0 ? ids[idx - 1] : null;
    final nextId = idx < ids.length - 1 ? ids[idx + 1] : null;

    final theme = Theme.of(context);

    return Container(
      color: theme.brightness == Brightness.dark ? Colors.black26 : Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous student
          TextButton.icon(
            onPressed: prevId != null
                ? () => GoRouter.of(context).replace('/student/$prevId')
                : null,
            icon: const Icon(Icons.arrow_back_ios, size: 14),
            label: const Text('이전 학생', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              minimumSize: const Size(100, 40),
            ),
          ),
          Text(
            '${idx + 1} / ${ids.length}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
            ),
          ),
          // Next student
          TextButton.icon(
            onPressed: nextId != null
                ? () => GoRouter.of(context).replace('/student/$nextId')
                : null,
            icon: const Icon(Icons.arrow_forward_ios, size: 14),
            label: const Text('다음 학생', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              foregroundColor: theme.colorScheme.primary,
              minimumSize: const Size(100, 40),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineTeacherMemoEditor extends StatefulWidget {
  final String studentId;
  final String? initialMemo;
  final WidgetRef ref;

  const _InlineTeacherMemoEditor({
    required this.studentId,
    required this.initialMemo,
    required this.ref,
  });

  @override
  State<_InlineTeacherMemoEditor> createState() => _InlineTeacherMemoEditorState();
}

class _InlineTeacherMemoEditorState extends State<_InlineTeacherMemoEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMemo ?? '');
  }

  @override
  void didUpdateWidget(covariant _InlineTeacherMemoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialMemo != widget.initialMemo) {
      _controller.text = widget.initialMemo ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF2E3135) : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '선생님 메모 (수정 시 자동 저장)',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Focus(
            onFocusChange: (hasFocus) async {
              if (!hasFocus) {
                final text = _controller.text.trim();
                if (text != (widget.initialMemo ?? '')) {
                  await widget.ref.read(studentRepositoryProvider).updateStudentMemo(widget.studentId, text);
                  widget.ref.invalidate(studentDetailStreamProvider(widget.studentId));
                  widget.ref.invalidate(studentsStreamProvider);
                }
              }
            },
            child: TextField(
              controller: _controller,
              maxLines: null,
              style: theme.textTheme.bodyMedium,
              decoration: const InputDecoration(
                hintText: '특이사항이나 상담 메모를 여기에 기록하세요...',
                hintStyle: TextStyle(fontSize: 13, color: Colors.grey),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (val) async {
                final text = val.trim();
                if (text != (widget.initialMemo ?? '')) {
                  await widget.ref.read(studentRepositoryProvider).updateStudentMemo(widget.studentId, text);
                  widget.ref.invalidate(studentDetailStreamProvider(widget.studentId));
                  widget.ref.invalidate(studentsStreamProvider);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineHomeworkMemoEditor extends StatefulWidget {
  final String studentId;
  final StudentHomeworkLog log;
  final WidgetRef ref;

  const _InlineHomeworkMemoEditor({
    required this.studentId,
    required this.log,
    required this.ref,
  });

  @override
  State<_InlineHomeworkMemoEditor> createState() => _InlineHomeworkMemoEditorState();
}

class _InlineHomeworkMemoEditorState extends State<_InlineHomeworkMemoEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.log.memo ?? '');
  }

  @override
  void didUpdateWidget(covariant _InlineHomeworkMemoEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.log.memo != widget.log.memo) {
      _controller.text = widget.log.memo ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Text('메모: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
        Expanded(
          child: Focus(
            onFocusChange: (hasFocus) async {
              if (!hasFocus) {
                final text = _controller.text.trim();
                if (text != (widget.log.memo ?? '')) {
                  await widget.ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                    studentId: widget.studentId,
                    date: widget.log.date,
                    status: widget.log.status,
                    title: widget.log.title,
                    memo: text.isEmpty ? null : text,
                  );
                  widget.ref.invalidate(studentDetailStreamProvider(widget.studentId));
                }
              }
            },
            child: TextField(
              controller: _controller,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
              decoration: const InputDecoration(
                hintText: '메모 입력 (자동 저장)',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              onSubmitted: (val) async {
                final text = val.trim();
                if (text != (widget.log.memo ?? '')) {
                  await widget.ref.read(homeworkRepositoryProvider).updateHomeworkStatus(
                    studentId: widget.studentId,
                    date: widget.log.date,
                    status: widget.log.status,
                    title: widget.log.title,
                    memo: text.isEmpty ? null : text,
                  );
                  widget.ref.invalidate(studentDetailStreamProvider(widget.studentId));
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
