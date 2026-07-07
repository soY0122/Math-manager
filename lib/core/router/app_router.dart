import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/student/presentation/student_list_screen.dart';
import '../../features/student/presentation/student_detail_screen.dart';
import '../../features/student/presentation/student_add_edit_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/test/presentation/test_screen.dart';
import '../../features/test/presentation/test_add_screen.dart';
import '../../features/test/presentation/test_score_input_screen.dart';
import '../../features/homework/presentation/homework_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../widgets/scaffold_with_nav_bar.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    navigatorKey: rootNavigatorKey,
    routes: [
      GoRoute(
        path: '/homework',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const HomeworkScreen(),
      ),
      GoRoute(
        path: '/grades/add-exam',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const TestAddScreen(),
      ),
      GoRoute(
        path: '/grades/score-input/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final idStr = state.pathParameters['id'];
          final id = int.tryParse(idStr ?? '') ?? 0;
          return TestScoreInputScreen(examId: id);
        },
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return ScaffoldWithNavBar(child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/student',
            pageBuilder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return NoTransitionPage(
                child: StudentListScreen(filter: filter),
              );
            },
            routes: [
              GoRoute(
                path: 'add',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) => const StudentAddEditScreen(),
              ),
              GoRoute(
                path: ':id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final idStr = state.pathParameters['id'];
                  final id = int.tryParse(idStr ?? '') ?? 0;
                  return StudentDetailScreen(studentId: id);
                },
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final idStr = state.pathParameters['id'];
                  final id = int.tryParse(idStr ?? '') ?? 0;
                  return StudentAddEditScreen(studentId: id);
                },
              ),
            ],
          ),
          GoRoute(
            path: '/attendance',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: AttendanceScreen(),
            ),
          ),
          GoRoute(
            path: '/grades',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TestScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
    ],
  );
});
