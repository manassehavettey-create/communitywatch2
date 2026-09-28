import 'dart:typed_data';

import 'translation.dart';
import 'translation_store.dart';

TranslationStore createStore() => _WebTranslationStore();

/// The web build ships only bundled translations.
class _WebTranslationStore extends TranslationStore {
  @override
  bool get supported => false;

  @override
  Future<List<TranslationInfo>> installed() async => const [];

  @override
  Future<String> read(String filePath) =>
      throw UnsupportedError('Installed translations are not used on web');

  @override
  Future<TranslationInfo> install(Uint8List bytes, {String? expectedSha256}) =>
      throw UnsupportedError('Installing translations is not supported');

  @override
  Future<void> remove(String id) async {}
}
