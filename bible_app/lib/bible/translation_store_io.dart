import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'translation.dart';
import 'translation_store.dart';

TranslationStore createStore() => _IoTranslationStore();

class _IoTranslationStore extends TranslationStore {
  @override
  bool get supported => true;

  Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'translations'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<List<TranslationInfo>> installed() async {
    final dir = await _dir();
    final out = <TranslationInfo>[];
    for (final f in dir.listSync().whereType<File>()) {
      if (!f.path.endsWith('.meta.json')) continue;
      try {
        final meta = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        final textPath = f.path.replaceFirst('.meta.json', '.json');
        if (!File(textPath).existsSync()) continue;
        out.add(TranslationInfo.fromJson(meta, FileLocation(textPath)));
      } on FormatException {
        // A damaged metadata file hides that translation instead of
        // breaking the catalogue.
        continue;
      }
    }
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<String> read(String filePath) => File(filePath).readAsString();

  @override
  Future<TranslationInfo> install(
    Uint8List bytes, {
    String? expectedSha256,
  }) async {
    final doc = TranslationStore.validate(
      bytes,
      expectedSha256: expectedSha256,
    );
    final id = doc['id'] as String;
    final dir = await _dir();
    final textFile = File(p.join(dir.path, '$id.json'));
    final metaFile = File(p.join(dir.path, '$id.meta.json'));
    // Write the text first; the metadata file is what makes it visible.
    final tmp = File('${textFile.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(textFile.path);
    final meta = Map<String, dynamic>.of(doc)..remove('books');
    await metaFile.writeAsString(jsonEncode(meta), flush: true);
    return TranslationInfo.fromJson(meta, FileLocation(textFile.path));
  }

  @override
  Future<void> remove(String id) async {
    final dir = await _dir();
    for (final name in ['$id.meta.json', '$id.json']) {
      final f = File(p.join(dir.path, name));
      if (f.existsSync()) await f.delete();
    }
  }
}
