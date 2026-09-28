import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/services/lock_service.dart';
import '../../core/theme/app_theme.dart' show AppText;
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_image.dart';
import '../../core/widgets/buttons.dart';
import 'pin_pad.dart';

/// Covers the app with a PIN / biometric lock when app lock is on: at cold
/// start and when returning after more than [relockAfter] in the background.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  static const relockAfter = Duration(seconds: 30);

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate>
    with WidgetsBindingObserver {
  late bool _locked = ref.read(settingsProvider).lockEnabled;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_locked) _verifyPinExists();
  }

  /// If the lock is on but no PIN exists (e.g. keychain cleared), unlock
  /// and turn the setting off rather than trapping the user.
  Future<void> _verifyPinExists() async {
    final has = await ref.read(lockServiceProvider).hasPin();
    if (!has && mounted) {
      await ref.read(settingsProvider.notifier).setLockEnabled(false);
      setState(() => _locked = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final enabled = ref.read(settingsProvider).lockEnabled;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt == null
          ? Duration.zero
          : DateTime.now().difference(_backgroundedAt!);
      _backgroundedAt = null;
      if (enabled && !_locked && away > LockGate.relockAfter) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.lockEnabled), (_, enabled) {
      if (!enabled && _locked) setState(() => _locked = false);
    });
    return Stack(
      children: [
        ExcludeSemantics(
          excluding: _locked,
          child: AbsorbPointer(absorbing: _locked, child: widget.child),
        ),
        if (_locked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  int _failures = 0;
  DateTime? _cooldownUntil;
  bool _error = false;
  bool _biometricAvailable = false;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _initBiometrics();
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _initBiometrics() async {
    final settings = ref.read(settingsProvider);
    if (!settings.biometricEnabled) return;
    final ok = await ref.read(lockServiceProvider).biometricsAvailable();
    if (!mounted) return;
    setState(() => _biometricAvailable = ok);
    if (ok) await _biometric();
  }

  Future<void> _biometric() async {
    final ok = await ref.read(lockServiceProvider).authenticateBiometric();
    if (ok && mounted) widget.onUnlocked();
  }

  bool get _coolingDown =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  Future<void> _submit(String pin) async {
    if (_coolingDown) return;
    final ok = await ref.read(lockServiceProvider).verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      ref.read(hapticsProvider).light();
      widget.onUnlocked();
      return;
    }
    _failures++;
    setState(() => _error = true);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _error = false);
    });
    if (_failures >= LockService.maxAttempts) {
      _failures = 0;
      _cooldownUntil = DateTime.now().add(LockService.cooldown);
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!_coolingDown) t.cancel();
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wait = _coolingDown
        ? _cooldownUntil!.difference(DateTime.now()).inSeconds + 1
        : 0;
    return Material(
      color: Palette.ink,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Palette.lime,
                    shape: BoxShape.circle,
                  ),
                  child: const AppImage(AppAssets.splashLogo),
                ),
                const SizedBox(height: Space.lg),
                Text(
                  'Welcome back',
                  style: AppText.display.copyWith(
                    color: Palette.white,
                    fontSize: 32,
                  ),
                ),
                const SizedBox(height: Space.xs),
                Text(
                  wait > 0
                      ? 'Too many tries. Try again in ${wait}s.'
                      : 'Enter your PIN to unlock',
                  style: AppText.body.copyWith(
                    color: Palette.white.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: Space.xxl),
                PinPad(
                  onComplete: _submit,
                  enabled: wait == 0,
                  error: _error,
                  onBiometric: _biometricAvailable ? _biometric : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks for a new PIN twice. Returns the PIN, or null if cancelled.
Future<String?> showCreatePin(BuildContext context) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _CreatePinScreen(),
    ),
  );
}

class _CreatePinScreen extends StatefulWidget {
  const _CreatePinScreen();

  @override
  State<_CreatePinScreen> createState() => _CreatePinScreenState();
}

class _CreatePinScreenState extends State<_CreatePinScreen> {
  String? _first;
  bool _error = false;

  Future<void> _onPin(String pin) async {
    if (_first == null) {
      setState(() => _first = pin);
      return;
    }
    if (pin == _first) {
      Navigator.pop(context, pin);
      return;
    }
    setState(() {
      _error = true;
      _first = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) setState(() => _error = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.ink,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.all(Space.gutter),
                child: CircleIconButton(
                  icon: Icons.close,
                  tooltip: 'Cancel',
                  background: Palette.white.withValues(alpha: 0.1),
                  foreground: Palette.white,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            const Spacer(),
            Text(
              _first == null ? 'Choose a PIN' : 'Confirm your PIN',
              style: AppText.display.copyWith(
                color: Palette.white,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: Space.xs),
            Text(
              _error
                  ? "Those didn't match — try again."
                  : '${LockService.pinLength} digits you will remember',
              style: AppText.body.copyWith(
                color: _error
                    ? Palette.blush
                    : Palette.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: Space.xxl),
            PinPad(
              key: ValueKey(_first == null),
              onComplete: _onPin,
              error: _error,
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

/// Asks for the current PIN (before disabling the lock or changing it).
Future<bool> verifyCurrentPin(BuildContext context) async {
  final ok = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (ctx) => Stack(
        children: [
          LockScreen(onUnlocked: () => Navigator.pop(ctx, true)),
          Positioned(
            top: MediaQuery.paddingOf(ctx).top + Space.sm,
            left: Space.gutter,
            child: CircleIconButton(
              icon: Icons.close,
              tooltip: 'Cancel',
              background: Palette.white.withValues(alpha: 0.1),
              foreground: Palette.white,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ),
        ],
      ),
    ),
  );
  return ok ?? false;
}
