import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/icons.dart';

import '../../app/providers.dart';
import '../../bible/references.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/layout.dart';
import 'audio_catalog.dart';
import 'audio_player.dart';

/// Audio Bible controls. Disabled, with an explanation, when the current
/// translation has no licensed recording.
class AudioSheet extends ConsumerStatefulWidget {
  const AudioSheet({super.key, required this.chapter});

  final ChapterRef chapter;

  @override
  ConsumerState<AudioSheet> createState() => _AudioSheetState();
}

class _AudioSheetState extends ConsumerState<AudioSheet> {
  BibleAudioHandler? _handler;
  double _speed = 1;
  bool _starting = false;

  static const _speeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  Future<void> _play(AudioSourceInfo source) async {
    setState(() => _starting = true);
    try {
      final h = _handler ??= await BibleAudioHandler.start(source);
      if (h.chapter != widget.chapter) {
        await h.playChapter(widget.chapter);
      } else {
        await h.play();
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final translation = ref.watch(currentTranslationProvider).value;
    final source = translation == null ? null : audioSourceFor(translation.id);
    final enabled = source != null;
    final handler = _handler;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Space.x6, 0, Space.x6, Space.x6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetHeader(title: 'Listen'),
            Text(
              '${widget.chapter.label}${translation == null ? '' : ' · ${translation.abbreviation}'}',
              style: AppType.body.copyWith(color: p.inkSoft),
            ),
            const SizedBox(height: Space.x5),
            if (!enabled)
              Container(
                padding: const EdgeInsets.all(Space.x4),
                decoration: BoxDecoration(
                  color: p.sky,
                  borderRadius: Radii.mdAll,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(PhosphorIconsRegular.headphones, color: p.onPastel),
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Text(
                        'Audio isn’t available yet. We only include recordings '
                        'we’re licensed to use, and none are confirmed for this '
                        'translation. Reading works fully without it.',
                        style: AppType.bodySmall.copyWith(color: p.onPastel),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: Space.x5),
            StreamBuilder<Duration>(
              stream: handler?.position,
              builder: (context, snap) {
                final pos = snap.data ?? Duration.zero;
                final dur = handler?.duration ?? Duration.zero;
                final max = dur.inMilliseconds.toDouble();
                return Slider(
                  value: max == 0
                      ? 0
                      : pos.inMilliseconds.clamp(0, max).toDouble(),
                  max: max == 0 ? 1 : max,
                  onChanged: enabled && max > 0
                      ? (v) => handler?.seek(Duration(milliseconds: v.round()))
                      : null,
                );
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                CircleIconButton(
                  icon: PhosphorIconsFill.skipBack,
                  tooltip: 'Previous chapter',
                  onPressed: enabled && handler != null
                      ? handler.skipToPrevious
                      : null,
                ),
                StreamBuilder(
                  stream: handler?.playbackState,
                  builder: (context, snap) {
                    final playing = snap.data?.playing ?? false;
                    return CircleIconButton(
                      icon: playing
                          ? PhosphorIconsFill.pause
                          : PhosphorIconsFill.play,
                      tooltip: playing ? 'Pause' : 'Play',
                      size: 64,
                      background: enabled ? p.ink : p.paperDeep,
                      foreground: enabled ? p.paper : p.inkMute,
                      onPressed: !enabled || _starting
                          ? null
                          : playing
                          ? handler!.pause
                          : () => _play(source),
                    );
                  },
                ),
                CircleIconButton(
                  icon: PhosphorIconsFill.skipForward,
                  tooltip: 'Next chapter',
                  onPressed: enabled && handler != null
                      ? handler.skipToNext
                      : null,
                ),
              ],
            ),
            const SizedBox(height: Space.x5),
            Opacity(
              opacity: enabled ? 1 : 0.45,
              child: ChipRow<double>(
                options: _speeds,
                selected: _speed,
                labelOf: (s) => '${s}x',
                onSelected: (s) {
                  if (!enabled) return;
                  setState(() => _speed = s);
                  handler?.setSpeed(s);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
