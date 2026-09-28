import 'dart:convert';
import 'dart:io';

import 'package:bible_app/bible/translation.dart';

final _cache = <String, BibleText>{};

/// Loads a bundled translation straight from assets/ for tests.
BibleText loadBundled(String id) => _cache[id] ??= BibleText.parse(
  jsonDecode(File('assets/bible/$id.json').readAsStringSync())
      as Map<String, dynamic>,
  AssetLocation('assets/bible/$id.json'),
);
