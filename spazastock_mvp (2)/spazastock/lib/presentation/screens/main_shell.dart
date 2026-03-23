// lib/presentation/screens/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MainShell extends ConsumerWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    _NavTab(icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, label: 'Dashboard', path: '/dashboard'),
    _NavTab(icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Inventory', path: '/inventory'),
    _NavTab(icon: Icons.nfc_outlined, activeIcon: Icons.nfc, label: 'Scan', path: '/scan'),
    _NavTab(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long, label: 'Sales', path: '/sales'),
    _NavTab(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Analytics', path: '/analytics'),
  ];

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i].path)) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = _getCurrentIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (i) => context.go(_tabs[i].path),
        backgroundColor: SpazaColors.surface,
        indicatorColor: SpazaColors.primaryLight.withOpacity(0.15),
        destinations: _tabs
            .map((tab) => NavigationDestination(
                  icon: Icon(tab.icon),
                  selectedIcon: Icon(tab.activeIcon, color: SpazaColors.primary),
                  label: tab.label,
                ))
            .toList(),
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String path;
  const _NavTab({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.path,
  });
}
