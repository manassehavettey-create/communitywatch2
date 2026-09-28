import 'package:bible_app/bible/reference_parser.dart';
import 'package:bible_app/bible/references.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? label(String s) => ReferenceParser.parse(s)?.label;

  group('ReferenceParser', () {
    test('full names, abbreviations and case', () {
      expect(label('John 3:16'), 'John 3:16');
      expect(label('jn 3:16'), 'John 3:16');
      expect(label('JHN 3:16'), 'John 3:16');
      expect(label('Gen 1'), 'Genesis 1');
      expect(label('ps 23'), 'Psalms 23');
      expect(label('Psalm 119:105'), 'Psalms 119:105');
      expect(label('rev'), 'Revelation');
      expect(label('Song of Songs 2:4'), 'Song of Solomon 2:4');
      expect(label('phil 4:13'), 'Philippians 4:13');
      expect(label('philem 1:6'), 'Philemon 1:6');
    });

    test('numbered books in every common spelling', () {
      for (final s in [
        '1 Cor 13',
        '1cor 13',
        'I Corinthians 13',
        '1st Cor 13',
        'First Corinthians 13',
        '1 co 13',
      ]) {
        expect(label(s), '1 Corinthians 13', reason: s);
      }
      expect(label('2 tim 3:16'), '2 Timothy 3:16');
      expect(label('iii john 1:4'), '3 John 1:4');
      expect(label('1jn 1:9'), '1 John 1:9');
    });

    test('ranges within and across chapters', () {
      expect(label('John 3:16-18'), 'John 3:16–18');
      expect(label('John 3:16–18'), 'John 3:16–18');
      expect(label('Gen 1:1-2:3'), 'Genesis 1:1–2:3');
      expect(label('Gen 1-3'), 'Genesis 1–3');
      final r = ReferenceParser.parse('Gen 1:1-2:3')!.range!;
      expect(r.start, const VerseRef('GEN', 1, 1));
      expect(r.end, const VerseRef('GEN', 2, 3));
    });

    test('single-chapter books take a verse directly', () {
      expect(label('Jude 5'), 'Jude 1:5');
      expect(label('Jude 1'), 'Jude 1');
      expect(label('Obadiah 3-4'), 'Obadiah 1:3–4');
      expect(label('3 John 14'), '3 John 1:14');
    });

    test('rejects impossible or non-reference input', () {
      expect(ReferenceParser.parse(''), isNull);
      expect(ReferenceParser.parse('love one another'), isNull);
      expect(ReferenceParser.parse('Genesis 51'), isNull);
      expect(ReferenceParser.parse('John 0'), isNull);
      expect(ReferenceParser.parse('John 3:18-16'), isNull);
      expect(ReferenceParser.parse('Hezekiah 3'), isNull);
    });

    test('book suggestions by prefix', () {
      expect(
        ReferenceParser.suggestBooks('jo').map((b) => b.id),
        containsAll(['JOB', 'JOL', 'JON', 'JHN']),
      );
      expect(ReferenceParser.suggestBooks('1 j').first.id, '1JN');
    });
  });

  group('VerseRange', () {
    test('orders its ends and formats labels', () {
      final r = VerseRange(
        const VerseRef('JHN', 4, 2),
        const VerseRef('JHN', 3, 16),
      );
      expect(r.start.chapter, 3);
      expect(r.label, 'John 3:16–4:2');
      expect(VerseRange.parseCode(r.code), r);
      expect(
        VerseRange(
          const VerseRef('JHN', 21, 25),
          const VerseRef('ACT', 1, 3),
        ).label,
        'John 21:25–Acts 1:3',
      );
    });

    test('chapter navigation crosses book boundaries', () {
      expect(const ChapterRef('GEN', 50).next, const ChapterRef('EXO', 1));
      expect(const ChapterRef('EXO', 1).previous, const ChapterRef('GEN', 50));
      expect(const ChapterRef('REV', 22).next, isNull);
      expect(const ChapterRef('GEN', 1).previous, isNull);
    });
  });
}
