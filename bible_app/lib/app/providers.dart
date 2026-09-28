import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bible/bible_repository.dart';
import '../bible/references.dart';
import '../bible/translation.dart';
import '../data/auth/auth_service.dart';
import '../data/db/database.dart';
import '../data/notifications/reminder_service.dart';
import '../data/repos/annotations_repository.dart';
import '../data/repos/journal_repository.dart';
import '../data/repos/plans_repository.dart';
import '../data/repos/prayer_repository.dart';
import '../data/repos/preferences_repository.dart';
import '../data/repos/reading_repository.dart';
import '../data/sync/sync_service.dart';
import '../data/sync/sync_writer.dart';
import '../domain/plans.dart';

// ---------------------------------------------------------------------------
// Singletons, created in main() and injected with overrides.
// ---------------------------------------------------------------------------

final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final syncServiceProvider = Provider<SyncService>(
  (ref) => throw UnimplementedError('Overridden in main()'),
);

final bibleRepositoryProvider = Provider<BibleRepository>(
  (ref) => BibleRepository(),
);

final reminderServiceProvider = Provider<ReminderService>(
  (ref) => ReminderService(FlutterLocalNotificationsPlugin()),
);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final syncWriterProvider = Provider<SyncWriter>((ref) {
  final auth = ref.watch(authServiceProvider);
  return SyncWriter(ref.watch(databaseProvider), () => auth.currentUser?.id);
});

final preferencesRepositoryProvider = Provider(
  (ref) => PreferencesRepository(ref.watch(syncWriterProvider)),
);
final annotationsRepositoryProvider = Provider(
  (ref) => AnnotationsRepository(ref.watch(syncWriterProvider)),
);
final readingRepositoryProvider = Provider(
  (ref) => ReadingRepository(ref.watch(syncWriterProvider)),
);
final plansRepositoryProvider = Provider(
  (ref) => PlansRepository(ref.watch(syncWriterProvider)),
);
final prayerRepositoryProvider = Provider(
  (ref) => PrayerRepository(ref.watch(syncWriterProvider)),
);
final journalRepositoryProvider = Provider(
  (ref) => JournalRepository(ref.watch(syncWriterProvider)),
);

// ---------------------------------------------------------------------------
// Account and sync
// ---------------------------------------------------------------------------

final currentUserProvider = StreamProvider<AppUser?>((ref) async* {
  final auth = ref.watch(authServiceProvider);
  yield auth.currentUser;
  yield* auth.userChanges;
});

final syncStatusProvider = StreamProvider<SyncStatus>((ref) async* {
  final sync = ref.watch(syncServiceProvider);
  yield sync.status;
  yield* sync.statusChanges;
});

// ---------------------------------------------------------------------------
// Preferences and Scripture
// ---------------------------------------------------------------------------

final prefsProvider = StreamProvider<ReaderPrefs>(
  (ref) => ref.watch(preferencesRepositoryProvider).watch(),
);

/// Current prefs, or defaults while loading.
final prefsValueProvider = Provider<ReaderPrefs>(
  (ref) => ref.watch(prefsProvider).value ?? const ReaderPrefs(),
);

final catalogProvider = FutureProvider<TranslationCatalog>(
  (ref) => ref.watch(bibleRepositoryProvider).catalog(),
);

final _translationIdProvider = Provider<String?>(
  (ref) => ref.watch(prefsValueProvider.select((p) => p.translationId)),
);

final currentTranslationProvider = FutureProvider<TranslationInfo>((ref) async {
  final id = ref.watch(_translationIdProvider);
  final catalog = await ref.watch(catalogProvider.future);
  return catalog.resolve(id);
});

final bibleTextProvider = FutureProvider.autoDispose.family<BibleText, String>((
  ref,
  id,
) async {
  final catalog = await ref.watch(catalogProvider.future);
  return ref.watch(bibleRepositoryProvider).load(catalog.resolve(id));
});

final currentBibleProvider = FutureProvider.autoDispose<BibleText>((ref) async {
  final info = await ref.watch(currentTranslationProvider.future);
  return ref.watch(bibleTextProvider(info.id).future);
});

final chapterAnnotationsProvider = StreamProvider.autoDispose
    .family<ChapterAnnotations, ChapterRef>(
      (ref, chapter) =>
          ref.watch(annotationsRepositoryProvider).watchChapter(chapter),
    );

// ---------------------------------------------------------------------------
// Lists
// ---------------------------------------------------------------------------

final readingStatsProvider = StreamProvider<ReadingStats>(
  (ref) => ref.watch(readingRepositoryProvider).watchStats(),
);

final readChaptersProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(readingRepositoryProvider).watchReadChapterCodes(),
);

final planCatalogProvider = FutureProvider<List<PlanDefinition>>(
  (ref) => ref.watch(plansRepositoryProvider).catalog(),
);

final userPlansProvider = StreamProvider<List<UserPlan>>(
  (ref) => ref.watch(plansRepositoryProvider).watchUserPlans(),
);

final highlightsProvider = StreamProvider<List<Highlight>>(
  (ref) => ref.watch(annotationsRepositoryProvider).watchHighlights(),
);
final notesProvider = StreamProvider<List<Note>>(
  (ref) => ref.watch(annotationsRepositoryProvider).watchNotes(),
);
final bookmarksProvider = StreamProvider<List<Bookmark>>(
  (ref) => ref.watch(annotationsRepositoryProvider).watchBookmarks(),
);
final savedVersesProvider = StreamProvider<List<SavedVerse>>(
  (ref) => ref.watch(annotationsRepositoryProvider).watchSaved(),
);

final prayersProvider = StreamProvider<List<Prayer>>(
  (ref) => ref.watch(prayerRepositoryProvider).watchAll(),
);

final journalProvider = StreamProvider<List<JournalItem>>(
  (ref) => ref.watch(journalRepositoryProvider).watchAll(),
);

/// Device-local setting stored in key_values.
final localSettingProvider = StreamProvider.family<String?, String>(
  (ref, key) => ref.watch(databaseProvider).watchValue(key),
);
