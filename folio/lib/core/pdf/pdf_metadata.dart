import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:pdfium_dart/pdfium_dart.dart' as pdfium_bindings;
import 'package:pdfrx/pdfrx.dart';

/// Title / author from the PDF's Info dictionary.
class PdfInfo {
  const PdfInfo({this.title, this.author});
  final String? title;
  final String? author;
}

/// Reads document metadata with PDFium. pdfrx doesn't expose the Info
/// dictionary, so this calls `FPDF_GetMetaText` directly — on pdfrx's own
/// PDFium worker isolate, because PDFium is not thread-safe.
Future<PdfInfo> readPdfInfo(String path) async {
  await PdfrxEntryFunctions.instance.init();
  final result = await PdfrxEntryFunctions.instance.compute(
    _readInfo,
    (path: path, modulePath: Pdfrx.pdfiumModulePath),
  );
  return PdfInfo(title: result.$1, author: result.$2);
}

(String?, String?) _readInfo(({String path, String? modulePath}) args) {
  final pdfium = pdfium_bindings.getPdfium(modulePath: args.modulePath);
  final arena = Arena();
  try {
    final doc = pdfium.FPDF_LoadDocument(args.path.toNativeUtf8(allocator: arena).cast(), nullptr);
    if (doc == nullptr) return (null, null);
    try {
      String? read(String tag) {
        final t = tag.toNativeUtf8(allocator: arena).cast<Char>();
        final len = pdfium.FPDF_GetMetaText(doc, t, nullptr, 0);
        if (len <= 2) return null;
        final buf = arena.allocate<Uint8>(len);
        pdfium.FPDF_GetMetaText(doc, t, buf.cast(), len);
        final bytes = buf.asTypedList(len);
        // UTF-16LE with a trailing NUL.
        final units = Uint16List.view(Uint8List.fromList(bytes).buffer, 0, (len ~/ 2) - 1);
        final s = String.fromCharCodes(units).trim();
        return s.isEmpty ? null : s;
      }

      return (read('Title'), read('Author'));
    } finally {
      pdfium.FPDF_CloseDocument(doc);
    }
  } catch (_) {
    return (null, null);
  } finally {
    arena.releaseAll();
  }
}

/// Picks a display title: the embedded title when it looks real, otherwise a
/// cleaned-up file name.
String chooseTitle(String? embedded, String fileName) {
  final t = embedded?.trim() ?? '';
  final lower = t.toLowerCase();
  final junk = t.isEmpty ||
      t.length < 2 ||
      lower == 'untitled' ||
      lower.startsWith('microsoft word') ||
      lower.startsWith('microsoft powerpoint') ||
      RegExp(r'\.(docx?|pdf|pptx?|txt|indd|tex|odt)$').hasMatch(lower) ||
      RegExp(r'^[\w-]+\.\w{2,4}$').hasMatch(t) ||
      RegExp(r'^[a-f0-9-]{16,}$').hasMatch(lower);
  if (!junk) return t;
  var name = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');
  name = name.replaceAll(RegExp(r'[_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (name.isEmpty) return 'Untitled PDF';
  // Title-case names that are all lower-case (e.g. "deep-work" -> "Deep-work").
  if (name == name.toLowerCase()) {
    name = name[0].toUpperCase() + name.substring(1);
  }
  return name;
}

String? cleanAuthor(String? a) {
  final t = a?.trim() ?? '';
  if (t.isEmpty) return null;
  final lower = t.toLowerCase();
  if (const {'unknown', 'anonymous', 'administrator', 'admin', 'user', 'owner'}.contains(lower)) {
    return null;
  }
  return t;
}
