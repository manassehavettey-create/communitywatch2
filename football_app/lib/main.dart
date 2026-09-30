import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:intl/intl.dart';

import 'app/app.dart';
import 'app/local_store.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'core/cache/cache_store.dart';
import 'features/notifications/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // English-only app: pin the locale so date formatting never depends on
  // an unsupported system locale string.
  Intl.defaultLocale = 'en_US';
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, systemNavigationBarColor: Colors.transparent));
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await Hive.initFlutter('touchline');
  final cacheBox = await Hive.openBox<String>('api_cache');
  final prefsBox = await Hive.openBox<String>('prefs');
  await NotificationService.instance.init();

  runApp(ProviderScope(
    // Retries are handled by our own polling/backoff so a failing endpoint
    // never burns the request quota.
    retry: (count, error) => null,
    overrides: [
      localStoreProvider.overrideWithValue(LocalStore(prefsBox)),
      cacheStoreProvider.overrideWithValue(HiveCacheStore(cacheBox)),
    ],
    child: const TouchlineApp(),
  ));
}
