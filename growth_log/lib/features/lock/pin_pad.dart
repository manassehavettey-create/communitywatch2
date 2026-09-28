import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/services/lock_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/pressable.dart';

/// Four dots and a round-key number pad.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onComplete,
    this.foreground = Palette.white,
    this.keyColor,
    this.onBiometric,
    this.enabled = true,
    this.error = false,
  });

  /// Called with the full PIN; the dots clear once it completes.
  final Future<void> Function(String pin) onComplete;
  final Color foreground;
  final Color? keyColor;
  final VoidCallback? onBiometric;
  final bool enabled;
  final bool error;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _pin = '';
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    if (widget.error && !old.error) {
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  Future<void> _tap(String d) async {
    if (!widget.enabled || _pin.length >= LockService.pinLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _pin += d);
    if (_pin.length == LockService.pinLength) {
      final pin = _pin;
      await widget.onComplete(pin);
      if (mounted) setState(() => _pin = '');
    }
  }

  void _back() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground;
    final keyBg = widget.keyColor ?? fg.withValues(alpha: 0.08);
    Widget key(String d) => _Key(
          label: d,
          fg: fg,
          bg: keyBg,
          onTap: widget.enabled ? () => _tap(d) : null,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = math.sin(t * math.pi * 6) * 12 * (1 - t);
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Semantics(
            label: '${_pin.length} of ${LockService.pinLength} digits entered',
            liveRegion: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < LockService.pinLength; i++)
                  AnimatedContainer(
                    duration: Motion.fast,
                    margin: const EdgeInsets.symmetric(horizontal: 9),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: i < _pin.length ? (widget.error ? Palette.danger : Palette.lime) : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.error ? Palette.danger : fg, width: 2),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.xxl),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ]) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [for (final d in row) key(d)]),
          const SizedBox(height: Space.sm),
        ],
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.onBiometric == null
                ? const SizedBox(width: 92)
                : _Key(
                    icon: PhosphorIconsRegular.fingerprint,
                    semantic: 'Use biometrics',
                    fg: fg,
                    bg: Colors.transparent,
                    onTap: widget.onBiometric,
                  ),
            key('0'),
            _Key(
              icon: PhosphorIconsRegular.backspace,
              semantic: 'Delete digit',
              fg: fg,
              bg: Colors.transparent,
              onTap: _back,
            ),
          ],
        ),
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({this.label, this.icon, this.semantic, required this.fg, required this.bg, this.onTap});

  final String? label;
  final IconData? icon;
  final String? semantic;
  final Color fg;
  final Color bg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Pressable(
        onTap: onTap,
        haptic: false,
        scale: 0.9,
        semanticLabel: semantic ?? label,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: label != null
              ? Text(label!, style: AppText.display.copyWith(color: fg, fontSize: 28, letterSpacing: 0))
              : Icon(icon, color: fg, size: 28),
        ),
      ),
    );
  }
}
