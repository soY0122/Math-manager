import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import 'providers/settings_providers.dart';
import '../../test/presentation/providers/exam_providers.dart';
import '../../test/domain/models/exam_group_models.dart';
import '../domain/models/settings_models.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('설정 및 통계'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '학원 일정', icon: Icon(Icons.calendar_today, size: 20)),
              Tab(text: '학원 통계', icon: Icon(Icons.analytics_outlined, size: 20)),
              Tab(text: '설정 관리', icon: Icon(Icons.settings_outlined, size: 20)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ScheduleCalendarTab(),
            _AcademyStatsTab(),
            _SystemSettingsTab(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: SCHEDULE CALENDAR
// ==========================================
class _ScheduleCalendarTab extends ConsumerStatefulWidget {
  const _ScheduleCalendarTab();

  @override
  ConsumerState<_ScheduleCalendarTab> createState() => _ScheduleCalendarTabState();
}

class _ScheduleCalendarTabState extends ConsumerState<_ScheduleCalendarTab> {
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final selectedDate = ref.watch(scheduleSelectedDateProvider);
    final dateStr = selectedDate.toIso8601String().split('T')[0];

    final dateSchedulesAsync = ref.watch(dateSchedulesStreamProvider);
    final allSchedulesAsync = ref.watch(allSchedulesStreamProvider);

    return Scaffold(
      body: Column(
        children: [
          // Calendar Card
          allSchedulesAsync.when(
            data: (allSchedules) {
              // Group schedules by date for markers
              final Map<DateTime, List<ScheduleItem>> events = {};
              for (final s in allSchedules) {
                final dateParts = s.date.split('-');
                if (dateParts.length == 3) {
                  final dt = DateTime.utc(
                    int.parse(dateParts[0]),
                    int.parse(dateParts[1]),
                    int.parse(dateParts[2]),
                  );
                  events.putIfAbsent(dt, () => []).add(s);
                }
              }

              return Container(
                color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
                padding: const EdgeInsets.only(bottom: 12.0),
                child: TableCalendar(
                  locale: 'ko_KR',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: selectedDate,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                  eventLoader: (day) {
                    final normalizedDay = DateTime.utc(day.year, day.month, day.day);
                    return events[normalizedDay] ?? [];
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    ref.read(scheduleSelectedDateProvider.notifier).state = selectedDay;
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  availableCalendarFormats: const {
                    CalendarFormat.month: '월간',
                    CalendarFormat.twoWeeks: '2주간',
                    CalendarFormat.week: '주간',
                  },
                  daysOfWeekStyle: DaysOfWeekStyle(
                    dowTextFormatter: (date, locale) {
                      final weekday = date.weekday;
                      const days = ['월', '화', '수', '목', '금', '토', '일'];
                      return days[weekday - 1];
                    },
                  ),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: true,
                    titleCentered: true,
                    titleTextFormatter: (date, locale) => DateFormat('yyyy년 M월', 'ko_KR').format(date),
                    leftChevronIcon: Icon(Icons.chevron_left, color: theme.colorScheme.primary),
                    rightChevronIcon: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
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
                    markerDecoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    markersMaxCount: 3,
                  ),
                ),
              );
            },
            loading: () => const SizedBox(height: 150, child: MathLoader()),
            error: (err, stack) => Center(child: Text('달력 로드 오류: $err')),
          ),
          
          const Divider(height: 1),

          // Date Schedules List
          Expanded(
            child: dateSchedulesAsync.when(
              data: (schedules) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$dateStr 일정 목록',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '일정: ${schedules.length}건',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: schedules.isEmpty
                          ? Center(
                              child: Text(
                                '선택된 날짜에 등록된 일정이 없습니다.',
                                style: theme.textTheme.bodyMedium,
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: schedules.length,
                              itemBuilder: (context, index) {
                                final s = schedules[index];
                                Color typeColor;
                                String typeKr;

                                if (s.type == 'EXAM') {
                                  typeColor = theme.colorScheme.primary;
                                  typeKr = '시험';
                                } else if (s.type == 'LEAVE') {
                                  typeColor = const Color(0xFF9C27B0);
                                  typeKr = '휴원';
                                } else if (s.type == 'CONSULT') {
                                  typeColor = const Color(0xFFFF9800);
                                  typeKr = '상담';
                                } else {
                                  typeColor = Colors.teal;
                                  typeKr = '기타';
                                }

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: MathCard(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: typeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: typeColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            typeKr,
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: typeColor,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.title,
                                                style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                              ),
                                              if (s.memo != null && s.memo!.trim().isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  s.memo!,
                                                  style: theme.textTheme.bodySmall,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Color(0xFFEF5350), size: 18),
                                          onPressed: () => _deleteSchedule(s.id),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
              loading: () => const MathLoader(message: '일정을 가져오는 중...'),
              error: (err, stack) => Center(child: Text('일정 로드 오류: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddScheduleDialog(context, dateStr),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.add_task),
      ),
    );
  }
  void _deleteSchedule(String id) async {
    await ref.read(settingsRepositoryProvider).deleteSchedule(id);
    ref.invalidate(dateSchedulesStreamProvider);
    ref.invalidate(allSchedulesStreamProvider);
  }

  void _showAddScheduleDialog(BuildContext context, String defaultDate) {
    final titleController = TextEditingController();
    final memoController = TextEditingController();
    String selectedType = 'CONSULT'; // Default
    int selectedTabIndex = 0; // 0: 일정 추가, 1: 기간 설정

    // Tab 1 state
    DateTime singleDate = DateTime.parse(defaultDate);

    // Tab 2 state
    DateTime startDate = DateTime.parse(defaultDate);
    DateTime endDate = DateTime.parse(defaultDate);
    String repeatType = 'NO_REPEAT'; // 'NO_REPEAT', 'WEEKLY', 'MONTHLY', 'YEARLY'
    final Set<int> selectedWeekdays = {startDate.weekday};
    int selectedDayOfMonth = startDate.day;
    int selectedYearlyMonth = startDate.month;
    int selectedYearlyDay = startDate.day;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            final theme = Theme.of(context);

            Widget buildWeekdaySelector() {
              final weekdaysText = ['월', '화', '수', '목', '금', '토', '일'];
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (index) {
                  final day = index + 1;
                  final isSelected = selectedWeekdays.contains(day);
                  return InkWell(
                    onTap: () {
                      setStateDialog(() {
                        if (selectedWeekdays.contains(day)) {
                          if (selectedWeekdays.length > 1) {
                            selectedWeekdays.remove(day);
                          }
                        } else {
                          selectedWeekdays.add(day);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: isSelected ? theme.colorScheme.primary : Colors.grey.shade200,
                      child: Text(
                        weekdaysText[index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }),
              );
            }

            return AlertDialog(
              title: const Text('신규 일정 추가'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: '일정명',
                        hintText: '예: 기말고사 피드백 상담',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(labelText: '일정 분류'),
                      items: const [
                        DropdownMenuItem(value: 'EXAM', child: Text('시험 일정')),
                        DropdownMenuItem(value: 'LEAVE', child: Text('휴원 일정')),
                        DropdownMenuItem(value: 'CONSULT', child: Text('상담 일정')),
                        DropdownMenuItem(value: 'OTHER', child: Text('기타 일정')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setStateDialog(() {
                            selectedType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: memoController,
                      decoration: const InputDecoration(
                        labelText: '상세 내용 (선택)',
                        hintText: '예: 학부모 동반 참석',
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Custom Tab Bar
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setStateDialog(() {
                                selectedTabIndex = 0;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selectedTabIndex == 0
                                        ? theme.colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                '일정 추가',
                                style: TextStyle(
                                  color: selectedTabIndex == 0
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                  fontWeight: selectedTabIndex == 0
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              setStateDialog(() {
                                selectedTabIndex = 1;
                              });
                            },
                            child: Container(
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: selectedTabIndex == 1
                                        ? theme.colorScheme.primary
                                        : Colors.grey.shade300,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Text(
                                '기간 설정',
                                style: TextStyle(
                                  color: selectedTabIndex == 1
                                      ? theme.colorScheme.primary
                                      : Colors.grey,
                                  fontWeight: selectedTabIndex == 1
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Tab Body
                    if (selectedTabIndex == 0) ...[
                      // Tab 1: Single Date
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: singleDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                            locale: const Locale('ko', 'KR'),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              singleDate = picked;
                            });
                          }
                        },
                        child: Text(
                          '날짜: ${DateFormat('yyyy-MM-dd').format(singleDate)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      // Tab 2: Range / Repeating Event
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2030),
                                  locale: const Locale('ko', 'KR'),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate;
                                    }
                                  });
                                }
                              },
                              child: Column(
                                children: [
                                  const Text('시작일', style: TextStyle(fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(startDate),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime(2030),
                                  locale: const Locale('ko', 'KR'),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    endDate = picked;
                                  });
                                }
                              },
                              child: Column(
                                children: [
                                  const Text('종료일', style: TextStyle(fontSize: 10)),
                                  const SizedBox(height: 2),
                                  Text(
                                    DateFormat('yyyy-MM-dd').format(endDate),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: repeatType,
                        decoration: const InputDecoration(labelText: '반복 설정'),
                        items: const [
                          DropdownMenuItem(value: 'NO_REPEAT', child: Text('반복 없음 (선택 기간 등록)')),
                          DropdownMenuItem(value: 'WEEKLY', child: Text('매주 반복')),
                          DropdownMenuItem(value: 'MONTHLY', child: Text('매월 반복')),
                          DropdownMenuItem(value: 'YEARLY', child: Text('매년 반복')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() {
                              repeatType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (repeatType == 'WEEKLY') ...[
                        Text(
                          '반복 요일 선택',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        buildWeekdaySelector(),
                      ] else if (repeatType == 'MONTHLY') ...[
                        DropdownButtonFormField<int>(
                          value: selectedDayOfMonth,
                          decoration: const InputDecoration(labelText: '반복 일 (매월)'),
                          items: List.generate(31, (index) => index + 1)
                              .map((day) => DropdownMenuItem(value: day, child: Text('$day일')))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() {
                                selectedDayOfMonth = val;
                              });
                            }
                          },
                        ),
                      ] else if (repeatType == 'YEARLY') ...[
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedYearlyMonth,
                                decoration: const InputDecoration(labelText: '반복 월'),
                                items: List.generate(12, (index) => index + 1)
                                    .map((m) => DropdownMenuItem(value: m, child: Text('$m월')))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setStateDialog(() {
                                      selectedYearlyMonth = val;
                                      final maxDays = DateUtils.getDaysInMonth(DateTime.now().year, val);
                                      if (selectedYearlyDay > maxDays) {
                                        selectedYearlyDay = maxDays;
                                      }
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                value: selectedYearlyDay,
                                decoration: const InputDecoration(labelText: '반복 일'),
                                items: List.generate(31, (index) => index + 1)
                                    .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setStateDialog(() {
                                      selectedYearlyDay = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
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
                    if (title.isEmpty) return;

                    final List<Future<void>> futures = [];
                    final memo = memoController.text.trim().isEmpty ? null : memoController.text.trim();

                    if (selectedTabIndex == 0) {
                      // Tab 1: Single Date
                      final dateStr = DateFormat('yyyy-MM-dd').format(singleDate);
                      futures.add(ref.read(settingsRepositoryProvider).addSchedule(
                        title: title,
                        date: dateStr,
                        type: selectedType,
                        memo: memo,
                      ));
                    } else {
                      // Tab 2: Range / Repeating
                      final daysCount = endDate.difference(startDate).inDays;
                      for (int i = 0; i <= daysCount; i++) {
                        final targetDate = startDate.add(Duration(days: i));
                        
                        bool shouldAdd = false;
                        if (repeatType == 'NO_REPEAT') {
                          shouldAdd = true;
                        } else if (repeatType == 'WEEKLY') {
                          shouldAdd = selectedWeekdays.contains(targetDate.weekday);
                        } else if (repeatType == 'MONTHLY') {
                          shouldAdd = targetDate.day == selectedDayOfMonth;
                        } else if (repeatType == 'YEARLY') {
                          shouldAdd = targetDate.month == selectedYearlyMonth && targetDate.day == selectedYearlyDay;
                        }

                        if (shouldAdd) {
                          final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
                          futures.add(ref.read(settingsRepositoryProvider).addSchedule(
                            title: title,
                            date: dateStr,
                            type: selectedType,
                            memo: memo,
                          ));
                        }
                      }
                    }

                    if (futures.isNotEmpty) {
                      await Future.wait(futures);
                    }

                    ref.invalidate(dateSchedulesStreamProvider);
                    ref.invalidate(allSchedulesStreamProvider);
                    Navigator.pop(context);
                  },
                  child: const Text('등록'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ==========================================
// TAB 2: ACADEMY STATISTICS
// ==========================================
class _AcademyStatsTab extends ConsumerWidget {
  const _AcademyStatsTab();

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

  Widget _buildStatsGroupFilter(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final selectedGroupId = ref.watch(settingsExamGroupFilterProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return groupsAsync.maybeWhen(
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Icon(Icons.filter_list_rounded, color: theme.colorScheme.primary, size: 20),
                const SizedBox(width: 12),
                Text(
                  '시험 분석 그룹:',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: selectedGroupId,
                      isExpanded: true,
                      dropdownColor: theme.colorScheme.surface,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text(
                            '전체 시험 (합산)',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...groups.map((g) {
                          final color = _parseColor(g.colorHex);
                          return DropdownMenuItem<String?>(
                            value: g.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  g.name,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        ref.read(settingsExamGroupFilterProvider.notifier).state = val;
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(academyStatsStreamProvider);
    final theme = Theme.of(context);
    
    final selectedGroupId = ref.watch(settingsExamGroupFilterProvider);
    final allGroups = ref.watch(examGroupsStreamProvider).value ?? [];
    final selectedGroup = allGroups.firstWhere(
      (g) => g.id == selectedGroupId,
      orElse: () => const ExamGroup(id: '', name: '', colorHex: '', orderIndex: 0),
    );
    final groupColor = selectedGroupId != null && selectedGroup.colorHex.isNotEmpty
        ? _parseColor(selectedGroup.colorHex)
        : theme.colorScheme.primary;

    return Scaffold(
      body: statsAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Exam Group Selector
                _buildStatsGroupFilter(context, ref),
                const SizedBox(height: 16),

                // 1. Grade stats table card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '학년별 평균 분석',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selectedGroupId != null ? groupColor : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MathCard(
                  padding: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 28,
                        columns: const [
                          DataColumn(label: Text('학년')),
                          DataColumn(label: Text('시험 평균')),
                          DataColumn(label: Text('출석률')),
                          DataColumn(label: Text('과제 완료율')),
                        ],
                        rows: stats.gradeStats.map((gs) {
                          return DataRow(
                            cells: [
                              DataCell(Text(_formatGrade(gs.grade), style: const TextStyle(fontWeight: FontWeight.bold))),
                              DataCell(Text('${gs.averageScore.toStringAsFixed(1)}점')),
                              DataCell(Text('${(gs.attendanceRate * 100).toStringAsFixed(0)}%')),
                              DataCell(Text('${(gs.homeworkRate * 100).toStringAsFixed(0)}%')),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 2. Score Rankings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '성적 명예의 전당 (평균 점수 기준)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selectedGroupId != null ? groupColor : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MathCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stats.scoreRankings.take(5).length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = stats.scoreRankings[index];
                      final rank = index + 1;
                      return ListTile(
                        leading: _buildRankCircle(context, rank),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_formatGrade(item.grade)),
                        trailing: Text(
                          '${item.value.toStringAsFixed(1)}점',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: groupColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // 3. Growth Rankings
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '성장률 랭킹',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: selectedGroupId != null ? groupColor : null,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                MathCard(
                  padding: EdgeInsets.zero,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: stats.growthRankings.take(5).length,
                    separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (context, index) {
                      final item = stats.growthRankings[index];
                      final rank = index + 1;
                      final isPositive = item.value > 0;
                      return ListTile(
                        leading: _buildRankCircle(context, rank),
                        title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(_formatGrade(item.grade)),
                        trailing: Text(
                          (isPositive ? '+' : '') + '${item.value.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPositive ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const MathLoader(message: '학원 성적 통계를 연산하는 중...'),
        error: (err, stack) => Center(child: Text('통계 로드 에러: $err')),
      ),
    );
  }

  Widget _buildRankCircle(BuildContext context, int rank) {
    Color color;
    if (rank == 1) {
      color = const Color(0xFFFBC02D);
    } else if (rank == 2) {
      color = Colors.grey.shade500;
    } else if (rank == 3) {
      color = const Color(0xFF8D6E63);
    } else {
      color = Colors.grey.shade300;
    }
    return CircleAvatar(
      radius: 12,
      backgroundColor: color.withOpacity(0.15),
      child: Text(
        '$rank',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
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

// ==========================================
// TAB 3: SYSTEM SETTINGS (BACKUP & RESTORE)
// ==========================================
class _SystemSettingsTab extends ConsumerWidget {
  const _SystemSettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Academy Profile Card
            MathCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.school, color: theme.colorScheme.primary, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Math Manager Academy',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text('학원용 모바일 수학 관리 솔루션'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Settings options list
            MathCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.brightness_medium),
                    title: const Text('테마 모드 설정'),
                    subtitle: Text(themeMode == ThemeMode.dark ? '다크 모드 적용 중' : '라이트 모드 적용 중'),
                    trailing: _ThemeToggleSwitch(
                      themeMode: themeMode,
                      onChanged: (isDark) {
                        ref.read(themeModeProvider.notifier).setThemeMode(
                          isDark ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.assessment_outlined),
                    title: const Text('시험 통합 관리'),
                    subtitle: const Text('모든 시험 기록을 검색, 필터링 및 일괄 이동/삭제합니다.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/settings/exam-management');
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.arrow_upward),
                    title: const Text('학년 일괄 진급'),
                    subtitle: const Text('새 학기를 맞아 모든 학생들의 학년을 한 단계씩 올립니다.'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      context.push('/settings/promote');
                    },
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('앱 버전 정보'),
                    trailing: Text('v1.0.0 (Release)'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    subtitle: const Text('계정에서 로그아웃합니다.'),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('로그아웃'),
                          content: const Text('정말로 로그아웃 하시겠습니까?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('로그아웃', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authNotifierProvider.notifier).signOut();
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggleSwitch extends StatelessWidget {
  final ThemeMode themeMode;
  final ValueChanged<bool> onChanged;

  const _ThemeToggleSwitch({
    required this.themeMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => onChanged(!isDark),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 60,
        height: 30,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDark ? theme.colorScheme.primary : Colors.grey.shade300,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 250),
          alignment: isDark ? Alignment.centerRight : Alignment.centerLeft,
          curve: Curves.easeInOut,
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                size: 14,
                color: isDark ? theme.colorScheme.primary : Colors.orange,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
