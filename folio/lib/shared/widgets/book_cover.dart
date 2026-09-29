import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';

/// A book cover: the rendered first page, or a typographic cover when the
/// PDF had nothing renderable. Adds a spine shade and soft shadow so it reads
/// as a physical book, not a thumbnail.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.book,
    this.width = 120,
    this.hero = true,
    this.radius = Radii.sm,
    this.shadow = true,
  });

  final Book book;
  final double width;
  final bool hero;
  final double radius;
  final bool shadow;

  static const double aspect = 2 / 3;

  static String heroTag(int id) => 'cover-$id';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final height = width / aspect;
    final path = book.coverPath;
    Widget face;
    if (path != null && File(path).existsSync()) {
      face = Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        cacheWidth: (width * dpr).round(),
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _TypeCover(book: book, width: width),
      );
    } else {
      face = _TypeCover(book: book, width: width);
    }

    final cover = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: c.surface,
        boxShadow: shadow ? c.floatingShadow : null,
        border: shadow && c.floatingShadow.isEmpty ? Border.all(color: c.hairline) : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            face,
            // Spine shade.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: width * 0.07,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0x33000000), Color(0x00000000)])),
              ),
            ),
            Positioned(
              left: width * 0.07,
              top: 0,
              bottom: 0,
              width: 1,
              child: const ColoredBox(color: Color(0x14FFFFFF)),
            ),
          ],
        ),
      ),
    );

    if (!hero) return cover;
    return Hero(tag: heroTag(book.id), transitionOnUserGestures: true, child: cover);
  }
}

class _TypeCover extends StatelessWidget {
  const _TypeCover({required this.book, required this.width});
  final Book book;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = ShelfColor.collectionColors;
    final color = colors[book.title.hashCode.abs() % colors.length];
    final scale = width / 120;
    return ColoredBox(
      color: color.strong,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14 * scale, 14 * scale, 10 * scale, 12 * scale),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                book.title,
                maxLines: 5,
                overflow: TextOverflow.fade,
                style: withWeight(
                  TextStyle(
                    fontFamily: Fonts.display,
                    fontSize: 15 * scale,
                    height: 1.05,
                    color: const Color(0xFF161514),
                    letterSpacing: -0.2,
                  ),
                  800,
                ),
              ),
            ),
            if (book.author != null)
              Text(
                book.author!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: withWeight(
                  TextStyle(fontFamily: Fonts.ui, fontSize: 9 * scale, color: const Color(0xCC161514)),
                  700,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
