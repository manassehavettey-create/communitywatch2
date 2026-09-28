import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'app/config.dart';
import 'app/notifications.dart';
import 'app/providers.dart';
import 'app/settings.dart';
import 'data/local/database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final prefs = await SharedPreferences.getInstance();
  if (AppConfig.cloudEnabled) {
    // Only the public anon key is used; Row Level Security protects all data.
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseAnonKey);
  }
  final db = AppDatabase.open();
  final notifications = NotificationService();
  await notifications.init();

  runApp(ProviderScope(
    // Local data never "fails" transiently — don't auto-retry providers.
    retry: (_, _) => null,
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      notificationsProvider.overrideWithValue(notifications),
    ],
    child: const BodyforgeApp(),
  ));
}
