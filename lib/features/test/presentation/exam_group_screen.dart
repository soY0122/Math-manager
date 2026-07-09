import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/exam_providers.dart';
import '../domain/models/exam_group_models.dart';
import '../../../core/widgets/math_loader.dart';

class ExamGroupScreen extends ConsumerStatefulWidget {
  const ExamGroupScreen({super.key});

  @override
  ConsumerState<ExamGroupScreen> createState() => _ExamGroupScreenState();
}

class _ExamGroupScreenState extends ConsumerState<ExamGroupScreen> {
  bool _isReordering = false;

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('시험 그룹 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showGroupFormDialog(context, ref, null),
            tooltip: '새 그룹 추가',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: groupsAsync.when(
        data: (groups) {
          if (groups.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 72,
                    color: theme.colorScheme.primary.withOpacity(0.4),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '등록된 시험 그룹이 없습니다.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '우측 상단 + 버튼을 눌러 새 그룹을 만들어보세요.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '목록을 길게 눌러 드래그 앤 드롭으로 시험 그룹 순서를 변경할 수 있습니다. 변경된 순서는 앱 전체에 반영됩니다.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    onReorderStart: (index) {
                      setState(() {
                        _isReordering = true;
                      });
                    },
                    onReorderEnd: (index) {
                      setState(() {
                        _isReordering = false;
                      });
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    itemCount: groups.length,
                    itemBuilder: (context, index) {
                      final group = groups[index];
                      final groupColor = _parseColor(group.colorHex);
                      return Card(
                        key: ValueKey(group.id),
                        margin: const EdgeInsets.only(bottom: 12.0),
                        elevation: _isReordering ? 8 : 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          leading: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: groupColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          title: Text(
                            group.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: groupColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    group.colorHex.toUpperCase(),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? groupColor.withOpacity(0.8) : groupColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined),
                                color: Colors.blue.shade600,
                                onPressed: () => _showGroupFormDialog(context, ref, group),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded),
                                color: Colors.red.shade600,
                                onPressed: () => _confirmDeleteGroup(context, ref, group),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.drag_handle_rounded, color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                    onReorder: (oldIndex, newIndex) async {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final List<ExamGroup> reorderedList = List.from(groups);
                      final ExamGroup movedItem = reorderedList.removeAt(oldIndex);
                      reorderedList.insert(newIndex, movedItem);

                      try {
                        await ref.read(examRepositoryProvider).reorderExamGroups(reorderedList);
                        ref.invalidate(examGroupsStreamProvider);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('순서 변경 실패: $e')),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const MathLoader(message: '그룹 목록을 불러오는 중...'),
        error: (err, _) => Center(child: Text('에러 발생: $err')),
      ),
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

  void _showGroupFormDialog(BuildContext context, WidgetRef ref, ExamGroup? group) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _GroupFormDialog(group: group, ref: ref),
    ).then((updated) {
      if (updated == true) {
        ref.invalidate(examGroupsStreamProvider);
        ref.invalidate(examsListStreamProvider);
      }
    });
  }

  void _confirmDeleteGroup(BuildContext context, WidgetRef ref, ExamGroup group) async {
    final exams = await ref.read(examRepositoryProvider).watchExams().first;
    final groupExams = exams.where((e) => e.examGroupId == group.id).toList();

    if (!context.mounted) return;

    if (groupExams.isEmpty) {
      // If the group contains no exams, delete it immediately.
      try {
        await ref.read(examRepositoryProvider).deleteExamGroup(group.id, deleteExams: false);
        ref.invalidate(examGroupsStreamProvider);
        ref.invalidate(examsListStreamProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('시험 그룹이 삭제되었습니다.')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('삭제 실패: $e')),
          );
        }
      }
    } else {
      // If the group contains exams, show dialog with three options: Cancel, Move, Delete.
      final allGroups = ref.read(examGroupsStreamProvider).value ?? [];
      final otherGroups = allGroups.where((g) => g.id != group.id).toList();

      showDialog(
        context: context,
        builder: (context) {
          String? targetGroupId = otherGroups.isNotEmpty ? otherGroups.first.id : null;
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('그룹 삭제 옵션 설정'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${group.name}" 그룹 내에 ${groupExams.length}개의 시험 기록이 존재합니다.',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    const Text('이 그룹을 어떻게 처리하시겠습니까?'),
                    if (otherGroups.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const Text('1. 다른 그룹으로 이동하여 보존:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: targetGroupId,
                        decoration: const InputDecoration(
                          labelText: '이동할 대상 그룹',
                          border: OutlineInputBorder(),
                        ),
                        items: otherGroups.map((g) {
                          return DropdownMenuItem<String>(
                            value: g.id,
                            child: Text(g.name),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            targetGroupId = val;
                          });
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 16),
                      const Text('(이동할 다른 그룹이 존재하지 않습니다)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                    const SizedBox(height: 20),
                    const Text('2. 이 그룹의 모든 시험 및 성적 삭제:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      '주의: 삭제된 모든 시험 정보 및 학생 성적 데이터는 영구히 복구할 수 없습니다.',
                      style: TextStyle(color: Colors.red.shade600, fontSize: 11),
                    ),
                  ],
                ),
                actions: [
                  // Option 1: Cancel
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('취소'),
                  ),
                  // Option 2: Move
                  if (otherGroups.isNotEmpty)
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await ref.read(examRepositoryProvider).deleteExamGroup(
                                group.id,
                                deleteExams: false,
                                moveGroupId: targetGroupId,
                              );
                          ref.invalidate(examGroupsStreamProvider);
                          ref.invalidate(examsListStreamProvider);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('시험 기록을 이동하고 그룹을 삭제했습니다.')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('이동 실패: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('이동 후 삭제'),
                    ),
                  // Option 3: Delete
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      try {
                        await ref.read(examRepositoryProvider).deleteExamGroup(
                              group.id,
                              deleteExams: true,
                            );
                        ref.invalidate(examGroupsStreamProvider);
                        ref.invalidate(examsListStreamProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('그룹 및 내부 시험이 일괄 삭제되었습니다.')),
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
                    child: const Text('일괄 전체 삭제'),
                  ),
                ],
              );
            },
          );
        },
      );
    }
  }
}

class _GroupFormDialog extends StatefulWidget {
  final ExamGroup? group;
  final WidgetRef ref;

  const _GroupFormDialog({required this.group, required this.ref});

  @override
  State<_GroupFormDialog> createState() => _GroupFormDialogState();
}

class _GroupFormDialogState extends State<_GroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _hexController;
  late Color _selectedColor;

  // Preset colors for quick picks
  final List<String> _presets = [
    '#3F51B5', // Indigo
    '#10B981', // Emerald
    '#F59E0B', // Orange
    '#F43F5E', // Rose
    '#8B5CF6', // Purple
    '#0D9488', // Teal
    '#EC4899', // Pink
    '#06B6D4', // Cyan
    '#EF4444', // Red
    '#10B981', // Green
    '#6366F1', // Indigo2
    '#64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    final initialColorHex = widget.group?.colorHex ?? '#3F51B5';
    _hexController = TextEditingController(text: initialColorHex.toUpperCase());
    _selectedColor = _parseColor(initialColorHex);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hexController.dispose();
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

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2, 8).toUpperCase()}';
  }

  void _onColorChanged(Color color) {
    setState(() {
      _selectedColor = color;
      _hexController.text = _colorToHex(color);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final luminance = _selectedColor.computeLuminance();
    final badgeTextColor = luminance > 0.5 ? Colors.black87 : Colors.white;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      title: Text(
        widget.group == null ? '새 시험 그룹 추가' : '시험 그룹 수정',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '그룹 이름',
                  hintText: '예: 학교 내신, 월간 고사, 모의고사 등',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline_rounded),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '그룹 이름을 입력해주세요.';
                  }
                  return null;
                },
                onChanged: (val) {
                  setState(() {}); // refresh preview
                },
              ),
              const SizedBox(height: 20),

              // Live Preview Badge
              Text(
                '미리보기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _selectedColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _nameController.text.trim().isEmpty ? '시험 그룹 이름' : _nameController.text,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: badgeTextColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Preset Quick Color Picks
              Text(
                '빠른 색상 선택',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: _presets.map((hex) {
                  final presetColor = _parseColor(hex);
                  final isSelected = _colorToHex(_selectedColor) == hex;
                  return GestureDetector(
                    onTap: () => _onColorChanged(presetColor),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: presetColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: presetColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Visual Hue & Saturation Pickers
              Text(
                '사용자 지정 색상 설정',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ColorPalettePicker(
                initialColor: _selectedColor,
                onColorChanged: _onColorChanged,
              ),
              const SizedBox(height: 16),

              // Manual HEX input
              TextFormField(
                controller: _hexController,
                decoration: const InputDecoration(
                  labelText: 'HEX 색상 코드',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.color_lens_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '색상 코드를 입력해주세요.';
                  }
                  final reg = RegExp(r'^#?([0-9a-fA-F]{6})$');
                  if (!reg.hasMatch(val)) {
                    return '올바른 HEX 코드 형태여야 합니다 (예: #FF3B30).';
                  }
                  return null;
                },
                onChanged: (val) {
                  final clean = val.trim();
                  if (clean.length == 7 && clean.startsWith('#') || clean.length == 6) {
                    final targetColor = _parseColor(clean);
                    setState(() {
                      _selectedColor = targetColor;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final name = _nameController.text.trim();
              final color = _colorToHex(_selectedColor);

              try {
                if (widget.group == null) {
                  await widget.ref.read(examRepositoryProvider).addExamGroup(name, color);
                } else {
                  await widget.ref.read(examRepositoryProvider).updateExamGroup(widget.group!.id, name, color);
                }
                if (context.mounted) {
                  Navigator.pop(context, true);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('실패: $e')),
                  );
                }
              }
            }
          },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

class _ColorPalettePicker extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPalettePicker({required this.initialColor, required this.onColorChanged});

  @override
  State<_ColorPalettePicker> createState() => _ColorPalettePickerState();
}

class _ColorPalettePickerState extends State<_ColorPalettePicker> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    _updateHSV(widget.initialColor);
  }

  @override
  void didUpdateWidget(covariant _ColorPalettePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialColor != widget.initialColor) {
      _updateHSV(widget.initialColor);
    }
  }

  void _updateHSV(Color color) {
    final hsv = HSVColor.fromColor(color);
    _hue = hsv.hue;
    _saturation = hsv.saturation;
    _value = hsv.value;
  }

  void _notifyColorChange() {
    final color = HSVColor.fromAHSV(1.0, _hue, _saturation, _value).toColor();
    widget.onColorChanged(color);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 280),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hue slider with linear gradient background representation
          Container(
            height: 12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: Slider(
              value: _hue,
              min: 0.0,
              max: 360.0,
              onChanged: (val) {
                setState(() {
                  _hue = val;
                });
                _notifyColorChange();
              },
            ),
          ),

          // Saturation / Shade Variations Grid selector
          const SizedBox(height: 8),
          Center(
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: List.generate(10, (index) {
                // Varying saturation (0.2 to 1.0) and value (0.4 to 1.0)
                final sat = 0.2 + (index % 5) * 0.2;
                final val = 1.0 - (index ~/ 5) * 0.3;
                final itemColor = HSVColor.fromAHSV(1.0, _hue, sat.clamp(0.0, 1.0), val.clamp(0.0, 1.0)).toColor();
                final isSelected = (_saturation - sat).abs() < 0.1 && (_value - val).abs() < 0.15;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _saturation = sat;
                      _value = val;
                    });
                    _notifyColorChange();
                  },
                  child: Container(
                    width: 48,
                    height: 32,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        width: isSelected ? 3.0 : 1.0,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
