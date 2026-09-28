import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/motion/motion.dart';
import '../core/widgets/navigation.dart';
import '../features/achievements/achievements_screen.dart';
import '../features/auth/auth_screen.dart';
import '../features/auth/welcome_screen.dart';
import '../features/exercise/exercise_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/journey/journey_screen.dart';
import '../features/journey/report_screen.dart';
import '../features/nutrition/challenge_screen.dart';
import '../features/nutrition/food_detail_screen.dart';
import '../features/nutrition/meal_guidance_screen.dart';
import '../features/nutrition/nutrition_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/player/completion_screen.dart';
import '../features/player/player_screen.dart';
import '../features/profile/edit_profile_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/profile/settings_screen.dart';
import '../features/progress/calendar_screen.dart';
import '../features/progress/measurements_screen.dart';
import '../features/progress/progress_screen.dart';
import '../features/progress/records_screen.dart';
import '../features/progress/weekly_check_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/workout/build_program_screen.dart';
import '../features/workout/session_preview_screen.dart';
import '../features/workout/skill_path_screen.dart';
import '../features/workout/workout_screen.dart';
import 'auth.dart';
import 'providers.dart';

/// Becomes true once the animated splash has played.
class SplashDone extends Notifier<bool> {
  @override
  bool build() => false;
  void done() => state = true;
}

final splashDoneProvider = NotifierProvider<SplashDone, bool>(SplashDone.new);

final _rootKey = GlobalKey<NavigatorState>();

/// Shared-axis style page transition (fade + slight rise); a plain fade when
/// reduced motion is on.
CustomTransitionPage<void> _page(GoRouterState state, Widget child, {bool modal = false}) => CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: Motion.slow,
      reverseTransitionDuration: Motion.medium,
      transitionsBuilder: (context, animation, secondary, child) {
        if (Motion.reduced(context)) return FadeTransition(opacity: animation, child: child);
        final curved = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: Offset(0, modal ? 0.08 : 0.03), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.onDispose(refresh.dispose);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.listen(profileProvider, (_, _) => refresh.value++);
  ref.listen(splashDoneProvider, (_, _) => refresh.value++);

  const public = {'/welcome', '/auth'};

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!ref.read(splashDoneProvider)) return loc == '/splash' ? null : '/splash';
      final auth = ref.read(authProvider);
      if (!auth.isSignedIn) return public.contains(loc) ? null : '/welcome';
      final profile = ref.read(profileProvider);
      if (!profile.hasValue) return loc == '/splash' ? null : '/splash';
      if (profile.value == null) return loc == '/onboarding' ? null : '/onboarding';
      // Local users may open /auth from Settings to create an account.
      if (loc == '/auth' && auth.mode == AuthMode.local) return null;
      if (loc == '/splash' || loc == '/onboarding' || public.contains(loc)) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', pageBuilder: (c, s) => _page(s, const SplashScreen())),
      GoRoute(path: '/welcome', pageBuilder: (c, s) => _page(s, const WelcomeScreen())),
      GoRoute(
          path: '/auth',
          pageBuilder: (c, s) => _page(s, AuthScreen(signUp: s.uri.queryParameters['mode'] != 'signin'), modal: true)),
      GoRoute(path: '/onboarding', pageBuilder: (c, s) => _page(s, const OnboardingScreen())),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [GoRoute(path: '/home', pageBuilder: (c, s) => _page(s, const HomeScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/workout', pageBuilder: (c, s) => _page(s, const WorkoutScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/progress', pageBuilder: (c, s) => _page(s, const ProgressScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/nutrition', pageBuilder: (c, s) => _page(s, const NutritionScreen()))]),
          StatefulShellBranch(routes: [GoRoute(path: '/profile', pageBuilder: (c, s) => _page(s, const ProfileScreen()))]),
        ],
      ),
      GoRoute(path: '/session', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const SessionPreviewScreen())),
      GoRoute(path: '/player', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const PlayerScreen(), modal: true)),
      GoRoute(path: '/complete', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const CompletionScreen())),
      GoRoute(
          path: '/exercise/:id',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _page(s, ExerciseDetailScreen(exerciseId: s.pathParameters['id']!))),
      GoRoute(
          path: '/skills/:pathId',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _page(s, SkillPathScreen(pathId: s.pathParameters['pathId']!))),
      GoRoute(path: '/build', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const BuildProgramScreen())),
      GoRoute(path: '/records', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const RecordsScreen())),
      GoRoute(path: '/measurements', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const MeasurementsScreen())),
      GoRoute(path: '/calendar', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const CalendarScreen())),
      GoRoute(path: '/weekly', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const WeeklyCheckScreen())),
      GoRoute(path: '/journey', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const JourneyScreen())),
      GoRoute(path: '/report', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const ReportScreen())),
      GoRoute(path: '/achievements', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const AchievementsScreen())),
      GoRoute(
          path: '/food/:id',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _page(s, FoodDetailScreen(foodId: s.pathParameters['id']!))),
      GoRoute(path: '/meals', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const MealGuidanceScreen())),
      GoRoute(
          path: '/challenge/:id',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _page(s, ChallengeScreen(challengeId: s.pathParameters['id']!))),
      GoRoute(path: '/settings', parentNavigatorKey: _rootKey, pageBuilder: (c, s) => _page(s, const SettingsScreen())),
      GoRoute(
          path: '/edit/:section',
          parentNavigatorKey: _rootKey,
          pageBuilder: (c, s) => _page(s, EditProfileScreen(section: s.pathParameters['section']!), modal: true)),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: shell,
      bottomNavigationBar: ForgeNavBar(
        index: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
