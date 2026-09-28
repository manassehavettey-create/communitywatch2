import 'dart:io';
import 'dart:ui' as ui;

import 'package:bodyforge/app/providers.dart';
import 'package:bodyforge/app/router.dart';
import 'package:bodyforge/app/settings.dart';
import 'package:bodyforge/domain/engine/session_builder.dart';
import 'package:bodyforge/domain/models/enums.dart';
import 'package:bodyforge/features/player/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';

/// Renders real screenshots (app fonts, Material icons, images) of the main
/// screens for visual review. Only runs when BF_SCREENSHOT_DIR is set:
///
///   BF_SCREENSHOT_DIR=/tmp/shots flutter test test/widgets/screenshots_test.dart
void main() {
  final dir = Platform.environment['BF_SCREENSHOT_DIR'];

  setUpAll(() async {
    await loadAppFonts();
    final icons = File('${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
    if (icons.existsSync()) {
      final bytes = icons.readAsBytesSync();
      await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });

  const routes = {
    'home': '/home',
    'workout': '/workout',
    'progress': '/progress',
    'nutrition': '/nutrition',
    'profile': '/profile',
    'session': '/session',
    'exercise': '/exercise/incline_push_up',
    'skills': '/skills/push',
    'journey': '/journey',
    'calendar': '/calendar',
    'achievements': '/achievements',
    'food': '/food/sardines',
    'challenge': '/challenge/protein_20',
    'weekly': '/weekly',
    'settings': '/settings',
  };

  for (final theme in ['dark', 'light']) {
    testWidgets('screenshots ($theme)', (tester) async {
      final h = await Harness.boot(tester, demo: true);
      if (theme == 'light') h.container.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: ThemeMode.light));
      final router = h.container.read(routerProvider);
      for (final MapEntry(key: name, value: route) in routes.entries) {
        if (route == '/session') {
          // Preview of a full-body session.
          final inputs = h.container.read(sessionInputsProvider(DayType.fullBody))!;
          h.container.read(pendingSessionProvider.notifier).set(SessionBuilder(inputs).build());
          router.go('/home');
          await settle(tester);
          router.push('/session');
        } else {
          router.go(route);
        }
        await settle(tester, 1500);
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate().toList()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await settle(tester, 1500);
        await tester.runAsync(() async {
          final ro = kScreenKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final img = await ro.toImage(pixelRatio: 2);
          final png = await img.toByteData(format: ui.ImageByteFormat.png);
          Directory(dir!).createSync(recursive: true);
          File('$dir/${theme}_$name.png').writeAsBytesSync(png!.buffer.asUint8List());
        });
      }
      await h.shutdown();
    }, skip: dir == null);
  }
}
