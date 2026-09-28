import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'search.dart';
import 'translation.dart';
import 'translation_store.dart';

/// The catalogue: bundled translations, installed translations and the
/// ones listed as not available yet.
class TranslationCatalog {
  const TranslationCatalog({
    required this.available,
    required this.unavailable,
    required this.defaultId,
  });

  final List<TranslationInfo> available;
  final List<UnavailableTranslation> unavailable;
  final String defaultId;

  TranslationInfo? byId(String id) {
    for (final t in available) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// [id] if it is available, otherwise the default translation.
  TranslationInfo resolve(String? id) =>
      (id == null ? null : byId(id)) ?? byId(defaultId) ?? available.first;
}

/// Loads Scripture text. No UI code depends on the storage format; adding a
/// translation means adding a file, not changing code.
class BibleRepository {
  BibleRepository({AssetBundle? bundle, TranslationStore? store})
    : _bundle = bundle ?? rootBundle,
      _store = store ?? TranslationStore.instance;

  static const manifestAsset = 'assets/bible/translations.json';

  /// Parsed translations kept in memory (the current one and the last one
  /// switched away from, so switching back is instant).
  static const _cacheSize = 2;

  final AssetBundle _bundle;
  final TranslationStore _store;
  final _cache = <String, Future<BibleText>>{};
  final _order = <String>[];
  final _indexes = <String, Future<SearchIndex>>{};
  TranslationCatalog? _catalog;

  Future<TranslationCatalog> catalog({bool refresh = false}) async {
    if (_catalog != null && !refresh) return _catalog!;
    final manifest = jsonDecode(
      await _bundle.loadString(manifestAsset),
    ) as Map<String, dynamic>;
    final available = [
      for (final t
          in (manifest['available'] as List).cast<Map<String, dynamic>>())
        TranslationInfo.fromJson(t, AssetLocation(t['asset'] as String)),
    ];
    final bundledIds = {for (final t in available) t.id};
    try {
      for (final installed in await _store.installed()) {
        if (!bundledIds.contains(installed.id)) available.add(installed);
      }
    } on Object catch (e) {
      // Bundled translations must always open, even if the folder of
      // installed ones can't be read.
      debugPrint('Installed translations unavailable: $e');
    }
    final unavailable = [
      for (final t
          in (manifest['not_available'] as List).cast<Map<String, dynamic>>())
        if (!available.any((a) => a.abbreviation == t['abbreviation']))
          UnavailableTranslation(
            t['abbreviation'] as String,
            t['name'] as String,
            t['reason'] as String,
          ),
    ];
    return _catalog = TranslationCatalog(
      available: available,
      unavailable: unavailable,
      defaultId: manifest['default'] as String,
    );
  }

  /// Loads (or returns the cached) full text of a translation. JSON parsing
  /// runs off the UI isolate.
  Future<BibleText> load(TranslationInfo info) {
    final existing = _cache[info.id];
    if (existing != null) {
      _order
        ..remove(info.id)
        ..add(info.id);
      return existing;
    }
    final future = _loadUncached(info);
    _cache[info.id] = future;
    _order.add(info.id);
    while (_order.length > _cacheSize) {
      final evicted = _order.removeAt(0);
      _cache.remove(evicted);
      _indexes.remove(evicted);
    }
    // Don't cache failures, so the next attempt retries.
    future.then<void>(
      (_) {},
      onError: (Object _) {
        if (identical(_cache[info.id], future)) {
          _cache.remove(info.id);
          _order.remove(info.id);
        }
      },
    );
    return future;
  }

  Future<BibleText> _loadUncached(TranslationInfo info) async {
    final json = switch (info.location) {
      AssetLocation(:final assetPath) => await _bundle.loadString(
        assetPath,
        cache: false,
      ),
      FileLocation(:final filePath) => await _store.read(filePath),
    };
    return compute(_parse, (json, info.location));
  }

  /// Search index for a translation, built on first use.
  Future<SearchIndex> searchIndex(TranslationInfo info) {
    return _indexes[info.id] ??= load(info)
        .then((bible) => compute(SearchIndex.build, bible));
  }
}

BibleText _parse((String, TranslationLocation) args) {
  final doc = jsonDecode(args.$1) as Map<String, dynamic>;
  return BibleText.parse(doc, args.$2);
}
