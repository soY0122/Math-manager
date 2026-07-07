import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/exam_providers.dart';
import '../../../core/widgets/math_button.dart';
import '../../../core/widgets/math_text_field.dart';

class TestAddScreen extends ConsumerStatefulWidget {
  const TestAddScreen({super.key});

  @override
  ConsumerState<TestAddScreen> createState() => _TestAddScreenState();
}

class _StudentAddScreenState extends ConsumerState<TestAddScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _dateController = TextEditingController();
  int _selectedGrade = 3; // Default: 초3
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MathTextField(
                  controller: _titleController,
                  labelText: '시험명 *',
                  hintText: '예: 6월 월말 기말고사, 쎈수학 3단원 단원평가',
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? '시험명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),
                
                // Grade Selector Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedGrade,
                  decoration: const InputDecoration(
                    labelText: '대상 학년 *',
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
                const SizedBox(height: 16),

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
                const SizedBox(height: 32),
                MathButton(
                  text: _isSaving ? '저장하는 중...' : '시험 등록 완료',
                  isLoading: _isSaving,
                  onPressed: _isSaving ? null : _saveForm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toIso8601String().split('T')[0];
      });
    }
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

    try {
      await ref.read(examRepositoryProvider).addExam(title, date, _selectedGrade);
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

class _TestAddScreenState extends _StudentAddScreenState {}

class _GradeDropdownItem {
  final String label;
  final int value;

  _GradeDropdownItem({required this.label, required this.value});
}
