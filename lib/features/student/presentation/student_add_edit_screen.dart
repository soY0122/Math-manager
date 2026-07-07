import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/student_list_provider.dart';
import 'providers/student_detail_provider.dart';
import '../../../core/widgets/math_button.dart';
import '../../../core/widgets/math_text_field.dart';
import '../../../core/widgets/math_loader.dart';

class StudentAddEditScreen extends ConsumerStatefulWidget {
  final String? studentId;

  const StudentAddEditScreen({
    super.key,
    this.studentId,
  });

  @override
  ConsumerState<StudentAddEditScreen> createState() => _StudentAddEditScreenState();
}

class _StudentAddEditScreenState extends ConsumerState<StudentAddEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _schoolController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateController = TextEditingController();
  final _memoController = TextEditingController();

  int _selectedGrade = 3; // Default: 초3
  bool _isActive = true;
  bool _isDataLoaded = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Default registration date to today YYYY-MM-DD
    _dateController.text = DateTime.now().toIso8601String().split('T')[0];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.studentId != null;

    // Prepopulate form values once data is loaded when editing
    if (isEdit && !_isDataLoaded) {
      final detailAsync = ref.watch(studentDetailStreamProvider(widget.studentId!));
      return detailAsync.when(
        data: (detail) {
          final stats = detail.stats;
          _nameController.text = stats.name;
          _schoolController.text = stats.school;
          _phoneController.text = stats.parentPhone;
          _dateController.text = stats.registrationDate;
          _memoController.text = stats.memo ?? '';
          _selectedGrade = stats.grade;
          _isActive = stats.isActive;
          _isDataLoaded = true;

          return _buildFormScaffold(context, isEdit);
        },
        loading: () => const Scaffold(body: MathLoader(message: '기존 정보를 불러오는 중...')),
        error: (err, stack) => Scaffold(
          appBar: AppBar(),
          body: Center(child: Text('기존 학생 정보를 불러오지 못했습니다: $err')),
        ),
      );
    }

    return _buildFormScaffold(context, isEdit);
  }

  Widget _buildFormScaffold(BuildContext context, bool isEdit) {
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
        title: Text(isEdit ? '학생 정보 수정' : '신규 학생 추가'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                MathTextField(
                  controller: _nameController,
                  labelText: '이름 *',
                  hintText: '학생 이름을 입력하세요',
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? '이름을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),

                // School
                MathTextField(
                  controller: _schoolController,
                  labelText: '학교 *',
                  hintText: '학교명을 입력하세요 (예: 서울초등학교)',
                  validator: (val) =>
                      (val == null || val.trim().isEmpty) ? '학교명을 입력해주세요.' : null,
                ),
                const SizedBox(height: 16),

                // Grade Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedGrade,
                  decoration: const InputDecoration(
                    labelText: '학년 *',
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

                // Parent Contact
                MathTextField(
                  controller: _phoneController,
                  labelText: '학부모 연락처 (선택)',
                  hintText: '숫자와 하이픈만 입력하세요 (예: 010-1234-5678)',
                  keyboardType: TextInputType.phone,
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Registration Date Picker
                InkWell(
                  onTap: () => _selectDate(context),
                  child: IgnorePointer(
                    child: MathTextField(
                      controller: _dateController,
                      labelText: '학원 등록일 *',
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Memo
                MathTextField(
                  controller: _memoController,
                  labelText: '선생님 메모 (선택)',
                  hintText: '학생 특이사항이나 상담 요약을 입력하세요',
                  maxLines: 4,
                ),
                const SizedBox(height: 16),

                // Active Switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '원생 상태 (재원 여부)',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Switch(
                      value: _isActive,
                      activeColor: theme.colorScheme.primary,
                      onChanged: (val) {
                        setState(() {
                          _isActive = val;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Save Button
                MathButton(
                  text: _isSaving ? '저장하는 중...' : '저장 완료',
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

    final name = _nameController.text.trim();
    final school = _schoolController.text.trim();
    const className = '';
    final parentPhone = _phoneController.text.trim();
    final regDate = _dateController.text;
    final memo = _memoController.text.trim();

    final repository = ref.read(studentRepositoryProvider);
    
    try {
      if (widget.studentId != null) {
        // Edit student
        await repository.updateStudent(
          id: widget.studentId!,
          name: name,
          school: school,
          grade: _selectedGrade,
          className: className,
          parentPhone: parentPhone,
          registrationDate: regDate,
          memo: memo.isEmpty ? null : memo,
          isActive: _isActive,
        );
        // Invalidate detail to show fresh data immediately
        ref.invalidate(studentDetailStreamProvider(widget.studentId!));
      } else {
        // Add student
        await repository.addStudent(
          name: name,
          school: school,
          grade: _selectedGrade,
          className: className,
          parentPhone: parentPhone,
          registrationDate: regDate,
          memo: memo.isEmpty ? null : memo,
          isActive: _isActive,
        );
      }
      
      // Invalidate list to refresh counts
      ref.invalidate(studentsStreamProvider);

      if (mounted) {
        context.pop(); // Close form and return
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 저장 오류: $e')),
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

class _GradeDropdownItem {
  final String label;
  final int value;

  _GradeDropdownItem({required this.label, required this.value});
}
