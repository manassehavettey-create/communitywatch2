import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/ai/ask_book_screen.dart';
import '../features/annotations/bookmarks_screen.dart';
import '../features/annotations/highlights_screen.dart';
import '../features/annotations/notes_screen.dart';
import '../features/book/book_details_screen.dart';
import '../features/collections/collection_detail_screen.dart';
import '../features/collections/collections_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/search/search_screen.dart';
import '../features/settings/profile_screen.dart';
import '../features/settings/settings_pages.dart';
import '../features/shell/app_shell.dart';
import '../features/stats/stats_screen.dart';
import 'providers.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

int? _intParam(GoRouterState s, String name) => int.tryParse(s.uri.queryParameters[name] ?? '');

/// Fade + slight rise, used for the reader and focus screens.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 360),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      transitionsBuilder: (context, animation, _, child) {
        if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(scale: Tween(begin: 0.98, end: 1.0).animate(curved), child: child),
        );
      },
    );

final routerProvider = Provider<GoRouter>((ref) {
  final onboarded = ValueNotifier(ref.read(settingsProvider).onboardingDone);
  ref.listen(settingsProvider.select((s) => s.onboardingDone), (_, v) => onboarded.value = v);
  ref.onDispose(onboarded.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/home',
    refreshListenable: onboarded,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded.value && !atOnboarding) return '/onboarding';
      if (onboarded.value && atOnboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/home'),
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/library', builder: (_, _) => const LibraryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/search', builder: (_, _) => const SearchScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/stats', builder: (_, _) => const StatsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              builder: (_, _) => const ProfileScreen(),
              routes: [
                for (final page in SettingsPage.values)
                  GoRoute(
                    path: page.path,
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (_, _) => SettingsPageScreen(page: page),
                  ),
              ],
            ),
          ]),
        ],
      ),
      GoRoute(
        path: '/book/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => BookDetailsScreen(bookId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/read/:id',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, s) => _fadePage(
          s,
          ReaderScreen(
            bookId: int.parse(s.pathParameters['id']!),
            initialPage: _intParam(s, 'page'),
            fromStart: s.uri.queryParameters['start'] == '1',
            focusMinutes: _intParam(s, 'focus'),
            highlightQuery: s.uri.queryParameters['q'],
          ),
        ),
      ),
      GoRoute(
        path: '/ask/:id',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => AskBookScreen(
          bookId: int.parse(s.pathParameters['id']!),
          initialPage: _intParam(s, 'page'),
        ),
      ),
      GoRoute(
        path: '/highlights',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => HighlightsScreen(bookId: _intParam(s, 'book')),
      ),
      GoRoute(
        path: '/notes',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => NotesScreen(bookId: _intParam(s, 'book')),
      ),
      GoRoute(
        path: '/bookmarks',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => BookmarksScreen(bookId: _intParam(s, 'book')),
      ),
      GoRoute(
        path: '/collections',
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, _) => const CollectionsScreen(),
        routes: [
          GoRoute(
            path: ':id',
            parentNavigatorKey: rootNavigatorKey,
            builder: (_, s) => CollectionDetailScreen(collectionId: int.parse(s.pathParameters['id']!)),
          ),
        ],
      ),
    ],
  );
});
