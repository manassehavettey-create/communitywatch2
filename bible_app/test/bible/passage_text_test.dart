import 'package:bible_app/bible/references.dart';
import 'package:bible_app/features/reader/passage_text.dart';
import 'package:flutter_test/flutter_test.dart';

import 'bible_test_data.dart';

void main() {
  final kjv = PassageText(loadBundled('kjv'));
  final web = PassageText(loadBundled('web'));
  VerseRef v(String code) => VerseRef.parseCode(code);

  test('single verse', () {
    final sel = [v('JHN.11.35')];
    expect(kjv.label(sel), 'John 11:35');
    expect(kjv.shareText(sel), '“Jesus wept.”\n— John 11:35 (KJV)');
  });

  test('contiguous verses become one run with verse numbers in text', () {
    final sel = [v('JHN.3.17'), v('JHN.3.16')];
    expect(kjv.runs(sel), hasLength(1));
    expect(kjv.label(sel), 'John 3:16–17');
    expect(kjv.body(sel), startsWith('16 For God so loved'));
    expect(kjv.body(sel), contains(' 17 For God sent not'));
  });

  test('gaps split runs and labels stay compact', () {
    final sel = [v('PSA.23.1'), v('PSA.23.2'), v('PSA.23.4'), v('PSA.23.6')];
    expect(kjv.label(sel), 'Psalms 23:1–2, 4, 6');
  });

  test('a selection spanning a chapter boundary is one run', () {
    final sel = [v('GEN.1.31'), v('GEN.2.1')];
    final runs = kjv.runs(sel);
    expect(runs, hasLength(1));
    expect(runs.single.label, 'Genesis 1:31–2:1');
  });

  test('a selection spanning books is one run', () {
    final sel = [v('MAL.4.6'), v('MAT.1.1')];
    expect(kjv.runs(sel), hasLength(1));
    expect(kjv.label(sel), 'Malachi 4:6–Matthew 1:1');
  });

  test('verses a translation omits do not break a run', () {
    // WEB leaves Luke 17:36 empty.
    final sel = [v('LUK.17.35'), v('LUK.17.37')];
    expect(web.runs(sel), hasLength(1));
    expect(web.body(sel), isNot(contains('36 ')));
    // KJV has 17:36, so the same pair is two runs there.
    expect(kjv.runs(sel), hasLength(2));
  });

  test('supplied-word brackets are removed from shared KJV text', () {
    expect(
      kjv.body([v('PSA.23.1')]),
      'The LORD is my shepherd; I shall not want.',
    );
  });
}
