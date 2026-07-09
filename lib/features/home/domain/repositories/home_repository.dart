import '../models/dashboard_stats.dart';

abstract class HomeRepository {
  Stream<DashboardStats> watchDashboardStats(int? gradeFilter, String? examGroupId);
}
