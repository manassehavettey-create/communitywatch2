import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:pdfrx/pdfrx.dart';

import '../../core/db/database.dart';
import '../../core/pdf/library_storage.dart';
import '../../core/pdf/pdf_metadata.dart';
import '../repositories/books_repository.dart';
import 'indexing_service.dart';

enum ImportStage { checking, copying, reading, cover, done }

enum ImportOutcome { added, duplicate, failed }

class ImportResult {
  const ImportResult(this.outcome, this.fileName, {this.bookId, this.message});
  final ImportOutcome outcome;
  final String fileName;
  final int? bookId;
  final String? message;
}

/// Imports PDFs into Folio's private library. Nothing is uploaded anywhere:
/// files are copied into app storage, read with PDFium on-device, and their
/// text is indexed locally.
class ImportService {
  ImportService({
    required this.books,
    required this.storage,
    required this.indexer,
  });

  final BooksRepository books;
  final LibraryStorage storage;
  final IndexingService indexer;

  Future<ImportResult> importFile(
    String sourcePath,
    String fileName, {
    void Function(ImportStage stage)? onStage,
    DateTime? now,
    bool moveSource = false,
  }) async {
    String? copiedPath;
    String? coverPath;
    try {
      final src = File(sourcePath);
      if (!await src.exists()) {
        return ImportResult(ImportOutcome.failed, fileName,
            message: "The file couldn't be opened. It may have been moved or deleted.");
      }
      if (!await _looksLikePdf(src)) {
        return ImportResult(ImportOutcome.failed, fileName,
            message: "This file isn't a PDF, so Folio can't open it.");
      }

      onStage?.call(ImportStage.checking);
      final sha = await sha256OfFile(sourcePath);
      final existing = await books.findBySha(sha);
      if (existing != null) {
        if (moveSource) await src.delete();
        return ImportResult(ImportOutcome.duplicate, fileName,
            bookId: existing.id, message: 'Already in your library as “${existing.title}”.');
      }

      onStage?.call(ImportStage.copying);
      final dest = storage.bookPathFor(sha);
      copiedPath = dest;
      final size = await src.length();
      if (sourcePath != dest) {
        if (moveSource) {
          try {
            await src.rename(dest);
          } on FileSystemException {
            await src.copy(dest);
            await src.delete();
          }
        } else {
          await src.copy(dest);
        }
      }

      onStage?.call(ImportStage.reading);
      final PdfDocument doc;
      try {
        doc = await PdfDocument.openFile(dest);
      } on PdfPasswordException {
        await storage.deleteFiles(filePath: dest);
        copiedPath = null;
        return ImportResult(ImportOutcome.failed, fileName,
            message: 'This PDF is password-protected. Remove the password and import it again.');
      } catch (_) {
        await storage.deleteFiles(filePath: dest);
        copiedPath = null;
        return ImportResult(ImportOutcome.failed, fileName,
            message: "This PDF looks damaged and couldn't be opened.");
      }

      int pageCount;
      double aspect = 0.7071;
      try {
        pageCount = doc.pages.length;
        if (pageCount == 0) {
          await storage.deleteFiles(filePath: dest);
          copiedPath = null;
          return ImportResult(ImportOutcome.failed, fileName, message: 'This PDF has no pages.');
        }
        final first = doc.pages.first;
        if (first.height > 0) aspect = first.width / first.height;

        onStage?.call(ImportStage.cover);
        coverPath = await _renderCover(first, storage.coverPathFor(sha));
      } finally {
        await doc.dispose();
      }

      final info = await readPdfInfo(dest);
      final id = await books.insertBook(
        BooksCompanion.insert(
          title: chooseTitle(info.title, fileName),
          author: Value(cleanAuthor(info.author)),
          originalFileName: fileName,
          filePath: dest,
          fileSize: size,
          sha256: sha,
          pageCount: pageCount,
          coverPath: Value(coverPath),
          coverAspect: Value(aspect.clamp(0.3, 2.0)),
          addedAt: now ?? DateTime.now(),
        ),
      );
      onStage?.call(ImportStage.done);
      indexer.enqueue(id);
      return ImportResult(ImportOutcome.added, fileName, bookId: id);
    } catch (e) {
      if (copiedPath != null) {
        await storage.deleteFiles(filePath: copiedPath, coverPath: coverPath);
      }
      if (isOutOfSpace(e)) {
        return ImportResult(ImportOutcome.failed, fileName,
            message: 'Not enough free storage to add this PDF. Free up some space and try again.');
      }
      return ImportResult(ImportOutcome.failed, fileName,
          message: "Something went wrong while adding this PDF. (${e.runtimeType})");
    }
  }

  static Future<bool> _looksLikePdf(File f) async {
    try {
      final raf = await f.open();
      try {
        final head = await raf.read(1024);
        return String.fromCharCodes(head).contains('%PDF-');
      } finally {
        await raf.close();
      }
    } catch (_) {
      return false;
    }
  }

  /// Renders the first page as the cover image (PDFs have no standard
  /// "cover" field; the first page is what readers expect).
  static Future<String?> _renderCover(PdfPage page, String outPath) async {
    const targetWidth = 540;
    final scale = targetWidth / page.width;
    final w = targetWidth;
    final h = (page.height * scale).round().clamp(1, 1600);
    final img = await page.render(
      fullWidth: w.toDouble(),
      fullHeight: (page.height * scale),
      width: w,
      height: h,
      backgroundColor: 0xFFFFFFFF,
      annotationRenderingMode: PdfAnnotationRenderingMode.annotationAndForms,
    );
    if (img == null) return null;
    try {
      final image = await img.createImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) return null;
        await File(outPath).writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        return outPath;
      } finally {
        image.dispose();
      }
    } catch (_) {
      return null;
    } finally {
      img.dispose();
    }
  }
}
