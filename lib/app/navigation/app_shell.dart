import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_strings.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, required this.location, super.key});

  final Widget child;
  final String location;

  static const routes = [
    '/home',
    '/products',
    '/purchases',
    '/sales',
    '/reports',
  ];

  @override
  Widget build(BuildContext context) {
    final routeIndex = routes.indexOf(location);
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: routeIndex < 0 ? 0 : routeIndex,
        onDestinationSelected: (index) => context.go(routes[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: AppStrings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: AppStrings.products,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            label: AppStrings.purchases,
          ),
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            label: AppStrings.sales,
          ),
          NavigationDestination(
            icon: Icon(Icons.assessment_outlined),
            label: 'گزارش‌ها',
          ),
        ],
      ),
    );
  }
}
