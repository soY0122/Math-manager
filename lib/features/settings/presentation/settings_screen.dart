import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import 'providers/settings_providers.dart';
import '../domain/models/settings_models.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';
import 'package:table_calendar/table_calendar.dart';

final autoBackupEnabledProvider = StateProvider<bool>((ref) {
  final db = ref.watch(databaseProvider);
  return db.settingsBox.get('auto_backup_enabled', defaultValue: false) as bool;
});

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
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: true,
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

  void _deleteSchedule(int id) async {
    await ref.read(settingsRepositoryProvider).deleteSchedule(id);
    ref.invalidate(dateSchedulesStreamProvider);
    ref.invalidate(allSchedulesStreamProvider);
  }

  void _showAddScheduleDialog(BuildContext context, String defaultDate) {
    final titleController = TextEditingController();
    final memoController = TextEditingController();
    String selectedType = 'CONSULT'; // Default

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('신규 일정 추가'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
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
                ],
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

                    await ref.read(settingsRepositoryProvider).addSchedule(
                      title: title,
                      date: defaultDate,
                      type: selectedType,
                      memo: memoController.text.trim().isEmpty ? null : memoController.text.trim(),
                    );

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(academyStatsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: statsAsync.when(
        data: (stats) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Grade stats table card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    '학년별 평균 분석',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                            color: theme.colorScheme.primary,
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
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                    leading: const Icon(Icons.autorenew),
                    title: const Text('자동 백업'),
                    subtitle: const Text('앱을 닫을 때 데이터가 변경된 경우 매일 자동 백업'),
                    trailing: Switch(
                      value: ref.watch(autoBackupEnabledProvider),
                      onChanged: (val) async {
                        ref.read(autoBackupEnabledProvider.notifier).state = val;
                        final db = ref.read(databaseProvider);
                        await db.settingsBox.put('auto_backup_enabled', val);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.backup_outlined),
                    title: const Text('데이터 백업'),
                    subtitle: const Text('현재 데이터베이스를 로컬 백업 파일로 보관'),
                    onTap: () => _performBackup(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore_outlined),
                    title: const Text('데이터 복구'),
                    subtitle: const Text('백업 파일에서 데이터베이스를 복원'),
                    onTap: () => _confirmRestore(context, ref),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('앱 버전 정보'),
                    trailing: Text('v1.0.0 (Release)'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performBackup(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      
      // Copy all box contents into backupBox
      await db.backupBox.put('students', db.studentsBox.values.toList());
      await db.backupBox.put('attendances', db.attendancesBox.values.toList());
      await db.backupBox.put('homeworks', db.homeworksBox.values.toList());
      await db.backupBox.put('exams', db.examsBox.values.toList());
      await db.backupBox.put('exam_records', db.examRecordsBox.values.toList());
      await db.backupBox.put('schedules', db.schedulesBox.values.toList());
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('데이터베이스 백업이 완료되었습니다. (로컬 브라우저 저장소)')),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('백업 중 오류 발생: $e')),
      );
    }
  }

  void _confirmRestore(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('데이터 복구'),
          content: const Text('백업 파일에서 복구하시겠습니까?\n현재 저장된 모든 데이터가 백업 시점의 데이터로 덮어쓰기됩니다.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close confirm dialog
                await _performRestore(context, ref);
              },
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE53935)),
              child: const Text('복구 진행'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performRestore(BuildContext context, WidgetRef ref) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final db = ref.read(databaseProvider);
      
      final students = db.backupBox.get('students');
      if (students == null) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('백업 데이터를 찾을 수 없습니다. 먼저 백업을 실행해주세요.')),
        );
        return;
      }
      
      // Restore all boxes
      await db.studentsBox.clear();
      for (final s in (students as List)) {
        await db.studentsBox.put(s['id'], Map<String, dynamic>.from(s));
      }
      
      final attendances = db.backupBox.get('attendances') as List?;
      await db.attendancesBox.clear();
      if (attendances != null) {
        for (final a in attendances) {
          final map = Map<String, dynamic>.from(a);
          await db.attendancesBox.put('${map['student_id']}_${map['date']}', map);
        }
      }
      
      final homeworks = db.backupBox.get('homeworks') as List?;
      await db.homeworksBox.clear();
      if (homeworks != null) {
        for (final h in homeworks) {
          final map = Map<String, dynamic>.from(h);
          await db.homeworksBox.put('${map['student_id']}_${map['date']}', map);
        }
      }
      
      final exams = db.backupBox.get('exams') as List?;
      await db.examsBox.clear();
      if (exams != null) {
        for (final e in exams) {
          final map = Map<String, dynamic>.from(e);
          await db.examsBox.put(map['id'], map);
        }
      }
      
      final examRecords = db.backupBox.get('exam_records') as List?;
      await db.examRecordsBox.clear();
      if (examRecords != null) {
        for (final er in examRecords) {
          final map = Map<String, dynamic>.from(er);
          await db.examRecordsBox.put('${map['exam_id']}_${map['student_id']}', map);
        }
      }
      
      final schedules = db.backupBox.get('schedules') as List?;
      await db.schedulesBox.clear();
      if (schedules != null) {
        for (final s in schedules) {
          final map = Map<String, dynamic>.from(s);
          await db.schedulesBox.put(map['id'], map);
        }
      }

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              title: const Text('복구 성공'),
              content: const Text('데이터가 성공적으로 복구되었습니다.\n적용을 위해 앱을 완전히 다시 실행해 주세요.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('확인'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('복구 중 오류 발생: $e')),
      );
    }
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
