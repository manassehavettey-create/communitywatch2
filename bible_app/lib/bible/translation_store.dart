import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'translation.dart';
import 'translation_store_io.dart'
    if (dart.library.js_interop) 'translation_store_web.dart'
    as platform;

/// Translations installed after the app was built (downloaded files in the
/// app's support directory). Bundled translations never go through here.
abstract class TranslationStore {
  static final TranslationStore instance = platform.createStore();

  /// Whether this platform can install translations (not on web).
  bool get supported;

  Future<List<TranslationInfo>> installed();

  Future<String> read(String filePath);

  /// Validates and installs a translation file (schema 1). When
  /// [expectedSha256] is given the bytes must match it. Returns the
  /// installed translation.
  Future<TranslationInfo> install(Uint8List bytes, {String? expectedSha256});

  Future<void> remove(String id);

  /// Shared validation for [install]: returns the decoded document.
  static Map<String, dynamic> validate(
    Uint8List bytes, {
    String? expectedSha256,
  }) {
    if (expectedSha256 != null) {
      final actual = sha256.convert(bytes).toString();
      if (actual != expectedSha256) {
        throw const FormatException('Download is corrupt (checksum mismatch)');
      }
    }
    final doc = jsonDecode(utf8.decode(bytes));
    if (doc is! Map<String, dynamic> || doc['schema'] != 1) {
      throw const FormatException('Not a supported Bible file');
    }
    final books = doc['books'];
    if (doc['id'] is! String ||
        doc['name'] is! String ||
        doc['abbreviation'] is! String ||
        doc['license'] is! String ||
        books is! List ||
        books.length != 66) {
      throw const FormatException('Bible file is incomplete');
    }
    final id = doc['id'] as String;
    if (!RegExp(r'^[a-z0-9_-]{2,16}$').hasMatch(id)) {
      throw const FormatException('Bible file has an invalid id');
    }
    return doc;
  }
}
