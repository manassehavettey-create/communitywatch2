import 'package:flutter/material.dart';

/// Background/text pairs for the reader, independent of the app theme
/// (DESIGN.md → Reader themes).
enum ReaderTheme {
  paper('Paper', Color(0xFFF6F0E6), Color(0xFF1E1C19), Color(0xFF8F897E)),
  cream('Cream', Color(0xFFF3E9CC), Color(0xFF2A261F), Color(0xFF8A7F68)),
  night('Night', Color(0xFF121110), Color(0xFFD9D2C5), Color(0xFF7C766C)),
  forest('Forest', Color(0xFF1F312B), Color(0xFFE6E1D3), Color(0xFF8FA398));

  const ReaderTheme(this.label, this.background, this.text, this.muted);

  final String label;
  final Color background;
  final Color text;

  /// Verse numbers, headings and chrome.
  final Color muted;

  bool get isDark => this == night || this == forest;

  static ReaderTheme fromName(String? name) => ReaderTheme.values.firstWhere(
    (t) => t.name == name,
    orElse: () => ReaderTheme.paper,
  );

  /// "auto" follows the app brightness: Paper by day, Night by night.
  static ReaderTheme resolve(String? name, Brightness appBrightness) {
    if (name == null || name == 'auto') {
      return appBrightness == Brightness.dark ? night : paper;
    }
    return fromName(name);
  }
}
