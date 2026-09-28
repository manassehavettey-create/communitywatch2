import 'package:drift/drift.dart';

import '../../bible/references.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/typography.dart';
import '../db/database.dart';
import '../db/tables.dart';
import '../sync/sync_writer.dart';

/// Reading preferences with defaults applied.
class ReaderPrefs {
  const ReaderPrefs({
    this.translationId,
    this.font = ScriptureFont.literata,
    this.fontSize = 19,
    this.lineHeight = 1.65,
    this.readerTheme = 'auto',
    this.appTheme = AppThemeMode.system,
    this.showVerseNumbers = true,
    this.paragraphMode = true,
    this.suppliedItalics = true,
    this.lastChapter,
    this.lastVerse,
    this.lastReadAt,
  });

  final String? translationId;
  final ScriptureFont font;
  final double fontSize;
  final double lineHeight;

  /// 'auto' or a [ReaderTheme] name.
  final String readerTheme;
  final AppThemeMode appTheme;
  final bool showVerseNumbers;
  final bool paragraphMode;
  final bool suppliedItalics;
  final ChapterRef? lastChapter;
  final int? lastVerse;
  final DateTime? lastReadAt;

  static const minFontSize = 15.0;
  static const maxFontSize = 30.0;
  static const minLineHeight = 1.4;
  static const maxLineHeight = 2.0;

  factory ReaderPrefs.fromRow(Preference? r) {
    if (r == null) return const ReaderPrefs();
    ChapterRef? last;
    final code = r.lastChapter;
    if (code != null) {
      try {
        last = ChapterRef.parseCode(code);
        last.book; // validates the book id
      } on Object {
        last = null;
      }
    }
    return ReaderPrefs(
      translationId: r.translationId,
      font: ScriptureFont.fromName(r.scriptureFont),
      fontSize: r.fontSize.clamp(minFontSize, maxFontSize),
      lineHeight: r.lineHeight.clamp(minLineHeight, maxLineHeight),
      readerTheme: r.readerTheme,
      appTheme: AppThemeMode.fromName(r.appTheme),
      showVerseNumbers: r.showVerseNumbers,
      paragraphMode: r.paragraphMode,
      suppliedItalics: r.suppliedItalics,
      lastChapter: last,
      lastVerse: r.lastVerse,
      lastReadAt: r.lastReadAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(r.lastReadAt!),
    );
  }
}

class PreferencesRepository {
  PreferencesRepository(this._w);

  final SyncWriter _w;
  AppDatabase get _db => _w.db;

  Stream<ReaderPrefs> watch() =>
      (_db.select(_db.preferences)
            ..where((p) => p.id.equals(Preferences.rowId)))
          .watchSingleOrNull()
          .map(ReaderPrefs.fromRow);

  Future<ReaderPrefs> read() async => ReaderPrefs.fromRow(
    await (_db.select(
      _db.preferences,
    )..where((p) => p.id.equals(Preferences.rowId))).getSingleOrNull(),
  );

  /// Applies [changes] to the single preferences row, creating it first if
  /// needed.
  Future<void> update(PreferencesCompanion changes) =>
      _w.write('preferences', Preferences.rowId, (t) async {
        await _db
            .into(_db.preferences)
            .insert(
              PreferencesCompanion.insert(
                id: Preferences.rowId,
                userId: Value(_w.userId),
                createdAt: t,
                updatedAt: t,
              ),
              mode: InsertMode.insertOrIgnore,
            );
        await (_db.update(_db.preferences)
              ..where((p) => p.id.equals(Preferences.rowId)))
            .write(changes.copyWith(updatedAt: Value(t)));
      });

  Future<void> setTranslation(String id) =>
      update(PreferencesCompanion(translationId: Value(id)));

  Future<void> setLastPosition(VerseRef ref) => update(
    PreferencesCompanion(
      lastChapter: Value(ref.chapterRef.code),
      lastVerse: Value(ref.verse),
      lastReadAt: Value(_w.now()),
    ),
  );
}
