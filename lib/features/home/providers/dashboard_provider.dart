import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider((_) => DashboardRepository());
final dashboardProvider = FutureProvider<DashboardSummary>(
  (ref) => ref.read(dashboardRepositoryProvider).getSummary(),
);

final lowStockItemsProvider = FutureProvider<List<LowStockItem>>(
  (ref) => ref.read(dashboardRepositoryProvider).getLowStockItems(),
);
