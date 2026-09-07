import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io'
    if (dart.library.html) 'package:communitywatch/core/services/database_stub.dart'
    as io;

class ImageHelper {
  static String get _serverUrl {
    return 'https://communitywatch2.onrender.com';
  }

  static Widget buildFileImage(
    String? path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    Widget? placeholder,
  }) {
    if (path == null || path.isEmpty) {
      return placeholder ??
          const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white10),
          );
    }

    // TACTICAL SYNC: If path starts with /uploads, it's a remote image from Command Core
    if (path.startsWith('/uploads')) {
      return Image.network(
        '$_serverUrl$path',
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) =>
            placeholder ??
            const Icon(Icons.broken_image_rounded, color: Colors.white10),
      );
    }

    if (kIsWeb)
      return placeholder ??
          const Center(
            child: Icon(Icons.broken_image_rounded, color: Colors.white10),
          );

    try {
      final file = io.File(path);
      if (file.existsSync()) {
        return Image.file(
          file as dynamic,
          width: width,
          height: height,
          fit: fit,
        );
      }
    } catch (e) {
      debugPrint("IMAGE_HELPER_ERROR: $e");
    }

    return placeholder ??
        const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white10),
        );
  }

  static ImageProvider? getFileImageProvider(String? path) {
    if (path == null || path.isEmpty) return null;

    if (path.startsWith('/uploads')) {
      return NetworkImage('$_serverUrl$path');
    }

    if (kIsWeb) return null;
    try {
      final file = io.File(path);
      if (file.existsSync()) {
        return FileImage(file as dynamic);
      }
    } catch (_) {}
    return null;
  }
}
