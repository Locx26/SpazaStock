// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../main.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import '../../presentation/screens/language_select/language_select_screen.dart';
import '../../presentation/screens/dashboard/dashboard_screen.dart';
import '../../presentation/screens/inventory/inventory_screen.dart';
import '../../presentation/screens/add_product/add_product_screen.dart';
import '../../presentation/screens/nfc_scan/nfc_scan_screen.dart';
import '../../presentation/screens/sales_history/sales_history_screen.dart';
import '../../presentation/screens/analytics/analytics_screen.dart';
import '../../presentation/screens/main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/language',
        builder: (_, __) => const LanguageSelectScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/product/add',
            builder: (_, __) => const AddProductScreen(),
          ),
          GoRoute(
            path: '/product/edit/:id',
            builder: (_, state) =>
                AddProductScreen(productId: state.pathParameters['id']),
          ),
          GoRoute(
            path: '/scan',
            builder: (_, __) => const NfcScanScreen(),
          ),
          GoRoute(
            path: '/sales',
            builder: (_, __) => const SalesHistoryScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (_, __) => const AnalyticsScreen(),
          ),
        ],
      ),
    ],
    redirect: (context, state) {
      final hasSeenLanguageSelect =
          prefs.getBool('has_seen_language_select') ?? false;
      if (state.matchedLocation == '/splash') return null;
      if (!hasSeenLanguageSelect && state.matchedLocation != '/language') {
        return '/language';
      }
      return null;
    },
  );
});
