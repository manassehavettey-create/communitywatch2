import 'canon.dart';
import 'references.dart';
import 'translation.dart';

/// Scope filter for text search.
enum SearchScope {
  all('Whole Bible'),
  oldTestament('Old Testament'),
  newTestament('New Testament'),
  gospels('Gospels');

  const SearchScope(this.label);
  final String label;

  bool includes(BookInfo b) => switch (this) {
    SearchScope.all => true,
    SearchScope.oldTestament => b.testament == Testament.old,
    SearchScope.newTestament => b.testament == Testament.newT,
    SearchScope.gospels => const {'MAT', 'MRK', 'LUK', 'JHN'}.contains(b.id),
  };
}

class SearchHit {
  const SearchHit(this.ref, this.text, this.matches);

  final VerseRef ref;

  /// Display text (supplied-word brackets removed, poetry lines joined).
  final String text;

  /// Character ranges in [text] to emphasise.
  final List<(int, int)> matches;
}

class SearchResults {
  const SearchResults(this.query, this.hits, this.total);

  final SearchQuery query;
  final List<SearchHit> hits;

  /// Total matches, which may exceed [hits] when results are capped.
  final int total;

  static const empty = SearchResults(SearchQuery.empty, [], 0);
}

/// A parsed search query: quoted phrases must match exactly; loose words
/// must all appear, each as a word or word prefix ("love" finds "loved").
class SearchQuery {
  const SearchQuery(this.phrases, this.words);

  final List<String> phrases;
  final List<String> words;

  static const empty = SearchQuery([], []);

  bool get isEmpty => phrases.isEmpty && words.isEmpty;

  static SearchQuery parse(String input) {
    final phrases = <String>[];
    final rest = input.replaceAllMapped(RegExp(r'"([^"]*)"?'), (m) {
      final p = SearchIndex.normalise(m.group(1)!).trim();
      if (p.isNotEmpty) phrases.add(p);
      return ' ';
    });
    final words = SearchIndex.normalise(rest)
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    return SearchQuery(phrases, words);
  }
}

/// In-memory full-text index over one translation.
///
/// Each verse is normalised once (lower case, punctuation → spaces, padded
/// with spaces) so matching is plain substring checks: `" love"` is a word
/// prefix and `" love "` a whole word. Scanning all 31k verses takes tens of
/// milliseconds, needs no on-disk index and behaves the same on every
/// platform.
class SearchIndex {
  SearchIndex._(this.translationId, this._refs, this._display, this._norm);

  factory SearchIndex.build(BibleText bible) {
    final refs = <VerseRef>[];
    final display = <String>[];
    final norm = <String>[];
    for (final ch in bible.allChapters) {
      for (var v = 1; v <= ch.verseCount; v++) {
        final raw = ch.verse(v);
        if (raw.isEmpty) continue;
        final plain = VerseText.plain(
          raw,
          suppliedWords: bible.info.suppliedWords,
        );
        refs.add(VerseRef(ch.ref.bookId, ch.ref.chapter, v));
        display.add(plain);
        norm.add(' ${normalise(plain)} ');
      }
    }
    return SearchIndex._(bible.info.id, refs, display, norm);
  }

  final String translationId;
  final List<VerseRef> _refs;
  final List<String> _display;
  final List<String> _norm;

  int get verseCount => _refs.length;

  static final _apostrophes = RegExp('[’‘`´]');
  static final _nonWord = RegExp(r"[^a-z0-9']+");

  /// Lower-cases, folds curly apostrophes and turns every other
  /// non-alphanumeric run into a single space.
  static String normalise(String s) => s
      .toLowerCase()
      .replaceAll(_apostrophes, "'")
      .replaceAll(_nonWord, ' ')
      .replaceAll(RegExp(r"(^|\s)'+|'+(\s|$)"), ' ')
      .trim();

  SearchResults search(
    SearchQuery query, {
    SearchScope scope = SearchScope.all,
    String? bookId,
    int limit = 300,
  }) {
    if (query.isEmpty) return SearchResults(query, const [], 0);
    final phraseNeedles = [for (final p in query.phrases) ' $p '];
    final wordNeedles = [for (final w in query.words) ' $w'];
    final wholeWords = [for (final w in query.words) ' $w '];
    // The whole loose query as a phrase ranks higher when present.
    final looseAsPhrase = query.words.length > 1
        ? ' ${query.words.join(' ')}'
        : null;

    final scored = <(int, int)>[]; // (score, index)
    for (var i = 0; i < _norm.length; i++) {
      final ref = _refs[i];
      if (bookId != null && ref.bookId != bookId) continue;
      if (!scope.includes(ref.book)) continue;
      final n = _norm[i];
      var ok = true;
      for (final p in phraseNeedles) {
        if (!n.contains(p)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      for (final w in wordNeedles) {
        if (!n.contains(w)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      var score = 0;
      if (looseAsPhrase != null && n.contains(looseAsPhrase)) score += 4;
      for (final w in wholeWords) {
        if (n.contains(w)) score += 1;
      }
      scored.add((score, i));
    }
    // Best score first, then canonical order (indices are canonical).
    scored.sort((a, b) {
      final s = b.$1.compareTo(a.$1);
      return s != 0 ? s : a.$2.compareTo(b.$2);
    });
    final hits = [
      for (final (_, i) in scored.take(limit))
        SearchHit(_refs[i], _display[i], _matchRanges(_display[i], query)),
    ];
    return SearchResults(query, hits, scored.length);
  }

  static List<(int, int)> _matchRanges(String text, SearchQuery q) {
    final ranges = <(int, int)>[];
    final lower = text.toLowerCase().replaceAll(_apostrophes, "'");
    void find(RegExp re) {
      for (final m in re.allMatches(lower)) {
        ranges.add((m.start, m.end));
      }
    }

    for (final p in q.phrases) {
      final pattern = p.split(' ').map(RegExp.escape).join(r"[^a-z0-9']+");
      find(RegExp('\\b$pattern\\b'));
    }
    for (final w in q.words) {
      find(RegExp("\\b${RegExp.escape(w)}[a-z0-9']*"));
    }
    ranges.sort((a, b) => a.$1.compareTo(b.$1));
    // Merge overlaps.
    final merged = <(int, int)>[];
    for (final r in ranges) {
      if (merged.isNotEmpty && r.$1 <= merged.last.$2) {
        final last = merged.removeLast();
        merged.add((last.$1, r.$2 > last.$2 ? r.$2 : last.$2));
      } else {
        merged.add(r);
      }
    }
    return merged;
  }
}
