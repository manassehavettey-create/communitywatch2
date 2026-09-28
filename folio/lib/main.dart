import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import 'app/app.dart';
import 'app/boot_failure.dart';
import 'app/providers.dart';
import 'core/db/connection.dart';
import 'core/pdf/library_storage.dart';
import 'data/repositories/settings_repository.dart';
import 'data/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicenses();
  await pdfrxFlutterInitialize();

  final storage = await LibraryStorage.open();
  final db = await openAppDatabase();
  try {
    // Surfaces a wrong/missing encryption key before any UI is built.
    await db.customSelect('SELECT 1').get();
  } catch (e) {
    await db.close();
    runApp(BootFailureApp(error: e));
    return;
  }
  final settings = await SettingsRepository(db).load();
  await NotificationService.instance.init();

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      libraryStorageProvider.overrideWithValue(storage),
      initialSettingsProvider.overrideWithValue(settings),
    ],
  );

  runApp(UncontrolledProviderScope(container: container, child: const FolioApp()));

  // Resume any indexing that was interrupted when the app last closed.
  unawaited(container.read(indexingServiceProvider).resumePending());
  // Keep the daily reminder in sync with settings (e.g. after a reboot or
  // timezone change).
  unawaited(NotificationService.instance.applySettings(settings));
}

/// Bundled fonts and icons ship their licences in-app (Settings → About).
void _registerFontLicenses() {
  const files = {
    'Bricolage Grotesque': 'assets/fonts/OFL-bricolagegrotesque.txt',
    'Manrope': 'assets/fonts/OFL-manrope.txt',
    'Literata': 'assets/fonts/OFL-literata.txt',
    'Phosphor Icons': 'assets/fonts/LICENSE-phosphor.txt',
  };
  LicenseRegistry.addLicense(() async* {
    for (final e in files.entries) {
      yield LicenseEntryWithLineBreaks([e.key], await rootBundle.loadString(e.value));
    }
  });
}
