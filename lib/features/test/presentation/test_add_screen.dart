import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/exam_providers.dart';
import '../../../core/widgets/math_button.dart';
import '../../../core/widgets/math_text_field.dart';
import '../../../core/widgets/math_loader.dart';

class TestAddScreen extends ConsumerStatefulWidget {
  const TestAddScreen({super.key});

  @override
  ConsumerState<TestAddScreen> createState() => _TestAddScreenState();
}

class _TestAddScreenState extends ConsumerState<TestAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  final _maxScoreController = TextEditingController(text: '100');
  int _selectedGrade = 3; // Default: 초3
  String? _selectedGroupId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _dateController.dispose();
    _maxScoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(examGroupsStreamProvider);
    final theme = Theme.of(context);

    final gradeChoices = [
      _GradeDropdownItem(label: '초등학교 1학년', value: 1),
      _GradeDropdownItem(label: '초등학교 2학년', value: 2),
      _GradeDropdownItem(label: '초등학교 3학년', value: 3),
      _GradeDropdownItem(label: '초등학교 4학년', value: 4),
      _GradeDropdownItem(label: '초등학교 5학년', value: 5),
      _GradeDropdownItem(label: '초등학교 6학년', value: 6),
      _GradeDropdownItem(label: '중학교 1학년', value: 7),
      _GradeDropdownItem(label: '중학교 2학년', value: 8),
      _GradeDropdownItem(label: '중학교 3학년', value: 9),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('신규 시험 등록'),
      ),
      body: SafeArea(
        child: groupsAsync.when(
          data: (groups) {
            // Set initial selected group if not already set and groups are available
            if (_selectedGroupId == null && groups.isNotEmpty) {
              _selectedGroupId = groups.first.id;
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exam Group Dropdown with Inline Add Button
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedGroupId,
                            decoration: const InputDecoration(
                              labelText: '시험 그룹 *',
                              prefixIcon: Icon(Icons.folder_outlined),
                            ),
                            hint: const Text('시험 그룹을 선택하세요'),
                            items: groups.map((g) {
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
                                  _selectedGroupId = val;
                                });
                              }
                            },
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return '시험 그룹을 선택해야 합니다.';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filled(
                          onPressed: () => _showInlineAddGroupDialog(context),
                          icon: const Icon(Icons.add_rounded),
                          tooltip: '새 시험 그룹 만들기',
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(54, 54),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    MathTextField(
                      controller: _titleController,
                      labelText: '시험명 *',
                      hintText: '예: 6월 월말 기말고사, 쎈수학 3단원 단원평가',
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? '시험명을 입력해주세요.' : null,
                    ),
                    const SizedBox(height: 20),
                    
                    // Grade Selector Dropdown
                    DropdownButtonFormField<int>(
                      value: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: '대상 학년 *',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: gradeChoices.map((item) {
                        return DropdownMenuItem<int>(
                          value: item.value,
                          child: Text(item.label),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedGrade = val;
                          });
                        }
                      },
                    ),
                     const SizedBox(height: 20),

                    InkWell(
                      onTap: () => _selectDate(context),
                      child: IgnorePointer(
                        child: MathTextField(
                          controller: _dateController,
                          labelText: '시험 날짜 *',
                          suffixIcon: const Icon(Icons.calendar_today),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    MathTextField(
                      controller: _maxScoreController,
                      labelText: '시험 만점 (최대 점수) *',
                      hintText: '기본: 100',
                      keyboardType: TextInputType.number,
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return '시험 만점(최대 점수)을 입력해주세요.';
                        }
                        final score = int.tryParse(val.trim());
                        if (score == null || score <= 0) {
                          return '올바른 점수(0 초과 정수)를 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 36),
                    MathButton(
                      text: _isSaving ? '저장하는 중...' : '시험 등록 완료',
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _saveForm,
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const MathLoader(message: '시험 그룹을 확인하는 중...'),
          error: (err, _) => Center(child: Text('시험 그룹 로딩 에러: $err')),
        ),
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toIso8601String().split('T')[0];
      });
    }
  }

  void _showInlineAddGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => InlineGroupFormDialog(ref: ref),
    ).then((newGroupId) {
      if (newGroupId != null && newGroupId is String) {
        ref.invalidate(examGroupsStreamProvider);
        setState(() {
          _selectedGroupId = newGroupId;
        });
      }
    });
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final date = _dateController.text;
    final groupId = _selectedGroupId ?? '';
    final maxScore = int.tryParse(_maxScoreController.text.trim()) ?? 100;

    try {
      await ref.read(examRepositoryProvider).addExam(
        title,
        date,
        _selectedGrade,
        groupId,
        maxPossibleScore: maxScore,
      );
      ref.invalidate(examsListStreamProvider);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('시험 등록 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}

class InlineGroupFormDialog extends StatefulWidget {
  final WidgetRef ref;

  const InlineGroupFormDialog({required this.ref, super.key});

  @override
  State<InlineGroupFormDialog> createState() => InlineGroupFormDialogState();
}

class InlineGroupFormDialogState extends State<InlineGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hexController = TextEditingController(text: '#3F51B5');
  Color _selectedColor = const Color(0xFF3F51B5);
  bool _isSaving = false;

  final List<String> _presets = [
    '#3F51B5', // Indigo
    '#10B981', // Emerald
    '#F59E0B', // Orange
    '#F43F5E', // Rose
    '#8B5CF6', // Purple
    '#EC4899', // Pink
    '#0D9488', // Teal
    '#06B6D4', // Cyan
  ];

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
      title: const Text('새 시험 그룹 만들기', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '그룹 이름',
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
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),

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
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                decoration: BoxDecoration(
                  color: _selectedColor,
                  borderRadius: BorderRadius.circular(10),
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
              const SizedBox(height: 20),

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
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: presetColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                          width: 2.0,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: presetColor.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              Text(
                '사용자 지정 색상 설정',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _ColorPalettePickerInline(
                initialColor: _selectedColor,
                onColorChanged: _onColorChanged,
              ),
              const SizedBox(height: 12),

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
                    return '올바른 HEX 코드 형태여야 합니다.';
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
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _isSaving = true;
                    });

                    final name = _nameController.text.trim();
                    final color = _colorToHex(_selectedColor);

                    try {
                      final newId = await widget.ref.read(examRepositoryProvider).addExamGroup(name, color);
                      if (context.mounted) {
                        Navigator.pop(context, newId);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('생성 실패: $e')),
                        );
                      }
                    } finally {
                      setState(() {
                        _isSaving = false;
                      });
                    }
                  }
                },
          child: const Text('생성'),
        ),
      ],
    );
  }
}

class _ColorPalettePickerInline extends StatefulWidget {
  final Color initialColor;
  final ValueChanged<Color> onColorChanged;

  const _ColorPalettePickerInline({required this.initialColor, required this.onColorChanged});

  @override
  State<_ColorPalettePickerInline> createState() => _ColorPalettePickerInlineState();
}

class _ColorPalettePickerInlineState extends State<_ColorPalettePickerInline> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    _updateHSV(widget.initialColor);
  }

  @override
  void didUpdateWidget(covariant _ColorPalettePickerInline oldWidget) {
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
      constraints: const BoxConstraints(minWidth: 260),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
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
            height: 40,
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
          const SizedBox(height: 4),
          Center(
            child: Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children: List.generate(10, (index) {
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
                    width: 44,
                    height: 28,
                    decoration: BoxDecoration(
                      color: itemColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.grey.shade400,
                        width: isSelected ? 2.5 : 1.0,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _GradeDropdownItem {
  final String label;
  final int value;

  _GradeDropdownItem({required this.label, required this.value});
}
