import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/home_repository_impl.dart';
import '../../domain/repositories/home_repository.dart';
import '../../domain/models/dashboard_stats.dart';
import '../../../../core/database/database_provider.dart';

import '../../../../core/providers/global_providers.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return HomeRepositoryImpl(db);
});

final dashboardStatsProvider = StreamProvider<DashboardStats>((ref) {
  final repository = ref.watch(homeRepositoryProvider);
  final grade = ref.watch(globalGradeFilterProvider);
  return repository.watchDashboardStats(grade);
});
