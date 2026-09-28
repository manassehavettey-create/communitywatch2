import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../bible/references.dart';
import '../core/motion/motion.dart';
import '../features/auth/auth_screen.dart';
import '../features/bible/bible_screen.dart';
import '../features/home/home_screen.dart';
import '../features/journal/journal_editor_screen.dart';
import '../features/journal/journal_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/plans/plan_detail_screen.dart';
import '../features/plans/plans_screen.dart';
import '../features/prayer/prayer_detail_screen.dart';
import '../features/prayer/prayer_editor_screen.dart';
import '../features/prayer/prayer_screen.dart';
import '../features/profile/about_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/saved/notes_screen.dart';
import '../features/saved/saved_screen.dart';
import '../features/search/search_screen.dart';
import '../features/share/share_card_screen.dart';
import '../features/streaks/streak_screen.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Pushed screens rise and fade in; honours reduce motion via [Motion].
Page<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: MotionTokens.slow,
      reverseTransitionDuration: MotionTokens.base,
      transitionsBuilder: (context, animation, secondary, child) {
        final m = Motion.of(context);
        final curved = CurvedAnimation(
          parent: animation,
          curve: m.standard,
          reverseCurve: MotionTokens.exit,
        );
        if (m.reduced) return FadeTransition(opacity: curved, child: child);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );

GoRouter buildRouter({required bool onboarded}) => GoRouter(
  navigatorKey: _rootKey,
  initialLocation: onboarded ? '/home' : '/onboarding',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/bible', builder: (_, _) => const BibleScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/plans', builder: (_, _) => const PlansScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/prayer', builder: (_, _) => const PrayerScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/onboarding',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const OnboardingScreen()),
    ),
    GoRoute(
      path: '/auth',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(
        s,
        AuthScreen(fromOnboarding: s.uri.queryParameters['onboarding'] == '1'),
      ),
    ),
    GoRoute(
      path: '/read',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(
        s,
        ReaderScreen(args: ReaderArgs.fromQuery(s.uri.queryParameters)),
      ),
    ),
    GoRoute(
      path: '/search',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const SearchScreen()),
    ),
    GoRoute(
      path: '/saved',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) {
        final k = s.uri.queryParameters['kind'];
        return _page(
          s,
          SavedScreen(
            initialKind: SavedKind.values.where((x) => x.name == k).firstOrNull,
          ),
        );
      },
    ),
    GoRoute(
      path: '/notes',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const NotesScreen()),
    ),
    GoRoute(
      path: '/journal',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const JournalScreen()),
    ),
    GoRoute(
      path: '/journal/new',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(
        s,
        JournalEditorScreen(scriptureRef: s.uri.queryParameters['r']),
      ),
    ),
    GoRoute(
      path: '/journal/:id',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) =>
          _page(s, JournalEditorScreen(entryId: s.pathParameters['id'])),
    ),
    GoRoute(
      path: '/prayer/new',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const PrayerEditorScreen()),
    ),
    GoRoute(
      path: '/prayer/:id',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) =>
          _page(s, PrayerDetailScreen(prayerId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/prayer/:id/edit',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) =>
          _page(s, PrayerEditorScreen(prayerId: s.pathParameters['id'])),
    ),
    GoRoute(
      path: '/plans/:id',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) =>
          _page(s, PlanDetailScreen(planId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/streak',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const StreakScreen()),
    ),
    GoRoute(
      path: '/share',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) {
        VerseRange range;
        try {
          range = VerseRange.parseCode(s.uri.queryParameters['r'] ?? '');
        } on Object {
          range = VerseRange.single(const VerseRef('JHN', 3, 16));
        }
        return _page(
          s,
          ShareCardScreen(
            range: range,
            translationId: s.uri.queryParameters['t'],
          ),
        );
      },
    ),
    GoRoute(
      path: '/settings',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const SettingsScreen()),
    ),
    GoRoute(
      path: '/about',
      parentNavigatorKey: _rootKey,
      pageBuilder: (_, s) => _page(s, const AboutScreen()),
    ),
  ],
);
