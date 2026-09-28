@Tags(['monkey'])
library;

import 'package:bodyforge/app/router.dart';
import 'package:bodyforge/core/widgets/motion_widgets.dart';
import 'package:bodyforge/domain/catalog/challenges.dart';
import 'package:bodyforge/domain/catalog/foods.dart';
import 'package:bodyforge/domain/catalog/skill_paths.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart' as smoke;

/// Taps every tappable control on every screen (one per fresh visit) and
/// fails if any tap throws or leaves an error on screen. Catches dead
/// handlers, bad casts and layout errors in sheets/dialogs the route-only
/// smoke test never opens.
void main() {
  setUpAll(smoke.loadAppFonts);

  final routes = [
    '/home',
    '/workout',
    '/progress',
    '/nutrition',
    '/profile',
    '/exercise/wall_push_up',
    for (final p in kSkillPaths.take(2)) '/skills/${p.id}',
    '/build',
    '/records',
    '/measurements',
    '/calendar',
    '/weekly',
    '/journey',
    '/report',
    '/achievements',
    '/food/${kFoods.first.id}',
    '/meals',
    '/challenge/${kChallenges.first.id}',
    '/settings',
    '/edit/goals',
    '/edit/preferences',
  ];

  Finder tappables() => find.byWidgetPredicate((w) =>
      (w is Pressable && w.onTap != null) ||
      (w is InkWell && w.onTap != null) ||
      (w is ButtonStyleButton && w.onPressed != null) ||
      (w is IconButton && w.onPressed != null) ||
      (w is Switch && w.onChanged != null));

  for (final route in routes) {
    testWidgets('tap everything on $route', (tester) async {
      final h = await smoke.Harness.boot(tester, demo: true);
      final router = h.container.read(routerProvider);
      final failures = <String>[];
      final original = FlutterError.onError;
      var current = '';
      FlutterError.onError = (d) {
        final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
        failures.add('$current → ${d.exceptionAsString().split('\n').first} @ $where');
      };
      try {
        router.go(route);
        await smoke.settle(tester);
        final count = tappables().hitTestable().evaluate().length;
        for (var i = 0; i < count && i < 40; i++) {
          // Fresh visit so earlier taps (sheets, navigation) don't leak.
          router.go(route == '/home' ? '/profile' : '/home');
          await smoke.settle(tester, 300);
          router.go(route);
          await smoke.settle(tester);
          final targets = tappables().hitTestable();
          final n = targets.evaluate().length;
          if (i >= n) break;
          final target = targets.at(i);
          final label = _describe(tester, target);
          current = '$route #$i ($label)';
          await tester.tap(target, warnIfMissed: false);
          await smoke.settle(tester);
          if (find.byType(ErrorWidget).evaluate().isNotEmpty) failures.add('$current → ErrorWidget on screen');
        }
      } finally {
        FlutterError.onError = original;
      }
      await h.shutdown();
      expect(failures.toSet().toList(), isEmpty, reason: failures.toSet().join('\n'));
    });
  }
}

String _describe(WidgetTester tester, Finder f) {
  final texts = find.descendant(of: f, matching: find.byType(Text)).evaluate().map((e) => (e.widget as Text).data).whereType<String>();
  if (texts.isNotEmpty) return texts.first;
  final sem = find.descendant(of: f, matching: find.byType(Icon)).evaluate().map((e) => (e.widget as Icon).semanticLabel ?? 'icon');
  return sem.isNotEmpty ? sem.first : f.evaluate().first.widget.runtimeType.toString();
}
