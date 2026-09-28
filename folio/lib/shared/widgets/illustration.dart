import 'package:flutter/material.dart';
import '../../core/theme/icons.dart';

import '../../core/theme/illustration_colors.g.dart';
import '../../core/theme/tokens.dart';

/// Illustrations shipped in assets/images, keyed by file name.
enum Art {
  onboardingLibrary('onboarding', 'onboarding_library', 3 / 4),
  onboardingHighlight('onboarding', 'onboarding_highlight', 3 / 4),
  onboardingHabit('onboarding', 'onboarding_habit', 3 / 4),
  emptyLibrary('empty', 'empty_library', 1),
  emptyHighlights('empty', 'empty_highlights', 1),
  emptyNotes('empty', 'empty_notes', 1),
  emptyBookmarks('empty', 'empty_bookmarks', 1),
  emptyHistory('empty', 'empty_history', 1),
  emptyCollections('empty', 'empty_collections', 1),
  emptySearch('empty', 'empty_search', 1),
  sessionComplete('session', 'session_complete', 1);

  const Art(this.folder, this.name, this.aspect);
  final String folder;
  final String name;
  final double aspect;

  String get path => 'assets/images/$folder/$name.webp';
}

/// Shows an illustration on a rounded card painted in the illustration's own
/// sampled background colour, so its edges disappear. Falls back to a calm
/// icon tile if the asset isn't bundled.
class Illustration extends StatelessWidget {
  const Illustration(
    this.art, {
    super.key,
    this.width,
    this.radius = Radii.xl,
    this.fallbackIcon,
  });

  final Art art;
  final double? width;
  final double radius;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final bg = Color(kIllustrationBackgrounds[art.name] ?? 0xFFEDE6D8);
    final dark = context.brightness == Brightness.dark;
    final child = AspectRatio(
      aspectRatio: art.aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Image.asset(
            art.path,
            fit: BoxFit.cover,
            // Dim slightly at night so pastel cards don't glare.
            color: dark ? const Color(0xFFE6E0D6) : null,
            colorBlendMode: dark ? BlendMode.modulate : null,
            errorBuilder: (_, _, _) => Center(
              child: Icon(
                fallbackIcon ?? PhosphorIconsRegular.bookOpen,
                size: 56,
                color: const Color(0x99161514),
              ),
            ),
          ),
        ),
      ),
    );
    return width == null ? child : SizedBox(width: width, child: child);
  }
}

/// Collection cover art per colour, if bundled.
String collectionArtPath(ShelfColor color) => 'assets/images/collections/collection_${switch (color) {
      ShelfColor.lavender || ShelfColor.lilac => 'lavender',
      ShelfColor.lime => 'lime',
      ShelfColor.butter => 'butter',
      ShelfColor.peach => 'peach',
      ShelfColor.mint => 'mint',
      ShelfColor.sky => 'sky',
      ShelfColor.rose => 'peach',
    }}.webp';
