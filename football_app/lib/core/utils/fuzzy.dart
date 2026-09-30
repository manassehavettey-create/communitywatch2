/// Typo-tolerant matching for search (spec §32). Pure Dart, no allocations
/// beyond small buffers, fast enough for a few thousand candidates per
/// keystroke.
abstract final class Fuzzy {
  static const _fold = {
    'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ą': 'a', 'æ': 'ae',
    'ç': 'c', 'ć': 'c', 'č': 'c', 'ď': 'd', 'đ': 'd', 'ð': 'd',
    'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ę': 'e', 'ě': 'e', 'ğ': 'g',
    'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ı': 'i', 'ł': 'l', 'ñ': 'n', 'ń': 'n', 'ň': 'n',
    'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'œ': 'oe',
    'ř': 'r', 'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', 'ť': 't', 'ţ': 't',
    'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ý': 'y', 'ÿ': 'y', 'ž': 'z', 'ź': 'z', 'ż': 'z',
  };

  /// Lowercase, strip diacritics and punctuation, collapse whitespace.
  static String normalize(String s) {
    final b = StringBuffer();
    for (final r in s.toLowerCase().runes) {
      final ch = String.fromCharCode(r);
      final f = _fold[ch];
      if (f != null) {
        b.write(f);
      } else if (RegExp(r'[a-z0-9]').hasMatch(ch)) {
        b.write(ch);
      } else {
        b.write(' ');
      }
    }
    return b.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Optimal string alignment (Damerau–Levenshtein) distance.
  static int distance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev2 = List<int>.filled(b.length + 1, 0);
    var prev = List<int>.generate(b.length + 1, (i) => i);
    var cur = List<int>.filled(b.length + 1, 0);
    for (var i = 1; i <= a.length; i++) {
      cur[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = _min3(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost);
        if (i > 1 && j > 1 && a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) && a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1)) {
          v = v < prev2[j - 2] + 1 ? v : prev2[j - 2] + 1;
        }
        cur[j] = v;
      }
      final t = prev2;
      prev2 = prev;
      prev = cur;
      cur = t;
    }
    return prev[b.length];
  }

  static int _min3(int a, int b, int c) => a < b ? (a < c ? a : c) : (b < c ? b : c);

  /// Score in 0..1 of how well [query] matches [candidate]. 0 = no match.
  ///
  /// Exact/prefix/substring matches score highest; otherwise each query token
  /// is compared against candidate tokens (and their prefixes) with an edit
  /// budget proportional to token length, so "mbape" → "Mbappé" and
  /// "barcelna" → "Barcelona".
  static double score(String query, String candidate) {
    final q = normalize(query);
    final c = normalize(candidate);
    if (q.isEmpty || c.isEmpty) return 0;
    if (c == q) return 1;
    if (c.startsWith(q)) return 0.95;
    final cTokens = c.split(' ');
    if (cTokens.any((t) => t.startsWith(q))) return 0.9;
    if (c.contains(q)) return 0.8;
    final qTokens = q.split(' ');
    double total = 0;
    for (final qt in qTokens) {
      double best = 0;
      for (final ct in cTokens) {
        best = best > _tokenScore(qt, ct) ? best : _tokenScore(qt, ct);
        if (best >= 1) break;
      }
      if (best == 0) return 0;
      total += best;
    }
    return 0.75 * total / qTokens.length;
  }

  static double _tokenScore(String q, String t) {
    if (t == q) return 1;
    if (t.startsWith(q)) return 0.95;
    final budget = q.length <= 3 ? 0 : (q.length <= 5 ? 1 : 2);
    if (budget == 0) return 0;
    // Compare against the whole token and against its same-length prefix so
    // partially typed words still match.
    final whole = distance(q, t);
    final prefix = t.length > q.length ? distance(q, t.substring(0, q.length)) : whole;
    final d = whole < prefix ? whole : prefix;
    if (d > budget) return 0;
    return 1 - d / (q.length + 1);
  }

  /// Rank [items] by [score]; keeps those above [threshold].
  static List<T> rank<T>(String query, Iterable<T> items, String Function(T) text, {double threshold = 0.35, int limit = 20}) {
    final scored = <(T, double)>[];
    for (final it in items) {
      final s = score(query, text(it));
      if (s >= threshold) scored.add((it, s));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(limit).map((e) => e.$1).toList();
  }
}
