import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../../../core/providers/global_providers.dart';
import '../../../student/presentation/providers/student_list_provider.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../homework/presentation/providers/homework_providers.dart';
import '../../../test/presentation/providers/exam_providers.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepositoryImpl();
});

final dashboardExamGroupFilterProvider = StateProvider<String?>((ref) => null);

final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  ref.watch(studentsStreamProvider).maybeWhen(orElse: () => null);
  ref.watch(attendanceStreamProvider).maybeWhen(orElse: () => null);
  ref.watch(homeworkStreamProvider).maybeWhen(orElse: () => null);
  ref.watch(examsListStreamProvider).maybeWhen(orElse: () => null);

  final repository = ref.watch(homeRepositoryProvider);
  final grade = ref.watch(globalGradeFilterProvider);
  final examGroupId = ref.watch(dashboardExamGroupFilterProvider);
  return repository.watchDashboardStats(grade, examGroupId);
});
