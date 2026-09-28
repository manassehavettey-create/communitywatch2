import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/application/app_actions.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_image.dart';
import 'features/lock/lock_gate.dart';

class GrowthLogApp extends ConsumerStatefulWidget {
  const GrowthLogApp({super.key});

  @override
  ConsumerState<GrowthLogApp> createState() => _GrowthLogAppState();
}

class _GrowthLogAppState extends ConsumerState<GrowthLogApp> with WidgetsBindingObserver {
  StreamSubscription<String>? _taps;
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(notificationServiceProvider);
    _taps = notifications.taps.listen(_openPayload);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final actions = ref.read(appActionsProvider);
      unawaited(actions.syncAllReminders());
      unawaited(actions.restoreTimerNotification());
      final launch = notifications.launchPayload;
      if (launch != null) {
        notifications.launchPayload = null;
        _openPayload(launch);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Decode illustrations early so screens don't pop in.
    if (!_precached) {
      _precached = true;
      for (final a in AppAssets.all) {
        precacheImage(AssetImage(a), context, onError: (_, _) {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _taps?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // The date or time zone may have changed while we were away.
    ref.read(todayProvider.notifier).refresh();
    ref.read(notificationServiceProvider).refreshTimezone().then((changed) {
      if (changed) ref.read(appActionsProvider).syncAllReminders();
    });
  }

  void _openPayload(String payload) {
    if (!ref.read(settingsProvider).onboardingDone) return;
    final router = ref.read(routerProvider);
    if (payload == NotificationPayload.timer) {
      router.push(Routes.timer());
    } else if (payload == NotificationPayload.newEntry) {
      router.push(Routes.newEntry());
    } else if (payload.startsWith('skill:')) {
      final id = int.tryParse(payload.substring(6));
      if (id != null) router.push(Routes.skill(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final GoRouter router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Growth Log',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      themeAnimationDuration: const Duration(milliseconds: 300),
      routerConfig: router,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
          ),
          // Cap text scaling so big-type layouts stay intact while still
          // honouring larger accessibility sizes.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: LockGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}
