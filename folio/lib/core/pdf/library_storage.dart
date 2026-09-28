import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where Folio keeps its private copies of PDFs and generated covers.
class LibraryStorage {
  LibraryStorage(this.root);

  final Directory root;

  static Future<LibraryStorage> open() async {
    final base = await getApplicationSupportDirectory();
    final s = LibraryStorage(Directory(p.join(base.path, 'library')));
    await s.booksDir.create(recursive: true);
    await s.coversDir.create(recursive: true);
    return s;
  }

  Directory get booksDir => Directory(p.join(root.path, 'books'));
  Directory get coversDir => Directory(p.join(root.path, 'covers'));

  String bookPathFor(String sha) => p.join(booksDir.path, '$sha.pdf');
  String coverPathFor(String sha) => p.join(coversDir.path, '$sha.png');

  /// Bytes used by Folio's copies and covers.
  Future<int> usedBytes() async {
    var total = 0;
    for (final dir in [booksDir, coversDir]) {
      if (!await dir.exists()) continue;
      await for (final e in dir.list()) {
        if (e is File) total += await e.length();
      }
    }
    return total;
  }

  Future<void> deleteFiles({required String filePath, String? coverPath}) async {
    for (final path in [filePath, ?coverPath]) {
      // Only ever delete files inside Folio's own library folder.
      if (!p.isWithin(root.path, path)) continue;
      final f = File(path);
      if (await f.exists()) await f.delete();
    }
  }
}

/// SHA-256 of a file, streamed in a background isolate so large PDFs are
/// never loaded into memory and the UI stays responsive.
Future<String> sha256OfFile(String path) => Isolate.run(() async {
      final sink = _DigestSink();
      final input = sha256.startChunkedConversion(sink);
      await for (final chunk in File(path).openRead()) {
        input.add(chunk);
      }
      input.close();
      return sink.value.toString();
    });

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}

/// True when [e] means the device ran out of space.
bool isOutOfSpace(Object e) {
  if (e is FileSystemException) {
    final code = e.osError?.errorCode;
    final msg = '${e.osError?.message} ${e.message}'.toLowerCase();
    return code == 28 || code == 112 || msg.contains('no space') || msg.contains('disk full');
  }
  return false;
}
