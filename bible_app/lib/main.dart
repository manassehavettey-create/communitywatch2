import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/providers.dart';
import 'data/auth/auth_service.dart';
import 'data/db/database.dart';
import 'data/sync/sync_service.dart';
import 'features/onboarding/onboarding_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final db = AppDatabase.open();

  // Accounts are optional; if Supabase can't start, the app runs local-only.
  AuthService auth;
  try {
    auth = await AuthService.create();
  } on Object catch (e) {
    debugPrint('Accounts unavailable: $e');
    auth = AuthService.disabled();
  }

  final sync = SyncService(db)..start();
  final onboarded = await db.getValue(OnboardingScreen.doneKey) == '1';

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        authServiceProvider.overrideWithValue(auth),
        syncServiceProvider.overrideWithValue(sync),
      ],
      child: BibleApp(onboarded: onboarded),
    ),
  );
}
