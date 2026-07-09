import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/student/presentation/student_list_screen.dart';
import '../../features/student/presentation/student_detail_screen.dart';
import '../../features/student/presentation/student_add_edit_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/test/presentation/test_screen.dart';
import '../../features/test/presentation/test_add_screen.dart';
import '../../features/test/presentation/test_score_input_screen.dart';
import '../../features/test/presentation/exam_group_screen.dart';
import '../../features/test/presentation/exam_management_screen.dart';
import '../../features/homework/presentation/homework_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/promotion_screen.dart';
import '../widgets/scaffold_with_nav_bar.dart';
import '../widgets/math_loader.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();
final shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final authNotifier = ref.watch(authNotifierProvider.notifier);

  return GoRouter(
    initialLocation: '/splash',
    navigatorKey: rootNavigatorKey,
    refreshListenable: GoRouterRefreshStream(authNotifier.auth.authStateChanges()),
    redirect: (context, state) {
      if (authState.isLoading) {
        return state.matchedLocation == '/splash' ? null : '/splash';
      }

      final isLoggedIn = authState.user != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (!isLoggedIn) {
        return isLoggingIn ? null : '/login';
      }

      if (isLoggingIn || isSplash) {
        return '/home';
      }

      return null;
    },
    observers: [
      ClearSnackBarsNavigatorObserver(),
    ],
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const Scaffold(
          body: MathLoader(message: '로그인 세션을 확인하는 중...'),
        ),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
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
        path: '/grades/groups',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExamGroupScreen(),
      ),
      GoRoute(
        path: '/settings/promote',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const PromotionScreen(),
      ),
      GoRoute(
        path: '/settings/exam-management',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const ExamManagementScreen(),
      ),
      GoRoute(
        path: '/grades/score-input/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return TestScoreInputScreen(examId: id);
        },
      ),
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        observers: [
          ClearSnackBarsNavigatorObserver(),
        ],
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
                  final id = state.pathParameters['id'] ?? '';
                  return StudentDetailScreen(studentId: id);
                },
              ),
              GoRoute(
                path: 'edit/:id',
                parentNavigatorKey: rootNavigatorKey,
                builder: (context, state) {
                  final id = state.pathParameters['id'] ?? '';
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

class ClearSnackBarsNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _clearSnackBars();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _clearSnackBars();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _clearSnackBars();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _clearSnackBars();
  }

  void _clearSnackBars() {
    final context = shellNavigatorKey.currentContext ?? rootNavigatorKey.currentContext;
    if (context != null) {
      try {
        ScaffoldMessenger.of(context).clearSnackBars();
      } catch (_) {}
    }
  }
}

class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _subscription;

  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (dynamic _) => notifyListeners(),
        );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
