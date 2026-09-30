import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';
import 'router.dart';
import 'settings.dart';

class TouchlineApp extends ConsumerWidget {
  const TouchlineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    return MaterialApp.router(
      title: 'Touchline',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(AppColors.light),
      darkTheme: buildTheme(AppColors.dark),
      themeMode: settings.themeMode,
      themeAnimationDuration: Motion.slow,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        // In-app "Reduce motion" preference is merged with the OS setting.
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: mq.disableAnimations || settings.reduceMotion,
            textScaler: mq.textScaler.clamp(minScaleFactor: 1, maxScaleFactor: 1.6),
          ),
          child: child!,
        );
      },
    );
  }
}
