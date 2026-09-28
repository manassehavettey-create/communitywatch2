import 'package:bible_app/bible/references.dart';
import 'package:bible_app/bible/search.dart';
import 'package:bible_app/bible/translation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bible_test_data.dart';

void main() {
  late SearchIndex kjv;
  late SearchIndex web;

  setUpAll(() {
    kjv = SearchIndex.build(loadBundled('kjv'));
    web = SearchIndex.build(loadBundled('web'));
  });

  SearchResults find(
    SearchIndex i,
    String q, {
    SearchScope scope = SearchScope.all,
    String? book,
  }) => i.search(SearchQuery.parse(q), scope: scope, bookId: book);

  test('indexes every verse with text', () {
    expect(kjv.verseCount, 31102);
    // WEB leaves five verse numbers without text.
    expect(web.verseCount, 31103 - 5);
  });

  test('query parsing: phrases and words', () {
    final q = SearchQuery.parse('"Living Water" Jesus, said');
    expect(q.phrases, ['living water']);
    expect(q.words, ['jesus', 'said']);
    expect(SearchQuery.parse('   ').isEmpty, isTrue);
  });

  test('word search matches word prefixes, not mid-word', () {
    final r = find(kjv, 'wept');
    expect(r.hits.map((h) => h.ref), contains(const VerseRef('JHN', 11, 35)));
    // "love" finds "loved" (John 3:16); "egotten" (mid-word) finds nothing.
    expect(
      find(kjv, 'love', book: 'JHN').hits.map((h) => h.ref),
      contains(const VerseRef('JHN', 3, 16)),
    );
    expect(find(kjv, 'egotten').total, 0);
  });

  test('all loose words must appear', () {
    final r = find(kjv, 'begotten world');
    expect(r.total, greaterThan(0));
    for (final h in r.hits) {
      final t = h.text.toLowerCase();
      expect(t.contains('begotten') && t.contains('world'), isTrue);
    }
  });

  test('quoted phrase requires exact adjacent words', () {
    final r = find(kjv, '"shadow of death"');
    expect(r.hits.map((h) => h.ref), contains(const VerseRef('PSA', 23, 4)));
    for (final h in r.hits) {
      expect(h.text.toLowerCase(), contains('shadow of death'));
    }
    expect(find(kjv, '"death of shadow"').total, 0);
  });

  test('verses containing the whole query as a phrase rank first', () {
    final r = find(kjv, 'god so loved');
    expect(r.hits.first.ref, const VerseRef('JHN', 3, 16));
  });

  test('supplied-word brackets and curly apostrophes do not break search', () {
    // KJV Psalm 23:1 is stored as "The LORD [is] my shepherd".
    final r = find(kjv, '"lord is my shepherd"');
    expect(r.hits.single.ref, const VerseRef('PSA', 23, 1));
    expect(r.hits.single.text, 'The LORD is my shepherd; I shall not want.');
    // WEB uses a curly apostrophe in "name’s sake".
    expect(find(web, "name's sake").total, greaterThan(0));
  });

  test('scope and book filters', () {
    final all = find(kjv, 'faith').total;
    final nt = find(kjv, 'faith', scope: SearchScope.newTestament).total;
    final ot = find(kjv, 'faith', scope: SearchScope.oldTestament).total;
    expect(nt + ot, all);
    final heb = find(kjv, 'faith', book: 'HEB');
    expect(heb.hits.every((h) => h.ref.bookId == 'HEB'), isTrue);
    final gospels = find(kjv, 'wept', scope: SearchScope.gospels);
    expect(
      gospels.hits.every(
        (h) => h.ref.book.index >= 39 && h.ref.book.index <= 42,
      ),
      isTrue,
    );
  });

  test('match ranges point at the matched words', () {
    final hit = find(kjv, 'jesus wept').hits.first;
    final spans = hit.matches
        .map((m) => hit.text.substring(m.$1, m.$2))
        .toList();
    expect(spans, ['Jesus', 'wept']);
  });

  test('results are capped but the total is reported', () {
    final r = kjv.search(SearchQuery.parse('the'), limit: 50);
    expect(r.hits, hasLength(50));
    expect(r.total, greaterThan(20000));
  });

  test('plain text strips brackets only for supplied-word translations', () {
    expect(
      VerseText.plain('The LORD [is] good', suppliedWords: true),
      'The LORD is good',
    );
    expect(VerseText.plain('[Selah', suppliedWords: false), '[Selah');
    expect(VerseText.plain('a\nb', suppliedWords: false), 'a b');
    expect(VerseText.runs('The LORD [is] good', suppliedWords: true), [
      ('The LORD ', false),
      ('is', true),
      (' good', false),
    ]);
  });

  test('versesIn spans chapters and skips omitted verses', () {
    final bible = loadBundled('web');
    final r = bible.versesIn(
      VerseRange(const VerseRef('LUK', 17, 35), const VerseRef('LUK', 18, 1)),
    );
    // 17:36 has no text in the WEB.
    expect(r.map((e) => e.$1.code), ['LUK.17.35', 'LUK.17.37', 'LUK.18.1']);
  });
}
