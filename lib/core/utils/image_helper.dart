import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' as io;

class ImageHelper {
  static Widget buildFileImage(String? path, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget? placeholder}) {
    if (kIsWeb || path == null || path.isEmpty) {
      return placeholder ?? const Icon(Icons.broken_image);
    }

    try {
      final file = io.File(path);
      if (file.existsSync()) {
        return Image.file(file, width: width, height: height, fit: fit);
      }
    } catch (e) {
      debugPrint("Error loading file image: $e");
    }
    
    return placeholder ?? const Icon(Icons.broken_image);
  }

  static ImageProvider? getFileImageProvider(String? path) {
    if (kIsWeb || path == null || path.isEmpty) return null;
    try {
      final file = io.File(path);
      if (file.existsSync()) {
        return FileImage(file);
      }
    } catch (_) {}
    return null;
  }
}
