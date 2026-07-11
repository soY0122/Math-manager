import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/exam_providers.dart';
import '../domain/models/exam_models.dart';
import 'test_add_screen.dart'; // to reuse InlineGroupFormDialog
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';

class ExamManagementScreen extends ConsumerStatefulWidget {
  const ExamManagementScreen({super.key});

  @override
  ConsumerState<ExamManagementScreen> createState() => _ExamManagementScreenState();
}

class _ExamManagementScreenState extends ConsumerState<ExamManagementScreen> {
  // Search & Filter State
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedGroupId; // null means 'All'
  String? _selectedYear;    // null means 'All'
  String? _selectedMonth;   // null means 'All'
  
  // Sort State
  // Options: 'newest', 'oldest', 'name', 'avgScore', 'studentCount'
  String _sortBy = 'newest';

  // Selection State
  final Set<String> _selectedExamIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(examsListStreamProvider);
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 통합 관리'),
        actions: [
          if (_selectedExamIds.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.drive_file_move_outlined),
              onPressed: () => _showBulkMoveDialog(context),
              tooltip: '선택한 시험 그룹 이동',
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFEF5350)),
              onPressed: () => _showBulkDeleteDialog(context),
              tooltip: '선택한 시험 일괄 삭제',
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
      body: examsAsync.when(
        data: (exams) {
          final groups = groupsAsync.value ?? [];

          // Derive available Years and Months from data
          final List<String> years = [];
          for (final e in exams) {
            if (e.date.length >= 4) {
              final y = e.date.substring(0, 4);
              if (!years.contains(y)) years.add(y);
            }
          }
          years.sort((a, b) => b.compareTo(a));

          final List<String> months = List.generate(12, (i) => (i + 1).toString().padLeft(2, '0'));

          // Filter Exams
          final filteredExams = exams.where((e) {
            // Search Query Filter
            final matchQuery = e.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.examGroupName.toLowerCase().contains(_searchQuery.toLowerCase());
            
            // Group Filter
            final matchGroup = _selectedGroupId == null || e.examGroupId == _selectedGroupId;

            // Date Filters
            bool matchYear = true;
            bool matchMonth = true;
            if (e.date.length >= 10) {
              final y = e.date.substring(0, 4);
              final m = e.date.substring(5, 7);
              if (_selectedYear != null) matchYear = (y == _selectedYear);
              if (_selectedMonth != null) matchMonth = (m == _selectedMonth);
            } else {
              if (_selectedYear != null || _selectedMonth != null) {
                matchYear = false;
                matchMonth = false;
              }
            }

            return matchQuery && matchGroup && matchYear && matchMonth;
          }).toList();

          // Sort Exams
          if (_sortBy == 'newest') {
            filteredExams.sort((a, b) => b.date.compareTo(a.date));
          } else if (_sortBy == 'oldest') {
            filteredExams.sort((a, b) => a.date.compareTo(b.date));
          } else if (_sortBy == 'name') {
            filteredExams.sort((a, b) => a.title.compareTo(b.title));
          } else if (_sortBy == 'avgScore') {
            filteredExams.sort((a, b) => b.averageScore.compareTo(a.averageScore));
          } else if (_sortBy == 'studentCount') {
            filteredExams.sort((a, b) => b.studentCount.compareTo(a.studentCount));
          }

          // Statistics Calculations
          final totalExams = filteredExams.length;
          final uniqueGroupIds = filteredExams.map((e) => e.examGroupId).where((id) => id.isNotEmpty).toSet();
          final totalGroups = uniqueGroupIds.length;
          final totalRecords = filteredExams.fold<int>(0, (sum, e) => sum + e.studentCount);
          
          final totalStudentsForAvg = filteredExams.fold<int>(0, (sum, e) => sum + e.studentCount);
          final totalScoreSum = filteredExams.fold<double>(0.0, (sum, e) => sum + (e.averageScore * e.studentCount));
          final avgScore = totalStudentsForAvg > 0 ? totalScoreSum / totalStudentsForAvg : 0.0;

          return Column(
            children: [
              // 1. Statistics Cards at Top
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    Expanded(child: _buildStatCard(context, '총 시험', '$totalExams개', theme.colorScheme.primary)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(context, '활성 그룹', '$totalGroups개', const Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(context, '총 기록 수', '$totalRecords건', const Color(0xFFF59E0B))),
                    const SizedBox(width: 8),
                    Expanded(child: _buildStatCard(context, '필터 평균', ExamScoreFormatter.formatPercentage(avgScore), const Color(0xFF8B5CF6))),
                  ],
                ),
              ),

              // 2. Search & Filter Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '시험명 또는 그룹명 검색...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12.0)),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Group Filter Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: '그룹 필터',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('모든 그룹'),
                              ),
                              ...groups.map((g) {
                                return DropdownMenuItem<String>(
                                  value: g.id,
                                  child: Text(g.name),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedGroupId = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Year Filter Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedYear,
                            decoration: const InputDecoration(
                              labelText: '연도',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('전체'),
                              ),
                              ...years.map((y) {
                                return DropdownMenuItem<String>(
                                  value: y,
                                  child: Text('${y}년'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedYear = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Month Filter Dropdown
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedMonth,
                            decoration: const InputDecoration(
                              labelText: '월',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('전체'),
                              ),
                              ...months.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m,
                                  child: Text('${int.parse(m)}월'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedMonth = val;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Sorting selector & Select All
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: filteredExams.isNotEmpty && _selectedExamIds.length == filteredExams.length,
                              tristate: _selectedExamIds.isNotEmpty && _selectedExamIds.length < filteredExams.length,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedExamIds.addAll(filteredExams.map((e) => e.id));
                                  } else {
                                    _selectedExamIds.clear();
                                  }
                                });
                              },
                            ),
                            const Text('전체 선택', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                        // Sort Dropdown
                        Row(
                          children: [
                            const Text('정렬: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(width: 4),
                            DropdownButton<String>(
                              value: _sortBy,
                              underline: const SizedBox(),
                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                              items: const [
                                DropdownMenuItem(value: 'newest', child: Text('최신순')),
                                DropdownMenuItem(value: 'oldest', child: Text('과거순')),
                                DropdownMenuItem(value: 'name', child: Text('이름순')),
                                DropdownMenuItem(value: 'avgScore', child: Text('평균점수순')),
                                DropdownMenuItem(value: 'studentCount', child: Text('인원순')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _sortBy = val;
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // 3. Exams List View
              Expanded(
                child: filteredExams.isEmpty
                    ? const Center(
                        child: Text(
                          '필터 조건에 부합하는 시험 기록이 없습니다.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                        itemCount: filteredExams.length,
                        itemBuilder: (context, index) {
                          final exam = filteredExams[index];
                          final isSelected = _selectedExamIds.contains(exam.id);
                          final gColor = _parseColor(exam.examGroupColorHex);
                          final gTextColor = gColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12.0),
                            child: MathCard(
                              onTap: () => _showEditDialog(context, ref, exam),
                              padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                              child: Row(
                                children: [
                                  // Selection Checkbox
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: (checked) {
                                      setState(() {
                                        if (checked == true) {
                                          _selectedExamIds.add(exam.id);
                                        } else {
                                          _selectedExamIds.remove(exam.id);
                                        }
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  // Exam Content Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                exam.title,
                                                style: theme.textTheme.titleSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (exam.examGroupName.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: gColor,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  exam.examGroupName,
                                                  style: TextStyle(
                                                    color: gTextColor,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          '날짜: ${exam.date} • 참여 인원: ${exam.studentCount}명',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            _buildRowIndicator(
                                              context, 
                                              '평균', 
                                              ExamScoreFormatter.formatStats(exam.averageScore, exam.averageScore * exam.maxPossibleScore / 100, exam.maxPossibleScore), 
                                              theme.colorScheme.primary
                                            ),
                                            _buildRowIndicator(
                                              context, 
                                              '최고', 
                                              ExamScoreFormatter.formatStats(ExamScoreFormatter.calculatePercentage(exam.maxScore, exam.maxPossibleScore), exam.maxScore.toDouble(), exam.maxPossibleScore), 
                                              const Color(0xFF4CAF50)
                                            ),
                                            _buildRowIndicator(
                                              context, 
                                              '최저', 
                                              ExamScoreFormatter.formatStats(ExamScoreFormatter.calculatePercentage(exam.minScore, exam.maxPossibleScore), exam.minScore.toDouble(), exam.maxPossibleScore), 
                                              const Color(0xFFEF5350)
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
        loading: () => const MathLoader(message: '시험 정보를 불러오는 중...'),
        error: (err, _) => Center(child: Text('조회 오류 발생: $err')),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowIndicator(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11, color: Colors.grey.shade600),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  // --- Bulk Action Dialogs ---
  void _showBulkMoveDialog(BuildContext context) {
    final groups = ref.read(examGroupsStreamProvider).value ?? [];
    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이동시킬 다른 시험 그룹이 존재하지 않습니다.')),
      );
      return;
    }

    String selectedTargetGroupId = groups.first.id;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('시험 그룹 일괄 이동 (${_selectedExamIds.length}개 선택됨)'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('선택한 시험들을 아래의 그룹으로 일괄 이동하시겠습니까?'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedTargetGroupId,
                    decoration: const InputDecoration(
                      labelText: '이동할 대상 그룹',
                      border: OutlineInputBorder(),
                    ),
                    items: groups.map((g) {
                      return DropdownMenuItem<String>(
                        value: g.id,
                        child: Text(g.name),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          selectedTargetGroupId = val;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    try {
                      // Execute bulk update of examGroupId for all selected exams
                      for (final examId in _selectedExamIds) {
                        // Obtain existing title and date to call updateExam
                        final exam = ref.read(examsListStreamProvider).value?.firstWhere((e) => e.id == examId);
                        if (exam != null) {
                          await ref.read(examRepositoryProvider).updateExam(
                            examId,
                            exam.title,
                            exam.date,
                            selectedTargetGroupId,
                          );
                        }
                      }
                      ref.invalidate(examsListStreamProvider);
                      setState(() {
                        _selectedExamIds.clear();
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('선택한 시험들의 그룹이 일괄 이동되었습니다.')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('이동 처리 실패: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('이동 완료'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBulkDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            '시험 일괄 삭제 (${_selectedExamIds.length}개 선택됨)',
            style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('선택한 ${_selectedExamIds.length}개의 시험을 일괄 삭제하시겠습니까?'),
              const SizedBox(height: 8),
              const Text('각 시험에 기록된 학생들의 모든 성적 기록도 함께 일괄 영구 삭제됩니다.'),
              const SizedBox(height: 12),
              Text(
                '주의: 삭제된 성적 데이터는 복구할 수 없습니다.',
                style: TextStyle(color: Colors.red.shade600, fontSize: 12, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                try {
                  for (final examId in _selectedExamIds) {
                    await ref.read(examRepositoryProvider).deleteExam(examId);
                  }
                  ref.invalidate(examsListStreamProvider);
                  setState(() {
                    _selectedExamIds.clear();
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('선택한 시험들이 일괄 삭제되었습니다.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('삭제 실패: $e')),
                    );
                  }
                }
              },
              child: const Text('일괄 삭제 완료'),
            ),
          ],
        );
      },
    );
  }

  // --- Reused Edit Dialog from test_screen.dart ---
  void _showEditDialog(BuildContext context, WidgetRef ref, ExamOverview exam) {
    final titleController = TextEditingController(text: exam.title);
    final dateController = TextEditingController(text: exam.date);
    final maxScoreController = TextEditingController(text: exam.maxPossibleScore.toString());
    final formKey = GlobalKey<FormState>();
    String? selectedGroupId = exam.examGroupId.isEmpty ? null : exam.examGroupId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final currentGroups = ref.read(examGroupsStreamProvider).value ?? [];
            final theme = Theme.of(context);

            return AlertDialog(
              title: const Text('시험 정보 수정'),
              content: SingleChildScrollView(
                child: Form(
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
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: maxScoreController,
                        decoration: const InputDecoration(labelText: '시험 만점 (최대 점수) *'),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return '시험 만점(최대 점수)을 입력하세요';
                          }
                          final score = int.tryParse(val.trim());
                          if (score == null || score <= 0) {
                            return '올바른 점수(0 초과 정수)를 입력하세요';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Group selection field
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedGroupId,
                              decoration: const InputDecoration(
                                labelText: '시험 그룹 *',
                                prefixIcon: Icon(Icons.folder_outlined),
                              ),
                              hint: const Text('시험 그룹을 선택하세요'),
                              items: currentGroups.map((g) {
                                final gColor = _parseColor(g.colorHex);
                                return DropdownMenuItem<String>(
                                  value: g.id,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 12,
                                        height: 12,
                                        decoration: BoxDecoration(
                                          color: gColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        g.name,
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    selectedGroupId = val;
                                  });
                                }
                              },
                              validator: (val) => (val == null || val.isEmpty) ? '시험 그룹을 선택해야 합니다.' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          IconButton.filled(
                            onPressed: () {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => InlineGroupFormDialog(ref: ref),
                              ).then((newGroupId) {
                                if (newGroupId != null && newGroupId is String) {
                                  ref.invalidate(examGroupsStreamProvider);
                                  Future.delayed(const Duration(milliseconds: 100), () {
                                    if (context.mounted) {
                                      setState(() {
                                        selectedGroupId = newGroupId;
                                      });
                                    }
                                  });
                                }
                              });
                            },
                            icon: const Icon(Icons.add_rounded),
                            tooltip: '새 시험 그룹 만들기',
                            style: IconButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              minimumSize: const Size(48, 48),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
                            selectedGroupId!,
                            maxPossibleScore: int.tryParse(maxScoreController.text.trim()) ?? 100,
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
      },
    );
  }
}
