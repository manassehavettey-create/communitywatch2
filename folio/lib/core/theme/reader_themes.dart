import 'package:flutter/material.dart';

/// Page themes for the reader. Persisted by index — only append.
enum ReaderTheme {
  paper('Paper'),
  sepia('Sepia'),
  night('Night');

  const ReaderTheme(this.label);
  final String label;

  static ReaderTheme fromIndex(int i) =>
      (i >= 0 && i < values.length) ? values[i] : ReaderTheme.paper;

  /// Background around the pages.
  Color get canvas => switch (this) {
        ReaderTheme.paper => const Color(0xFFE9E3D6),
        ReaderTheme.sepia => const Color(0xFFE6D6B8),
        ReaderTheme.night => const Color(0xFF0E0D0C),
      };

  /// Page colour used by Text view and as the "blank page" tone.
  Color get page => switch (this) {
        ReaderTheme.paper => const Color(0xFFFFFDF8),
        ReaderTheme.sepia => const Color(0xFFF3E7CF),
        ReaderTheme.night => const Color(0xFF1E1C19),
      };

  /// Text colour in Text view.
  Color get text => switch (this) {
        ReaderTheme.paper => const Color(0xFF1F1D1A),
        ReaderTheme.sepia => const Color(0xFF3B2E20),
        ReaderTheme.night => const Color(0xFFD9D0BF),
      };

  Color get mutedText => text.withValues(alpha: 0.6);

  Brightness get chromeBrightness =>
      this == ReaderTheme.night ? Brightness.dark : Brightness.light;

  /// Colour filter applied to rendered PDF pages, or null for none.
  ColorFilter? get pageFilter => switch (this) {
        ReaderTheme.paper => null,
        ReaderTheme.sepia => _linearMap(
            black: const Color(0xFF3B2E20),
            white: const Color(0xFFF3E7CF),
          ),
        ReaderTheme.night => _nightFilter(
            // white page → warm dim, black text → warm light
            whiteTo: const Color(0xFF1E1C19),
            blackTo: const Color(0xFFD9D0BF),
          ),
      };

  /// Maps each channel linearly so black → [black] and white → [white].
  static ColorFilter _linearMap({required Color black, required Color white}) {
    double s(double w, double b) => (w - b);
    final r0 = black.r * 255, g0 = black.g * 255, b0 = black.b * 255;
    return ColorFilter.matrix(<double>[
      s(white.r, black.r), 0, 0, 0, r0, //
      0, s(white.g, black.g), 0, 0, g0,
      0, 0, s(white.b, black.b), 0, b0,
      0, 0, 0, 1, 0,
    ]);
  }

  /// Luminance inversion that keeps hue: c' = c − 2·L + 255, then the
  /// inverted range 0..255 is squeezed into [whiteTo]..[blackTo].
  ///
  /// A photo keeps its colours (a red stays red) instead of becoming a
  /// negative, and white pages turn into a warm, low-glare dark tone.
  static ColorFilter _nightFilter({required Color whiteTo, required Color blackTo}) =>
      ColorFilter.matrix(nightMatrix(whiteTo: whiteTo, blackTo: blackTo));

  /// The 4x5 colour matrix behind the Night theme (exposed for tests).
  static List<double> nightMatrix({
    Color whiteTo = const Color(0xFF1E1C19),
    Color blackTo = const Color(0xFFD9D0BF),
  }) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    // Inversion matrix rows (per output channel): c - 2L + 255.
    final inv = <List<double>>[
      [1 - 2 * lr, -2 * lg, -2 * lb, 255],
      [-2 * lr, 1 - 2 * lg, -2 * lb, 255],
      [-2 * lr, -2 * lg, 1 - 2 * lb, 255],
    ];
    final lo = [whiteTo.r * 255, whiteTo.g * 255, whiteTo.b * 255];
    final hi = [blackTo.r * 255, blackTo.g * 255, blackTo.b * 255];
    final m = <double>[];
    for (var ch = 0; ch < 3; ch++) {
      final k = (hi[ch] - lo[ch]) / 255;
      final row = inv[ch];
      m.addAll([row[0] * k, row[1] * k, row[2] * k, 0, row[3] * k + lo[ch]]);
    }
    m.addAll([0, 0, 0, 1, 0]);
    return m;
  }
}
