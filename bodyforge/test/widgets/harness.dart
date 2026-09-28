import 'package:bodyforge/app/app.dart';
import 'package:bodyforge/app/notifications.dart';
import 'package:bodyforge/app/providers.dart';
import 'package:bodyforge/app/router.dart';
import 'package:bodyforge/app/settings.dart';
import 'package:bodyforge/data/local/database.dart';
import 'package:bodyforge/data/repositories/data_context.dart';
import 'package:bodyforge/data/services/demo_data.dart';
import 'package:bodyforge/data/services/training_service.dart';
import 'package:bodyforge/domain/models/local_date.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/helpers.dart';

/// Records scheduling calls instead of talking to the platform plugin.
class FakeNotifications extends NotificationService {
  final calls = <String>[];
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> scheduleTrainingReminders({required List<int> weekdays, required int minutes}) async =>
      calls.add('train:${weekdays.join(',')}@$minutes');
  @override
  Future<void> cancelTrainingReminders() async => calls.add('cancelTrain');
  @override
  Future<void> scheduleWeeklyCheck() async => calls.add('weekly');
  @override
  Future<void> cancelWeeklyCheck() async => calls.add('cancelWeekly');
  @override
  Future<void> scheduleRestEnd(DateTime at, String next) async {}
  @override
  Future<void> cancelRestEnd() async {}
}

const kSmokeUser = 'smoke-user';

/// Wraps the whole app so tests can capture screenshots.
final kScreenKey = GlobalKey();

Future<void> loadAppFonts() async {
  for (final (family, weights) in [('Sora', [400, 500, 600, 700, 800]), ('Manrope', [400, 500, 600, 700, 800]), ('BfSymbols', [400, 700])]) {
    final loader = FontLoader(family);
    for (final w in weights) {
      loader.addFont(rootBundle.load('assets/fonts/$family-$w.ttf'));
    }
    await loader.load();
  }
}

/// Boots the real app on a 360×780 dp phone with an in-memory database,
/// fake notifications and a fixed clock.
class Harness {
  Harness._(this.tester, this.db, this.clock, this.container);
  final WidgetTester tester;
  final AppDatabase db;
  final FixedClock clock;
  final ProviderContainer container;

  static Future<Harness> boot(WidgetTester tester, {bool seed = true, bool demo = false}) async {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(seed ? {'bf.auth.localUserId': kSmokeUser} : {});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    final clock = FixedClock(DateTime.now());
    if (seed) {
      await tester.runAsync(() async {
        final svc = TrainingService(DataContext(db: db, userId: kSmokeUser, clock: clock));
        await svc.completeOnboarding(profile().copyWith(name: 'Kofi Boateng'));
        if (demo) await loadDemoData(svc, weeks: 5);
      });
    }
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        notificationsProvider.overrideWithValue(FakeNotifications()),
        clockProvider.overrideWithValue(clock),
      ],
    );
    await tester.pumpWidget(RepaintBoundary(
      key: kScreenKey,
      child: UncontrolledProviderScope(container: container, child: const BodyforgeApp()),
    ));
    await settle(tester, 2500); // splash
    return Harness._(tester, db, clock, container);
  }

  String get location => container.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  Future<void> shutdown() async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
    // The database was opened in the test's fake-async zone, so close it there.
    final closing = db.close();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await closing;
  }
}

/// Pump frames for [ms] without waiting for infinite animations to stop.
Future<void> settle(WidgetTester tester, [int ms = 900]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  // Let drift stream queries deliver.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pump(const Duration(milliseconds: 100));
}

