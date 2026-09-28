import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/app.dart';
import 'package:growth_log/core/db/database.dart';
import 'package:growth_log/core/providers.dart';
import 'package:growth_log/core/router.dart';
import 'package:growth_log/core/services/lock_service.dart';
import 'package:growth_log/core/utils/clock.dart';
import 'package:growth_log/features/log/data/entry_repository.dart';
import 'package:growth_log/features/settings/data/settings_repository.dart';
import 'package:growth_log/features/skills/data/skill_repository.dart';

/// End-to-end flows through the real widget tree with an in-memory DB.
void main() {
  late AppDatabase db;
  late FixedClock clock;

  Future<void> settle(WidgetTester tester, {int rounds = 10}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<ProviderContainer> boot(
    WidgetTester tester, {
    bool onboarded = true,
    Future<void> Function()? before,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 9, 28, 10));
    final settings = await tester.runAsync(() async {
      await SettingsRepository(db).set(SettingKeys.onboardingDone, onboarded);
      await before?.call();
      return SettingsRepository(db).load();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          initialSettingsProvider.overrideWithValue(settings!),
          lockServiceProvider.overrideWithValue(
            LockService(store: MemorySecretStore()),
          ),
        ],
        child: const GrowthLogApp(),
      ),
    );
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
    return ProviderScope.containerOf(tester.element(find.byType(GrowthLogApp)));
  }

  testWidgets('onboarding → first skill → home', (tester) async {
    await boot(tester, onboarded: false);
    expect(find.text('Growth Log'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.bySemanticsLabel(RegExp('Next|Get started')));
      await settle(tester);
    }
    expect(find.text('Skip for now'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'Ukulele');
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text("Let's start"),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text("Let's start"));
    await settle(tester, rounds: 15);

    expect(find.text('Your skills'), findsOneWidget);
    expect(find.text('Ukulele'), findsWidgets);
    final skills = await tester.runAsync(
      () => SkillRepository(db, clock).listSkills(),
    );
    expect(skills!.single.name, 'Ukulele');
  });

  testWidgets('empty states render on every tab', (tester) async {
    final c = await boot(tester);
    expect(find.text('Add your first skill'), findsOneWidget);
    c.read(routerProvider).go(Routes.skills);
    await settle(tester);
    expect(find.text('Plant your first flag'), findsOneWidget);
    c.read(routerProvider).go(Routes.log);
    await settle(tester);
    expect(find.text('Your log is waiting'), findsOneWidget);
    c.read(routerProvider).go(Routes.insights);
    await settle(tester);
    expect(find.text('Nothing here yet'), findsOneWidget);
  });

  testWidgets('log a session via quick add, milestone becomes a win', (
    tester,
  ) async {
    await boot(
      tester,
      before: () => SkillRepository(db, clock).createSkill(
        const SkillDraft(
          name: 'Piano',
          iconKey: 'piano',
          colorValue: 0xFFB6A3FF,
        ),
      ),
    );

    await tester.tap(find.bySemanticsLabel('Add'));
    await settle(tester);
    await tester.tap(find.text('Log practice'));
    await settle(tester);
    expect(find.text('Save session'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('1h'));
    await settle(tester);
    await tester.tap(find.text('Save session'));
    await settle(tester, rounds: 15);

    // 1 hour reached → a milestone win exists and the dashboard shows it.
    final wins = await tester.runAsync(
      () => EntryRepository(
        db,
        clock,
      ).query(const EntryFilter(type: EntryType.win)),
    );
    expect(wins!.single.entry.body, contains('1 hour of Piano'));
    expect(find.text('1h 0m'), findsOneWidget); // "This week" hero
    expect(find.textContaining('1h across 1 session'), findsOneWidget);
  });

  testWidgets('write a gratitude entry, then find it by search', (
    tester,
  ) async {
    final c = await boot(tester);
    unawaited(c.read(routerProvider).push(Routes.newEntry()));
    await settle(tester);

    await tester.enterText(
      find.byType(TextField).first,
      'Pancakes with the kids',
    );
    await tester.enterText(
      find.widgetWithText(TextField, '+ add tag'),
      'family',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);
    await tester.tap(find.text('Save to log'));
    await settle(tester, rounds: 15);

    c.read(routerProvider).go(Routes.log);
    await settle(tester);
    expect(find.text('Pancakes with the kids'), findsOneWidget);
    expect(find.text('#family'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search entries, tags, skills'),
      'zzz',
    );
    await settle(tester);
    expect(find.text('No matches'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search entries, tags, skills'),
      'pancake',
    );
    await settle(tester);
    expect(find.text('Pancakes with the kids'), findsOneWidget);
  });

  testWidgets('timer survives a restart and saves the session', (tester) async {
    late int skillId;
    final c = await boot(
      tester,
      before: () async {
        skillId = await SkillRepository(db, clock).createSkill(
          const SkillDraft(
            name: 'Chess',
            iconKey: 'strategy',
            colorValue: 0xFFF4DD7D,
          ),
        );
      },
    );
    unawaited(c.read(routerProvider).push(Routes.timer(skillId)));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('Start Chess timer'));
    await settle(tester);
    expect(find.text('Stop & save'), findsOneWidget);

    // 50 minutes pass while the app is closed.
    clock.advance(const Duration(minutes: 50));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.text('00:50:00'), findsOneWidget);

    await tester.tap(find.text('Stop & save'));
    await settle(tester);
    await tester.tap(find.text('Save 50m'));
    await settle(tester, rounds: 15);

    final total = await tester.runAsync(
      () => SkillRepository(db, clock).totalSeconds(skillId),
    );
    expect(total, 50 * 60);
  });

  testWidgets('app lock blocks the UI until the PIN is entered', (
    tester,
  ) async {
    final lock = LockService(store: MemorySecretStore());
    await tester.runAsync(() => lock.setPin('2468'));
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    db = AppDatabase(NativeDatabase.memory());
    clock = FixedClock(DateTime(2026, 9, 28, 10));
    final settings = await tester.runAsync(() async {
      final repo = SettingsRepository(db);
      await repo.set(SettingKeys.onboardingDone, true);
      await repo.set(SettingKeys.lockEnabled, true);
      return repo.load();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          initialSettingsProvider.overrideWithValue(settings!),
          lockServiceProvider.overrideWithValue(lock),
        ],
        child: const GrowthLogApp(),
      ),
    );
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
    await settle(tester);
    expect(find.text('Welcome back'), findsOneWidget);

    Future<void> enter(String pin) async {
      for (final d in pin.split('')) {
        await tester.tap(find.bySemanticsLabel(d).last);
        await tester.pump();
      }
      await settle(tester, rounds: 20);
    }

    await enter('1111');
    expect(find.text('Welcome back'), findsOneWidget);
    await enter('2468');
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Your skills'), findsOneWidget);
  });
}
