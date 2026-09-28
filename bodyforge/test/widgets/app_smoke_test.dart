import 'package:bodyforge/app/auth.dart';
import 'package:bodyforge/app/providers.dart';
import 'package:bodyforge/app/router.dart';
import 'package:bodyforge/app/settings.dart';
import 'package:bodyforge/data/local/database.dart';
import 'package:bodyforge/data/repositories/data_context.dart';
import 'package:bodyforge/data/services/training_service.dart';
import 'package:bodyforge/domain/catalog/challenges.dart';
import 'package:bodyforge/domain/catalog/exercises.dart';
import 'package:bodyforge/domain/catalog/foods.dart';
import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:bodyforge/core/widgets/components.dart';
import 'package:bodyforge/core/widgets/navigation.dart';
import 'package:bodyforge/domain/engine/quick_sessions.dart';
import 'package:bodyforge/domain/engine/session_builder.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/domain/models/local_date.dart';
import 'package:bodyforge/features/player/completion_screen.dart';
import 'package:bodyforge/features/player/player_controller.dart';
import 'package:bodyforge/features/player/player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

void main() {
  setUpAll(loadAppFonts);

  late Harness h;
  late AppDatabase db;
  late FixedClock clock;
  late ProviderContainer container;

  Future<void> boot(WidgetTester tester, {bool seed = true, bool demo = false}) async {
    h = await Harness.boot(tester, seed: seed, demo: demo);
    db = h.db;
    clock = h.clock;
    container = h.container;
  }

  Future<void> shutdown(WidgetTester tester) => h.shutdown();

  String location() => container.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  testWidgets('a new user lands on the welcome screen', (tester) async {
    await boot(tester, seed: false);
    expect(location(), '/welcome');
    expect(tester.takeException(), isNull);
    await shutdown(tester);
  });

  testWidgets('a new user goes offline through onboarding to a forged plan', (tester) async {
    await boot(tester, seed: false);
    await tester.tap(find.text('Get started'));
    await settle(tester);
    expect(location(), '/onboarding');

    Future<void> next() async {
      final btn = find.widgetWithText(BfButton, 'Continue').evaluate().isNotEmpty
          ? find.widgetWithText(BfButton, 'Continue')
          : find.widgetWithText(BfButton, 'Forge my plan');
      await tester.ensureVisible(btn);
      await tester.tap(btn);
      await settle(tester);
    }

    await tester.enterText(find.byType(TextField), 'Ama');
    await settle(tester, 200);
    for (var step = 1; step <= 8; step++) {
      await next();
      if (step == 5) {
        final ack = find.text("I understand and I'm ready to train");
        await tester.ensureVisible(ack);
        await settle(tester, 400);
        await tester.tap(ack);
        await settle(tester, 200);
      }
      if (step == 6) {
        await tester.tap(find.text(Goal.values.first.label));
        await settle(tester, 200);
      }
    }
    await next(); // Forge my plan
    await settle(tester, 6000); // the forge animation saves, then routes home
    expect(tester.takeException(), isNull);
    expect(location(), '/home');

    final uid = container.read(authProvider).userId!;
    final svc = TrainingService(DataContext(db: db, userId: uid, clock: clock));
    final p = await svc.profiles.getProfile();
    expect(p?.name, 'Ama');
    expect(p?.goals, {Goal.values.first});
    expect(await svc.profiles.getActiveProgram(), isNotNull);
    await shutdown(tester);
  });

  testWidgets('every screen renders with a fresh profile', (tester) async {
    await boot(tester);
    expect(location(), '/home');
    await visitAll(tester, container);
    await shutdown(tester);
  });

  testWidgets('every screen renders with five weeks of history', (tester) async {
    await boot(tester, demo: true);
    expect(location(), '/home');
    await visitAll(tester, container);
    await shutdown(tester);
  });

  testWidgets('every screen renders in light theme with reduced motion', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await boot(tester, demo: true);
    container.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: ThemeMode.light));
    await visitAll(tester, container);
    await shutdown(tester);
  });

  testWidgets('a quick session is started, played to the end, rated and saved', (tester) async {
    await boot(tester);
    final router = container.read(routerProvider);
    final base = container.read(sessionInputsProvider(DayType.fullBody))!;
    final plan = buildQuickSession(QuickOption.five, base, todaysDay: DayType.fullBody);
    container.read(pendingSessionProvider.notifier).set(plan);
    router.push('/session');
    await settle(tester);
    expect(find.text('Start workout'), findsOneWidget);

    // Swipe the start slider all the way across.
    final slider = find.byType(SwipeToStart);
    await tester.timedDragFrom(
        tester.getTopLeft(slider) + const Offset(32, 32), Offset(tester.getSize(slider).width, 0), const Duration(milliseconds: 400));
    await settle(tester);
    expect(find.byType(PlayerScreen), findsOneWidget);
    expect(container.read(playerProvider), isNotNull);

    // Play: tap Done on rep sets, skip rests, let timed holds run on the clock.
    var guard = 0;
    while (find.byType(PlayerScreen).evaluate().isNotEmpty && guard++ < 400) {
      final done = find.widgetWithText(BfButton, 'Done');
      final skipRest = find.widgetWithText(BfButton, 'Skip rest');
      if (done.evaluate().isNotEmpty) {
        await tester.tap(done.first);
      } else if (skipRest.evaluate().isNotEmpty) {
        await tester.tap(skipRest.first);
      } else {
        clock.advance(const Duration(seconds: 5));
      }
      await settle(tester, 300);
    }
    expect(find.byType(CompletionScreen), findsOneWidget, reason: 'player should hand over to the completion screen');
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Just right'));
    await settle(tester, 300);
    await tester.tap(find.widgetWithText(BfButton, 'Save workout'));
    await settle(tester, 1500);
    // Dismiss any PR / unlock / achievement celebrations.
    for (var i = 0; i < 8 && find.widgetWithText(BfButton, 'Continue').evaluate().isNotEmpty; i++) {
      await tester.tap(find.widgetWithText(BfButton, 'Continue').first);
      await settle(tester, 1200);
    }
    expect(tester.takeException(), isNull);

    final saved = await container.read(trainingRepoProvider).getWorkouts();
    expect(saved, hasLength(1));
    expect(saved.single.rating, Rating.good);
    expect(await container.read(trainingRepoProvider).getActiveSession(), isNull);
    await shutdown(tester);
  });
}

Future<void> visitAll(WidgetTester tester, ProviderContainer container) async {
  final router = container.read(routerProvider);
  final routes = [
    '/home',
    '/workout',
    '/progress',
    '/nutrition',
    '/profile',
    '/exercise/${kExercises.first.id}',
    '/exercise/wall_push_up',
    for (final p in kSkillPaths) '/skills/${p.id}',
    '/build',
    '/records',
    '/measurements',
    '/calendar',
    '/weekly',
    '/journey',
    '/report',
    '/achievements',
    '/food/${kFoods.first.id}',
    '/food/${kFoods.last.id}',
    '/meals',
    for (final c in kChallenges) '/challenge/${c.id}',
    '/settings',
    '/edit/goals',
    '/edit/fitness',
    '/edit/preferences',
    '/edit/body',
  ];
  final inputs = container.read(sessionInputsProvider(DayType.fullBody));
  if (inputs != null) {
    container.read(pendingSessionProvider.notifier).set(SessionBuilder(inputs).build());
    routes.add('/session');
  }
  final failures = <String>[];
  final original = FlutterError.onError;
  var current = '';
  FlutterError.onError = (d) {
    final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
    failures.add('$current → ${d.exceptionAsString().split('\n').first} @ $where');
  };
  try {
    for (final r in routes) {
      current = r;
      router.go(r);
      await settle(tester);
      if (find.byType(ErrorWidget).evaluate().isNotEmpty) failures.add('$r → shows an ErrorWidget');
    }
    current = '/home (return)';
    router.go('/home');
    await settle(tester);
  } finally {
    FlutterError.onError = original;
  }
  expect(failures.toSet().toList(), isEmpty, reason: failures.toSet().join('\n'));
}
