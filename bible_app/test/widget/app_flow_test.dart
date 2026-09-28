import 'package:bible_app/app/app.dart';
import 'package:bible_app/app/providers.dart';
import 'package:bible_app/bible/references.dart';
import 'package:bible_app/data/auth/auth_service.dart';
import 'package:bible_app/data/db/database.dart';
import 'package:bible_app/data/sync/sync_service.dart';
import 'package:bible_app/features/reader/reader_screen.dart';
import 'package:bible_app/core/theme/app_theme.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Runs real async work (asset loading, isolates, database) and then lets
/// the UI settle.
Future<void> settle(WidgetTester tester, [int rounds = 12]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pumps (with real async work in between) until [finder] matches.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await settle(tester, 1);
    if (finder.evaluate().isNotEmpty) return;
  }
  final texts = find
      .byType(Text)
      .evaluate()
      .map((e) => (e.widget as Text).data)
      .whereType<String>()
      .take(20)
      .join(' | ');
  throw TestFailure('Timed out waiting for $finder. On screen: $texts');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // rootBundle caches asset futures, and a future created in one test's
    // fake-async zone never resumes in the next test's zone.
    rootBundle.clear();
  });

  // Closed after the test's fake-async zone has ended: drift's stream
  // cleanup timers belong to that zone and can't run inside runAsync.
  tearDown(() => db.close());

  List<Override> overrides() => [
    databaseProvider.overrideWithValue(db),
    authServiceProvider.overrideWithValue(AuthService.disabled()),
    // Not started: no connectivity plugin in widget tests.
    syncServiceProvider.overrideWithValue(SyncService(db)),
  ];

  Future<void> tearDownApp(WidgetTester tester) async {
    // Unmount so streams are cancelled and timers stop.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('first launch: onboarding, then Home with the verse of the day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: const BibleApp(onboarded: false),
      ),
    );
    await settle(tester);
    expect(find.text('Scripture,'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await settle(tester, 20);

    expect(find.textContaining('Good'), findsWidgets); // greeting
    expect(find.text('VERSE OF THE DAY'), findsOneWidget);
    // The verse text itself loads from the bundled KJV.
    await pumpUntil(tester, find.textContaining('· KJV'));
    expect(await db.getValue('onboarding.done'), '1');
    await tearDownApp(tester);
  });

  testWidgets('reader: select a verse, highlight it, and it is saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReaderScreen(
            args: ReaderArgs(target: VerseRef('JHN', 11, 35)),
          ),
        ),
      ),
    );
    // John 11:35 is on screen once the KJV has loaded.
    await pumpUntil(
      tester,
      find.textContaining('Jesus wept.', findRichText: true),
    );
    // Let the reader scroll to the verse.
    await settle(tester, 4);

    // Each verse is announced to screen readers with its number.
    final handle = tester.ensureSemantics();
    expect(find.semantics.byLabel(RegExp(r'^Verse 35\.')), findsOne);

    // Tap the verse text itself.
    await tester.tapOnText(find.textRange.ofSubstring('Jesus wept.'));
    await settle(tester, 6);
    expect(find.text('John 11:35'), findsOneWidget); // action panel title

    await tester.tap(find.bySemanticsLabel('Butter highlight'));
    await settle(tester, 8);

    final highlights = await tester.runAsync(
      () => db.select(db.highlights).get(),
    );
    expect(highlights, hasLength(1));
    expect(highlights!.single.startRef, 'JHN.11.35');
    expect(highlights.single.color, 'butter');
    // The write was queued for sync.
    final outbox = await tester.runAsync(() => db.select(db.outbox).get());
    expect(outbox!.map((o) => o.entityTable), contains('highlights'));

    handle.dispose();
    await tearDownApp(tester);
  });
}
