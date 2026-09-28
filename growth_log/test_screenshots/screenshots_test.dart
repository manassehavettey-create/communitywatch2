// Renders real screens (real fonts, icons and illustrations) with demo data
// so the UI can be reviewed without a device:
//
//   flutter test test_screenshots --update-goldens
//
// PNGs are written to test_screenshots/goldens/.
import 'dart:async';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:growth_log/app.dart';
import 'package:growth_log/core/db/database.dart';
import 'package:growth_log/core/providers.dart';
import 'package:growth_log/core/router.dart';
import 'package:growth_log/core/services/lock_service.dart';
import 'package:growth_log/core/utils/clock.dart';
import 'package:growth_log/core/widgets/app_image.dart';
import 'package:growth_log/features/settings/data/demo_seeder.dart';
import 'package:growth_log/features/settings/data/settings_repository.dart';
import 'package:growth_log/features/skills/data/milestone_repository.dart';
import 'package:growth_log/features/skills/domain/levels.dart';
import 'package:growth_log/features/skills/presentation/level_up.dart';

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(rootBundle.load(a));
    }
    await loader.load();
  }

  const f = 'assets/fonts';
  await load('Urbanist', [
    for (final w in ['Regular', 'Medium', 'MediumItalic', 'SemiBold', 'Bold', 'ExtraBold'])
      '$f/Urbanist-$w.ttf',
  ]);
  await load('Archivo', ['$f/Archivo-LightItalic.ttf', '$f/Archivo-ExtraBold.ttf', '$f/Archivo-Black.ttf']);
  await load('Roboto', ['$f/Urbanist-Medium.ttf']);
  for (final style in ['Regular', 'Bold', 'Fill']) {
    await load('Phosphor$style', ['$f/phosphor/Phosphor-$style.ttf']);
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> settle(WidgetTester tester, {int rounds = 12}) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> precache(WidgetTester tester) async {
    final ctx = tester.element(find.byType(Navigator).first);
    await tester.runAsync(() async {
      for (final a in [...AppAssets.all, for (final l in Levels.all) l.badgeAsset]) {
        await precacheImage(AssetImage(a), ctx);
      }
    });
  }

  Future<ProviderContainer> boot(
    WidgetTester tester, {
    required bool onboarded,
    ThemeMode theme = ThemeMode.light,
    bool seed = true,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(top: 162, bottom: 102);
    addTearDown(tester.view.reset);
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

    final db = AppDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime(2026, 9, 28, 10, 30));
    final settings = SettingsRepository(db);
    final loaded = await tester.runAsync(() async {
      if (seed) await DemoSeeder(db, clock).seed();
      await settings.set(SettingKeys.onboardingDone, onboarded);
      await settings.set(SettingKeys.themeMode, theme.name);
      return settings.load();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          initialSettingsProvider.overrideWithValue(loaded!),
          lockServiceProvider.overrideWithValue(LockService(store: MemorySecretStore())),
        ],
        child: const GrowthLogApp(),
      ),
    );
    await precache(tester);
    await settle(tester);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.runAsync(db.close);
    });
    return ProviderScope.containerOf(tester.element(find.byType(GrowthLogApp)));
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await expectLater(find.byType(GrowthLogApp), matchesGoldenFile('goldens/$name.png'));
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String location, {bool push = false}) async {
    final router = c.read(routerProvider);
    if (push) {
      unawaited(router.push(location));
    } else {
      router.go(location);
    }
    await settle(tester);
    await precache(tester);
  }

  testWidgets('onboarding', (tester) async {
    await boot(tester, onboarded: false, seed: false);
    await shot(tester, '01_onboarding_1');
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await shot(tester, '02_onboarding_2');
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await shot(tester, '03_onboarding_3');
  });

  testWidgets('first skill setup', (tester) async {
    final c = await boot(tester, onboarded: false, seed: false);
    await go(tester, c, Routes.setup);
    await shot(tester, '04_setup');
  });

  testWidgets('main tabs (light)', (tester) async {
    final c = await boot(tester, onboarded: true);
    await shot(tester, '05_home');
    await go(tester, c, Routes.skills);
    await shot(tester, '06_skills');
    await go(tester, c, Routes.log);
    await shot(tester, '07_log');
    await go(tester, c, Routes.insights);
    await shot(tester, '08_insights');
  });

  testWidgets('detail screens', (tester) async {
    final c = await boot(tester, onboarded: true);
    await go(tester, c, Routes.skill(1), push: true);
    await shot(tester, '09_skill_detail');
    await go(tester, c, Routes.recap(), push: true);
    await shot(tester, '10_recap');
    await go(tester, c, Routes.newEntry(), push: true);
    await shot(tester, '11_entry_editor');
    await go(tester, c, Routes.settings, push: true);
    await shot(tester, '12_settings');
  });

  testWidgets('timer running', (tester) async {
    final c = await boot(tester, onboarded: true);
    await tester.runAsync(() => c.read(timerRepositoryProvider).start(2));
    (c.read(clockProvider) as FixedClock).advance(const Duration(minutes: 27, seconds: 14));
    await go(tester, c, Routes.timer(), push: true);
    await shot(tester, '13_timer');
    await go(tester, c, Routes.home);
    await shot(tester, '14_home_with_timer');
  });

  testWidgets('home + skill (dark)', (tester) async {
    final c = await boot(tester, onboarded: true, theme: ThemeMode.dark);
    await shot(tester, '15_home_dark');
    await go(tester, c, Routes.insights);
    await shot(tester, '16_insights_dark');
  });

  testWidgets('level up', (tester) async {
    await boot(tester, onboarded: true);
    final ctx = tester.element(find.byType(Navigator).first);
    unawaited(celebrate(ctx, const [
      Achievement(skillId: 1, skillName: 'Guitar', hours: 100, skillColor: 0xFFC8EC64),
    ]));
    await tester.pump(const Duration(milliseconds: 1200));
    await shot(tester, '17_level_up');
  });
}
