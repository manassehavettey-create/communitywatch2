import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../motion/motion.dart';
import '../motion/reveal.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'buttons.dart';
import 'sticker.dart';

/// Illustrated empty state: a drifting blob with an icon, a short title,
/// one line of guidance and an optional action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.color,
    this.actionLabel,
    this.onAction,
    this.blobSeed = 3,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? color;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int blobSeed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final m = Motion.of(context);
    Widget art = Container(
      width: 132,
      height: 120,
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: color ?? p.butter,
        shape: BlobBorder(seed: blobSeed),
      ),
      child: Icon(icon, size: 44, color: p.onPastel),
    );
    if (!m.reduced) {
      art = art
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: -4,
            end: 4,
            duration: 2600.ms,
            curve: Curves.easeInOutSine,
          )
          .rotate(
            begin: -0.01,
            end: 0.01,
            duration: 2600.ms,
            curve: Curves.easeInOutSine,
          );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x8,
        vertical: Space.x10,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Reveal(child: ExcludeSemantics(child: art)),
          const SizedBox(height: Space.x6),
          Reveal(
            index: 1,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.titleM.copyWith(color: p.ink),
            ),
          ),
          const SizedBox(height: Space.x2),
          Reveal(
            index: 2,
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: p.inkSoft),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: Space.x6),
            Reveal(
              index: 3,
              child: PillButton(
                label: actionLabel!,
                onPressed: onAction,
                compact: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
