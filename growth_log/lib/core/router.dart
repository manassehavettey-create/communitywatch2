import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import '../features/insights/presentation/insights_screen.dart';
import '../features/insights/presentation/recap_screen.dart';
import '../features/log/data/entry_repository.dart';
import '../features/log/presentation/entry_editor_screen.dart';
import '../features/log/presentation/log_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/shell/app_shell.dart';
import '../features/skills/presentation/skill_detail_screen.dart';
import '../features/skills/presentation/skill_editor_screen.dart';
import '../features/skills/presentation/skills_screen.dart';
import '../features/timer/presentation/timer_screen.dart';
import 'providers.dart';
import 'utils/day_key.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const setup = '/setup';
  static const home = '/home';
  static const skills = '/skills';
  static const log = '/log';
  static const insights = '/insights';
  static const settings = '/settings';
  static const newSkill = '/skills/new';
  static String skill(int id) => '/skills/$id';
  static String editSkill(int id) => '/skills/$id/edit';
  static String timer([int? skillId]) =>
      skillId == null ? '/timer' : '/timer?skill=$skillId';
  static String newEntry({EntryType type = EntryType.gratitude, int? skillId}) =>
      '/entry/new?type=${type.dbValue}${skillId == null ? '' : '&skill=$skillId'}';
  static String entry(int id) => '/entry/$id';
  static String recap([DayKey? month]) =>
      month == null ? '/recap' : '/recap?month=$month';
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(
    settingsProvider.select((s) => s.onboardingDone),
    (_, _) => refresh.value++,
  );
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final done = ref.read(settingsProvider).onboardingDone;
      final loc = state.matchedLocation;
      final inOnboarding = loc == Routes.onboarding || loc == Routes.setup;
      if (!done && !inOnboarding) return Routes.onboarding;
      if (done && inOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.setup,
        builder: (_, _) => const SkillEditorScreen(setupMode: true),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.skills, builder: (_, _) => const SkillsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.log, builder: (_, _) => const LogScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.insights,
              builder: (_, _) => const InsightsScreen(),
            ),
          ]),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, _) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.newSkill,
        builder: (_, _) => const SkillEditorScreen(),
      ),
      GoRoute(
        path: '/skills/:id',
        builder: (_, state) =>
            SkillDetailScreen(skillId: int.parse(state.pathParameters['id']!)),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => SkillEditorScreen(
              skillId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/timer',
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: TimerScreen(
            initialSkillId: int.tryParse(state.uri.queryParameters['skill'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/entry/new',
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: EntryEditorScreen(
            initialType: EntryType.parse(state.uri.queryParameters['type'] ?? ''),
            initialSkillId: int.tryParse(state.uri.queryParameters['skill'] ?? ''),
          ),
        ),
      ),
      GoRoute(
        path: '/entry/:id',
        pageBuilder: (_, state) => MaterialPage(
          fullscreenDialog: true,
          child: EntryEditorScreen(
            entryId: int.parse(state.pathParameters['id']!),
          ),
        ),
      ),
      GoRoute(
        path: '/recap',
        builder: (_, state) => RecapScreen(
          initialMonth: int.tryParse(state.uri.queryParameters['month'] ?? ''),
        ),
      ),
    ],
    errorBuilder: (context, state) => const _NotFound(),
  );
});

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: TextButton(
          onPressed: () => context.go(Routes.home),
          child: const Text("That page doesn't exist — go home"),
        ),
      ),
    );
  }
}
