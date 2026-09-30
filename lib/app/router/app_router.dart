import 'package:go_router/go_router.dart';

import '../navigation/app_shell.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/purchases/presentation/purchases_screen.dart';
import '../../features/purchases/presentation/purchase_form_screen.dart';
import '../../features/products/data/product.dart';
import '../../features/products/presentation/products_screen.dart';
import '../../features/products/presentation/product_details_screen.dart';
import '../../features/sales/presentation/sales_screen.dart';
import '../../features/sales/presentation/sale_form_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/settings_menu_screen.dart';
import '../../features/settings/presentation/security_screen.dart';
import '../../features/settings/presentation/data_management_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/financial/data/financial_models.dart';
import '../../features/financial/presentation/financial_screens.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
    GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
        GoRoute(
          path: '/notifications',
          builder: (_, _) => const NotificationsScreen(),
        ),
        GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
        GoRoute(path: '/purchases', builder: (_, _) => const PurchasesScreen()),
        GoRoute(path: '/sales', builder: (_, _) => const SalesScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
        GoRoute(path: '/backup', builder: (_, _) => const BackupScreen()),
        GoRoute(path: '/security', builder: (_, _) => const SecurityScreen()),
        GoRoute(
          path: '/data-management',
          builder: (_, _) => const DataManagementScreen(),
        ),
        GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
        GoRoute(
          path: '/financial-reports',
          builder: (_, _) => const FinancialReportsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/purchase-form',
      builder: (_, state) => PurchaseFormScreen(
        initialProduct: state.extra is Product ? state.extra as Product : null,
      ),
    ),
    GoRoute(path: '/sale-form', builder: (_, _) => const SaleFormScreen()),
    GoRoute(
      path: '/product-details',
      builder: (_, state) =>
          ProductDetailsScreen(product: state.extra as Product),
    ),
    GoRoute(
      path: '/financial-form',
      builder: (_, state) => FinancialReportFormScreen(
        initialReport: state.extra is FinancialReport
            ? state.extra as FinancialReport
            : null,
      ),
    ),
    GoRoute(
      path: '/financial-details',
      builder: (_, state) =>
          FinancialReportDetailsScreen(id: state.extra as int),
    ),
  ],
);
