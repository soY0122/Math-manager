import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/exam_providers.dart';
import '../domain/models/exam_models.dart';
import '../../../core/widgets/math_card.dart';
import '../../../core/widgets/math_loader.dart';

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
  final List<FocusNode> _focusNodes = [];

  void _updateFocusNodesCount(int count) {
    if (_focusNodes.length == count) return;
    if (_focusNodes.length < count) {
      final diff = count - _focusNodes.length;
      for (int i = 0; i < diff; i++) {
        _focusNodes.add(FocusNode());
      }
    } else {
      final diff = _focusNodes.length - count;
      for (int i = 0; i < diff; i++) {
        _focusNodes.removeLast().dispose();
      }
    }
  }

  @override
  void dispose() {
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoresAsync = ref.watch(examScoresStreamProvider(widget.examId));
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('성적 기록 입력'),
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

          _updateFocusNodesCount(scores.length);

          return SafeArea(
            child: Column(
              children: [
                // Info header card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  color: isDark ? theme.colorScheme.surface : const Color(0xFFF8FAFC),
                  child: Text(
                    '각 학생의 시험 점수를 입력하세요.\n입력이 끝나고 다음(Next)을 누르거나 필드를 벗어나면 자동으로 저장됩니다.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: scores.length,
                    itemBuilder: (context, index) {
                      final item = scores[index];
                      return Padding(
                        key: ValueKey(item.studentId),
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: StudentScoreRow(
                          item: item,
                          focusNode: _focusNodes[index],
                          nextFocusNode: index < scores.length - 1 ? _focusNodes[index + 1] : null,
                          onSave: (val) => _saveScore(context, ref, item, val),
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

  void _saveScore(
    BuildContext context,
    WidgetRef ref,
    StudentExamScoreItem item,
    String textVal,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final scoreVal = int.tryParse(textVal);
    if (scoreVal == null || scoreVal < 0 || scoreVal > 100) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('점수는 0점에서 100점 사이의 숫자만 입력 가능합니다.'),
          backgroundColor: Color(0xFFEF5350),
        ),
      );
      return;
    }

    // Avoid redundant saves if score matches
    if (scoreVal == item.score) return;

    try {
      await ref.read(examRepositoryProvider).updateExamScore(
            examId: widget.examId,
            studentId: item.studentId,
            score: scoreVal,
            recordId: item.recordId,
          );
      messenger.showSnackBar(
        SnackBar(
          content: Text('${item.studentName}: ${scoreVal}점 저장되었습니다.'),
          duration: const Duration(milliseconds: 500),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('점수 저장 중 오류가 발생했습니다: $e'),
          backgroundColor: const Color(0xFFEF5350),
        ),
      );
    }
  }
}

class StudentScoreRow extends StatefulWidget {
  final StudentExamScoreItem item;
  final FocusNode focusNode;
  final FocusNode? nextFocusNode;
  final Function(String val) onSave;

  const StudentScoreRow({
    super.key,
    required this.item,
    required this.focusNode,
    this.nextFocusNode,
    required this.onSave,
  });

  @override
  State<StudentScoreRow> createState() => _StudentScoreRowState();
}

class _StudentScoreRowState extends State<StudentScoreRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.item.score > 0 ? '${widget.item.score}' : '0',
    );
  }

  @override
  void didUpdateWidget(covariant StudentScoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.focusNode.hasFocus) {
      final newText = widget.item.score > 0 ? '${widget.item.score}' : '0';
      if (_controller.text != newText) {
        _controller.text = newText;
      }
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

    return Focus(
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          widget.onSave(_controller.text.trim());
        }
      },
      child: MathCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.item.studentName,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatGrade(widget.item.grade),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color?.withOpacity(0.5),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.school,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 80,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.02) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF2E3135) : Colors.grey.shade300,
                ),
              ),
              child: TextFormField(
                controller: _controller,
                focusNode: widget.focusNode,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                textInputAction: widget.nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                onFieldSubmitted: (val) {
                  widget.onSave(val.trim());
                  if (widget.nextFocusNode != null) {
                    widget.nextFocusNode!.requestFocus();
                  } else {
                    widget.focusNode.unfocus();
                  }
                },
              ),
            ),
          ],
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
