import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/attendance_providers.dart';
import '../domain/models/student_attendance_item.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/widgets/math_loader.dart';
import 'package:table_calendar/table_calendar.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.week; // Week view is perfect for one-handed mobile use

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final selectedDate = ref.watch(attendanceDateProvider);
    final dateStr = selectedDate.toIso8601String().split('T')[0];
    final attendanceAsync = ref.watch(attendanceStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('출결 관리'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text('전체 출석'),
            onPressed: () => _markAllAsPresent(context, dateStr),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 1. Weekly / Monthly Calendar View
          Container(
            color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
            padding: const EdgeInsets.only(bottom: 12.0),
            child: TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: selectedDate,
              calendarFormat: _calendarFormat,
              selectedDayPredicate: (day) => isSameDay(selectedDate, day),
              onDaySelected: (selectedDay, focusedDay) {
                ref.read(attendanceDateProvider.notifier).state = selectedDay;
              },
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              headerStyle: HeaderStyle(
                formatButtonVisible: true,
                formatButtonDecoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.5)),
                  borderRadius: BorderRadius.circular(12),
                ),
                formatButtonTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                titleCentered: true,
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: TextStyle(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
                outsideDaysVisible: false,
              ),
            ),
          ),

          // 2. Attendance Summary / Header
          Expanded(
            child: attendanceAsync.when(
              data: (list) {
                final total = list.length;
                final present = list.where((item) => item.status == 'ATTENDANCE').length;
                final lates = list.where((item) => item.status == 'LATE').length;
                final absents = list.where((item) => item.status == 'ABSENT').length;
                final leaves = list.where((item) => item.status == 'LEAVE').length;

                final rate = total > 0 ? (present + lates) / total : 1.0;

                return Column(
                  children: [
                    // Summary Row
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '출석 대상: $total명',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '출석률: ${(rate * 100).toStringAsFixed(0)}%',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              _buildSummaryCounter(context, label: '출석', count: present, color: const Color(0xFF4CAF50)),
                              const SizedBox(width: 12),
                              _buildSummaryCounter(context, label: '지각', count: lates, color: const Color(0xFFFF9800)),
                              const SizedBox(width: 12),
                              _buildSummaryCounter(context, label: '결석', count: absents, color: const Color(0xFFF44336)),
                              const SizedBox(width: 12),
                              _buildSummaryCounter(context, label: '휴원', count: leaves, color: const Color(0xFF9C27B0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // Student Attendance Switcher List
                    Expanded(
                      child: list.isEmpty
                          ? Center(
                              child: Text(
                                '재원 중인 학생이 없습니다.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16.0),
                              itemCount: list.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: _buildAttendanceItemTile(context, list[index]),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const MathLoader(message: '출결 상태를 조회하는 중...'),
              error: (err, stack) => Center(child: Text('데이터 조회 중 오류 발생: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCounter(
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

  Widget _buildAttendanceItemTile(BuildContext context, StudentAttendanceItem item) {
    final theme = Theme.of(context);

    // Get Status aesthetics
    Color statusColor;
    String statusKr;

    if (item.status == 'ATTENDANCE') {
      statusColor = const Color(0xFF4CAF50);
      statusKr = '출석';
    } else if (item.status == 'LATE') {
      statusColor = const Color(0xFFFF9800);
      statusKr = '지각';
    } else if (item.status == 'ABSENT') {
      statusColor = const Color(0xFFF44336);
      statusKr = '결석';
    } else {
      statusColor = const Color(0xFF9C27B0);
      statusKr = '휴원';
    }

    return MathCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _cycleAttendanceStatus(item),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Student details
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
          // Status switch button (Cycles on press)
          InkWell(
            onTap: () => _cycleAttendanceStatus(item),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.4), width: 1.5),
              ),
              child: Row(
                children: [
                  Text(
                    statusKr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.sync,
                    size: 14,
                    color: statusColor.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _cycleAttendanceStatus(StudentAttendanceItem item) {
    String next;
    switch (item.status) {
      case 'ATTENDANCE':
        next = 'LATE';
        break;
      case 'LATE':
        next = 'ABSENT';
        break;
      case 'ABSENT':
        next = 'LEAVE';
        break;
      case 'LEAVE':
        next = 'ATTENDANCE';
        break;
      default:
        next = 'ATTENDANCE';
    }

    ref.read(attendanceRepositoryProvider).updateAttendanceStatus(
          studentId: item.studentId,
          date: item.date,
          status: next,
          attendanceId: item.attendanceId,
        );
  }

  Future<void> _markAllAsPresent(BuildContext context, String date) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final grade = ref.read(globalGradeFilterProvider);
    try {
      await ref.read(attendanceRepositoryProvider).markAllAsPresent(date, gradeFilter: grade);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            grade != null 
                ? '해당 학년의 모든 활성 학생을 출석으로 처리했습니다.' 
                : '모든 활성 학생을 출석으로 처리했습니다.'
          )
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('일괄 출석 처리 실패: $e')),
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
