/// Turns free-form user input into a safe FTS5 MATCH expression.
///
/// * `"exact phrase"` stays a phrase.
/// * Other words become prefix terms, all required (AND): `photo synth`
///   matches "photosynthesis".
/// * FTS5 syntax characters are stripped so user input can never produce a
///   query error.
///
/// Returns null when nothing searchable remains.
String? buildFtsQuery(String input) {
  final parts = <String>[];
  final phrase = RegExp(r'"([^"]+)"');
  var rest = input;
  for (final m in phrase.allMatches(input)) {
    final words = _words(m.group(1)!);
    if (words.isNotEmpty) parts.add('"${words.join(' ')}"');
  }
  rest = rest.replaceAll(phrase, ' ');
  for (final w in _words(rest)) {
    parts.add('"$w"*');
  }
  if (parts.isEmpty) return null;
  return parts.join(' ');
}

List<String> _words(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .toList();

/// The individual words of a query, for locating matches inside page text.
List<String> queryTerms(String input) => _words(input);
