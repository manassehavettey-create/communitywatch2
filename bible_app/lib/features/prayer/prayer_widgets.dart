import 'package:flutter/material.dart';

import '../../core/theme/tokens.dart';
import '../../data/repos/prayer_repository.dart';

Color prayerColor(PrayerCategory c, AppPalette p) => switch (c) {
  PrayerCategory.personal => p.coral,
  PrayerCategory.family => p.butter,
  PrayerCategory.friends => p.sage,
  PrayerCategory.work => p.sky,
  PrayerCategory.school => p.blush,
  PrayerCategory.relationships => p.coral,
  PrayerCategory.gratitude => p.butter,
  PrayerCategory.other => p.cream,
};

/// Rounded card with a small speech-bubble tail at the bottom left.
class BubbleBorder extends OutlinedBorder {
  const BubbleBorder({this.radius = Radii.lg, this.tail = 14, super.side});

  final double radius;
  final double tail;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.only(bottom: tail);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      getOuterPath(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final body = Rect.fromLTRB(
      rect.left,
      rect.top,
      rect.right,
      rect.bottom - tail,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(body, Radius.circular(radius)));
    final x = body.left + radius + 6;
    path
      ..moveTo(x, body.bottom - 1)
      ..quadraticBezierTo(
        x + 2,
        body.bottom + tail * 0.6,
        x - 6,
        body.bottom + tail,
      )
      ..quadraticBezierTo(
        x + 14,
        body.bottom + tail * 0.7,
        x + 22,
        body.bottom - 1,
      )
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  BubbleBorder scale(double t) =>
      BubbleBorder(radius: radius * t, tail: tail * t);

  @override
  BubbleBorder copyWith({BorderSide? side}) =>
      BubbleBorder(radius: radius, tail: tail, side: side ?? this.side);
}
