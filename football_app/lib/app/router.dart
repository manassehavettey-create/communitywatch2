import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/tokens.dart';
import '../features/compare/compare_screen.dart';
import '../features/home/home_screen.dart';
import '../features/league/league_screen.dart';
import '../features/league/leagues_screen.dart';
import '../features/match/briefing_screen.dart';
import '../features/match/match_screen.dart';
import '../features/match/recap_screen.dart';
import '../features/matches/matches_screen.dart';
import '../features/notifications/notifications_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/player/player_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screens.dart';
import '../features/search/search_screen.dart';
import '../features/share/share_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/team/team_screen.dart';
import '../features/transfers/transfers_screen.dart';
import 'settings.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shared-axis style transition: fade + gentle scale/lift. Hero crests fly
/// on top of it.
CustomTransitionPage<void> _page(GoRouterState s, Widget child) => CustomTransitionPage(
      key: s.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 380),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      transitionsBuilder: (context, anim, secondary, child) {
        if (context.reduceMotion) return FadeTransition(opacity: anim, child: child);
        final a = CurvedAnimation(parent: anim, curve: Motion.emphasized, reverseCurve: Curves.easeInCubic);
        return FadeTransition(
          opacity: Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: anim, curve: const Interval(0, 0.6))),
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a),
            child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
          ),
        );
      },
    );

int _id(GoRouterState s) => int.tryParse(s.pathParameters['id'] ?? '') ?? 0;

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ref.read(settingsProvider).onboarded;
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: onboarded ? '/home' : '/onboarding',
    routes: [
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (c, s) => const HomeScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/matches', builder: (c, s) => const MatchesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/leagues', builder: (c, s) => const LeaguesScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/search', builder: (c, s) => const SearchScreen())]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen())]),
        ],
      ),
      GoRoute(
        path: '/match/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _page(s, MatchScreen(id: _id(s), heroScope: s.uri.queryParameters['h'] ?? 'x', initialTab: s.uri.queryParameters['tab'])),
        routes: [
          GoRoute(path: 'briefing', pageBuilder: (c, s) => _page(s, BriefingScreen(id: _id(s)))),
          GoRoute(path: 'recap', pageBuilder: (c, s) => _page(s, RecapScreen(id: _id(s)))),
        ],
      ),
      GoRoute(path: '/team/:id', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, TeamScreen(id: _id(s)))),
      GoRoute(path: '/player/:id', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, PlayerScreen(id: _id(s)))),
      GoRoute(path: '/league/:id', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, LeagueScreen(id: _id(s), initialTab: s.uri.queryParameters['tab']))),
      GoRoute(
        path: '/compare',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (c, s) => _page(s, CompareScreen(a: int.tryParse(s.uri.queryParameters['a'] ?? ''), b: int.tryParse(s.uri.queryParameters['b'] ?? ''))),
      ),
      GoRoute(path: '/transfers', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, const TransfersScreen())),
      GoRoute(path: '/notifications', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, const NotificationsScreen())),
      GoRoute(path: '/settings/:section', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, SettingsSectionScreen(section: s.pathParameters['section']!))),
      GoRoute(path: '/share', parentNavigatorKey: rootNavigatorKey, pageBuilder: (c, s) => _page(s, ShareScreen(request: s.extra as ShareRequest?))),
    ],
  );
});
