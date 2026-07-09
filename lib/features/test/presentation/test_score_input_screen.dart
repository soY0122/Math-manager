import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/exam_providers.dart';
import '../domain/models/exam_models.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';
import 'dart:async';

class TestScoreInputScreen extends ConsumerStatefulWidget {
  final String examId;

  const TestScoreInputScreen({
    super.key,
    required this.examId,
  });

  @override
  ConsumerState<TestScoreInputScreen> createState() => _TestScoreInputScreenState();
}

class _TestScoreInputScreenState extends ConsumerState<TestScoreInputScreen> {
  // Sort State: 'registration', 'name', 'grade'
  String _sortBy = 'registration';

  // State maps to persist inputs and focus nodes across sorts/filters
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, Timer> _debounceTimers = {};
  final Map<String, bool> _savingStates = {};

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    for (final timer in _debounceTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  TextEditingController _getController(String studentId, int score, String? recordId) {
    return _controllers.putIfAbsent(studentId, () {
      final text = recordId == null ? '' : '$score';
      final controller = TextEditingController(text: text);
      // Listen to text changes for real-time validation and progress summary recalculations
      controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      return controller;
    });
  }

  FocusNode _getFocusNode(String studentId) {
    return _focusNodes.putIfAbsent(studentId, () => FocusNode());
  }

  void _onScoreChanged(String studentId, String text, StudentExamScoreItem item) {
    // Reset existing debounce timer
    _debounceTimers[studentId]?.cancel();

    // Enforce validation bounds
    final scoreVal = int.tryParse(text.trim());
    if (scoreVal == null || scoreVal < 0 || scoreVal > 100) {
      return; // Do not auto-save invalid scores
    }

    if (scoreVal == item.score) {
      return; // No changes to save
    }

    // Set saving status to true
    setState(() {
      _savingStates[studentId] = true;
    });

    _debounceTimers[studentId] = Timer(const Duration(milliseconds: 1000), () async {
      await _saveScoreDirect(studentId, scoreVal, item);
    });
  }

  Future<void> _saveScoreDirect(String studentId, int scoreVal, StudentExamScoreItem item) async {
    try {
      await ref.read(examRepositoryProvider).updateExamScore(
            examId: widget.examId,
            studentId: item.studentId,
            score: scoreVal,
            recordId: item.recordId,
          );
      // Invalidate stream to fetch the new recordId and sync
      ref.invalidate(examScoresStreamProvider(widget.examId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.studentName} 점수 저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingStates[studentId] = false;
        });
      }
    }
  }

  Future<void> _saveAll(List<StudentExamScoreItem> items) async {
    bool hasSaved = false;
    for (final item in items) {
      final text = _controllers[item.studentId]?.text.trim() ?? '';
      if (text.isEmpty) continue;
      
      final scoreVal = int.tryParse(text);
      if (scoreVal != null && scoreVal >= 0 && scoreVal <= 100 && scoreVal != item.score) {
        setState(() {
          _savingStates[item.studentId] = true;
        });
        await _saveScoreDirect(item.studentId, scoreVal, item);
        hasSaved = true;
      }
    }

    if (mounted && hasSaved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('모든 변경 사항이 저장되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(examScoresStreamProvider(widget.examId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('성적 기록 입력'),
        actions: [
          scoresAsync.maybeWhen(
            data: (scores) => TextButton.icon(
              icon: const Icon(Icons.save_rounded, color: Colors.white),
              label: const Text('전체 저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              onPressed: () => _saveAll(scores),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: scoresAsync.when(
        data: (scores) {
          if (scores.isEmpty) {
            return Center(
              child: Text(
                '시험에 해당하는 학년의 학생이 없습니다.',
                style: theme.textTheme.bodyMedium,
              ),
            );
          }

          // Compute Sort order
          final sortedScores = List<StudentExamScoreItem>.from(scores);
          if (_sortBy == 'name') {
            sortedScores.sort((a, b) => a.studentName.compareTo(b.studentName));
          } else if (_sortBy == 'grade') {
            sortedScores.sort((a, b) => a.grade.compareTo(b.grade));
          }

          // Statistics Calculations
          final totalStudents = sortedScores.length;
          
          int completed = 0;
          final List<StudentExamScoreItem> missingStudents = [];

          for (final item in sortedScores) {
            final controller = _getController(item.studentId, item.score, item.recordId);
            final text = controller.text.trim();
            if (text.isNotEmpty) {
              final parsed = int.tryParse(text);
              if (parsed != null && parsed >= 0 && parsed <= 100) {
                completed++;
                continue;
              }
            }
            missingStudents.add(item);
          }

          final remaining = totalStudents - completed;
          final isCompletedAll = remaining == 0;

          return SafeArea(
            child: Column(
              children: [
                // 1. Progress Summary Indicator
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatCard(context, '총 학생', '$totalStudents명', theme.colorScheme.primary),
                          _buildStatCard(context, '입력 완료', '$completed명', const Color(0xFF10B981)),
                          _buildStatCard(context, '남은 학생', '$remaining명', remaining > 0 ? const Color(0xFFF59E0B) : Colors.grey),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Sorting buttons
                      Row(
                        children: [
                          const Text('정렬: ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(width: 8),
                          Wrap(
                            spacing: 8.0,
                            children: [
                              ChoiceChip(
                                label: const Text('등록순'),
                                selected: _sortBy == 'registration',
                                onSelected: (val) {
                                  if (val) setState(() => _sortBy = 'registration');
                                },
                              ),
                              ChoiceChip(
                                label: const Text('이름순'),
                                selected: _sortBy == 'name',
                                onSelected: (val) {
                                  if (val) setState(() => _sortBy = 'name');
                                },
                              ),
                              ChoiceChip(
                                label: const Text('학년순'),
                                selected: _sortBy == 'grade',
                                onSelected: (val) {
                                  if (val) setState(() => _sortBy = 'grade');
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

                // 2. Collapsible Missing Scores Panel
                _MissingScoresPanel(
                  missingStudents: missingStudents,
                  focusNodes: _focusNodes,
                ),

                // 3. Completion Success Alert Indicator
                if (isCompletedAll)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: const Color(0xE8E8F5E9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade300),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.green, size: 24),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '모든 학생들의 시험 점수 입력이 완료되었습니다!',
                            style: TextStyle(
                              color: Color(0xFF2E7D32),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 4. Student Score Input List
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: sortedScores.length,
                    itemBuilder: (context, index) {
                      final item = sortedScores[index];
                      final controller = _getController(item.studentId, item.score, item.recordId);
                      final node = _getFocusNode(item.studentId);
                      
                      // Identify next node in sorted sequence to focus on enter
                      FocusNode? nextNode;
                      if (index < sortedScores.length - 1) {
                        nextNode = _getFocusNode(sortedScores[index + 1].studentId);
                      }

                      final isSaving = _savingStates[item.studentId] ?? false;

                      return Padding(
                        key: ValueKey(item.studentId),
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _StudentScoreInputRow(
                          item: item,
                          controller: controller,
                          focusNode: node,
                          nextFocusNode: nextNode,
                          isSaving: isSaving,
                          onChanged: (text) => _onScoreChanged(item.studentId, text, item),
                          onSave: (text) {
                            final scoreVal = int.tryParse(text.trim());
                            if (scoreVal != null && scoreVal >= 0 && scoreVal <= 100) {
                              _saveScoreDirect(item.studentId, scoreVal, item);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const MathLoader(message: '점수 기록을 불러오는 중...'),
        error: (err, stack) => Center(child: Text('성적 데이터를 조회할 수 없습니다: $err')),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
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
            const SizedBox(height: 2),
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
      ),
    );
  }
}

class _StudentScoreInputRow extends StatelessWidget {
  final StudentExamScoreItem item;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final bool isSaving;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSave;

  const _StudentScoreInputRow({
    required this.item,
    required this.controller,
    required this.focusNode,
    this.nextFocusNode,
    required this.isSaving,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Validate current input state
    final val = controller.text.trim();
    String? errorText;
    bool isMissing = false;

    if (val.isEmpty) {
      if (item.recordId == null) {
        isMissing = true;
      }
    } else {
      final parsed = int.tryParse(val);
      if (parsed == null) {
        errorText = '숫자만 입력';
      } else if (parsed < 0 || parsed > 100) {
        errorText = '0~100 사이';
      }
    }

    final isSaved = !isMissing && errorText == null && !isSaving && val.isNotEmpty && (int.tryParse(val) == item.score);

    // Dynamic background and border color for warnings
    Color? backgroundColor;
    BoxBorder rowBorder = Border.all(color: isDark ? const Color(0xFF2E3135) : Colors.grey.shade200);

    if (isMissing) {
      backgroundColor = isDark ? Colors.amber.shade900.withOpacity(0.15) : Colors.amber.shade50.withOpacity(0.4);
      rowBorder = Border.all(color: Colors.amber.shade300);
    } else if (errorText != null) {
      backgroundColor = isDark ? Colors.red.shade900.withOpacity(0.15) : Colors.red.shade50.withOpacity(0.4);
      rowBorder = Border.all(color: Colors.red.shade300);
    }

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          onSave(controller.text.trim());
        }
      },
      child: MathCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: rowBorder,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 1. Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          item.studentName,
                          style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatGrade(item.grade),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.school} • ${item.className}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Status Badge Indicator
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    if (isMissing) ...[
                      Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade700),
                      const SizedBox(width: 4),
                      Text('점수 미입력', style: TextStyle(color: Colors.amber.shade800, fontSize: 11, fontWeight: FontWeight.w600)),
                    ] else if (errorText != null) ...[
                      const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFEF5350)),
                      const SizedBox(width: 4),
                      Text(errorText, style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11, fontWeight: FontWeight.w600)),
                    ] else if (isSaving) ...[
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2.0),
                      ),
                      const SizedBox(width: 6),
                      const Text('저장 중...', style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.w600)),
                    ] else if (isSaved) ...[
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      const Text('저장됨', style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),

              // 3. Input Text Box
              Container(
                width: 76,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2E3135) : Colors.grey.shade300,
                  ),
                ),
                child: TextFormField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                  textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  onChanged: onChanged,
                  onFieldSubmitted: (val) {
                    onSave(val.trim());
                    if (nextFocusNode != null) {
                      nextFocusNode!.requestFocus();
                    } else {
                      focusNode.unfocus();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
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

class _MissingScoresPanel extends StatefulWidget {
  final List<StudentExamScoreItem> missingStudents;
  final Map<String, FocusNode> focusNodes;

  const _MissingScoresPanel({
    required this.missingStudents,
    required this.focusNodes,
  });

  @override
  State<_MissingScoresPanel> createState() => _MissingScoresPanelState();
}

class _MissingScoresPanelState extends State<_MissingScoresPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.missingStudents.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: MathCard(
        child: Column(
        children: [
          ListTile(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            dense: true,
            leading: Icon(Icons.assignment_late_outlined, color: Colors.amber.shade700, size: 20),
            title: Text(
              '미입력 학생 목록 (${widget.missingStudents.length}명)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            trailing: Icon(
              _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 20,
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.missingStudents.length,
                itemBuilder: (context, index) {
                  final s = widget.missingStudents[index];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    title: Text(
                      s.studentName,
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    subtitle: Text('${s.school} • 초${s.grade}', style: const TextStyle(fontSize: 11)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
                    onTap: () {
                      final node = widget.focusNodes[s.studentId];
                      if (node != null) {
                        node.requestFocus();
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
}
