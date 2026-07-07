import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/global_providers.dart';

class ScaffoldWithNavBar extends ConsumerWidget {
  final Widget child;

  const ScaffoldWithNavBar({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedGrade = ref.watch(globalGradeFilterProvider);
    final theme = Theme.of(context);

    final gradeChoices = [
      _GradeChoice(label: '전체', value: null),
      _GradeChoice(label: '초1', value: 1),
      _GradeChoice(label: '초2', value: 2),
      _GradeChoice(label: '초3', value: 3),
      _GradeChoice(label: '초4', value: 4),
      _GradeChoice(label: '초5', value: 5),
      _GradeChoice(label: '초6', value: 6),
      _GradeChoice(label: '중1', value: 7),
      _GradeChoice(label: '중2', value: 8),
      _GradeChoice(label: '중3', value: 9),
    ];

    final currentChoice = gradeChoices.firstWhere(
      (c) => c.value == selectedGrade,
      orElse: () => gradeChoices.first,
    );

    return Scaffold(
      body: Column(
        children: [
          // Top Global Grade Selector Bar
          SafeArea(
            bottom: false,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              color: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '학원 대상 학년 설정',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    ),
                  ),
                  PopupMenuButton<int>(
                    initialValue: selectedGrade ?? -1,
                    onSelected: (val) {
                      ref.read(globalGradeFilterProvider.notifier).state = val == -1 ? null : val;
                    },
                    offset: const Offset(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), // Larger touch target
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.school_outlined, size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            currentChoice.label,
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                        ],
                      ),
                    ),
                    itemBuilder: (context) {
                      return gradeChoices.map((choice) {
                        final val = choice.value ?? -1;
                        return PopupMenuItem<int>(
                          value: val,
                          child: Text(
                            choice.label == '전체' ? '전체 학년' : '${choice.label} 학생',
                            style: TextStyle(
                              fontWeight: (selectedGrade ?? -1) == val ? FontWeight.bold : FontWeight.normal,
                              color: (selectedGrade ?? -1) == val ? theme.colorScheme.primary : null,
                            ),
                          ),
                        );
                      }).toList();
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _calculateSelectedIndex(context),
        onTap: (int index) => _onItemTapped(index, context),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: '학생',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: '출결',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment),
            label: '성적',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: '설정',
          ),
        ],
      ),
    );
  }

  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/home')) {
      return 0;
    }
    if (location.startsWith('/student')) {
      return 1;
    }
    if (location.startsWith('/attendance')) {
      return 2;
    }
    if (location.startsWith('/grades')) {
      return 3;
    }
    if (location.startsWith('/settings')) {
      return 4;
    }
    return 0;
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/student');
        break;
      case 2:
        context.go('/attendance');
        break;
      case 3:
        context.go('/grades');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }
}

class _GradeChoice {
  final String label;
  final int? value;

  _GradeChoice({required this.label, this.value});
}
