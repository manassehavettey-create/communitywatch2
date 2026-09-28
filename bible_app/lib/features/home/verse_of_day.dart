import '../../bible/references.dart';

/// A year of well-loved passages for Verse of the Day, cycled by day of
/// the year. Stored as translation-independent references so the verse
/// appears in whichever translation the reader uses.
const _passages = [
  'JHN.3.16',
  'PSA.23.1-PSA.23.3',
  'PRO.3.5-PRO.3.6',
  'ISA.40.31',
  'PHP.4.6-PHP.4.7',
  'ROM.8.28',
  'JER.29.11',
  'MAT.11.28-MAT.11.30',
  'PSA.46.1',
  'JOS.1.9',
  'LAM.3.22-LAM.3.23',
  'ROM.12.2',
  'PHP.4.13',
  'MAT.6.33',
  '2CO.5.17',
  'GAL.5.22-GAL.5.23',
  'PSA.119.105',
  'ISA.41.10',
  'HEB.11.1',
  'JHN.14.27',
  '1CO.13.4-1CO.13.7',
  'EPH.2.8-EPH.2.9',
  'PSA.121.1-PSA.121.2',
  'MIC.6.8',
  'ROM.15.13',
  'JAS.1.5',
  '1JN.4.19',
  'PSA.34.18',
  'COL.3.23',
  'ZEP.3.17',
  'MAT.5.14-MAT.5.16',
  'ISA.26.3',
  'PSA.139.14',
  '2TI.1.7',
  'JHN.15.5',
  'ROM.5.8',
  'PSA.37.4',
  'HEB.13.8',
  'DEU.31.6',
  '1PE.5.7',
  'PSA.27.1',
  'PRO.16.3',
  'JHN.1.5',
  'ISA.43.2',
  'MAT.28.20',
  'PSA.16.11',
  'ROM.8.38-ROM.8.39',
  'EPH.3.20',
  '2CO.12.9',
  'PSA.62.1-PSA.62.2',
  'JHN.10.10',
  'NUM.6.24-NUM.6.26',
  'PSA.91.1-PSA.91.2',
  'COL.3.12-COL.3.14',
  '1TH.5.16-1TH.5.18',
  'ISA.30.15',
  'PSA.103.2-PSA.103.4',
  'JHN.8.12',
  'HEB.4.16',
  'PSA.143.8',
];

/// The passage for [day] (local date).
VerseRange verseOfTheDay(DateTime day) {
  final start = DateTime(day.year);
  final dayOfYear = DateTime(
    day.year,
    day.month,
    day.day,
  ).difference(start).inDays;
  // Offset by year so the same date doesn't repeat the same verse yearly.
  return VerseRange.parseCode(
    _passages[(dayOfYear + day.year * 7) % _passages.length],
  );
}
