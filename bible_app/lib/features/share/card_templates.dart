import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';
import '../../core/widgets/sticker.dart';

/// Output sizes, in pixels.
enum CardFormat {
  square('Square', 'Instagram · Facebook post', 1080, 1080),
  portrait('Portrait', 'Instagram portrait', 1080, 1350),
  story('Story', 'Stories · WhatsApp status', 1080, 1920),
  landscape('Landscape', 'X · Facebook link', 1600, 900),
  wallpaper('Wallpaper', 'Phone lock screen', 1179, 2556);

  const CardFormat(this.label, this.useFor, this.width, this.height);
  final String label;
  final String useFor;
  final int width;
  final int height;

  double get aspect => width / height;
}

enum CardFont {
  fraunces('Fraunces', 'Fraunces', true),
  literata('Literata', 'Literata', true),
  urbanist('Urbanist', 'Urbanist', true),
  caveat('Handwritten', 'Caveat', true);

  const CardFont(this.label, this.family, this.variable);
  final String label;
  final String family;
  final bool variable;
}

/// Colour variants offered by templates that allow them.
const cardPastels = <Color>[
  Color(0xFFF4D352),
  Color(0xFFEF845D),
  Color(0xFFAAC385),
  Color(0xFFA1BDDD),
  Color(0xFFE9B4C8),
  Color(0xFFF3E9CC),
];

enum CardTemplate {
  paper('Paper'),
  botanical('Botanical'),
  dusk('Dusk'),
  blocks('Blocks'),
  sticker('Sticker'),
  grid('Grid'),
  forest('Forest'),
  night('Night');

  const CardTemplate(this.label);
  final String label;

  bool get hasColors => this == sticker || this == blocks;

  bool get dark => this == forest || this == night;

  Color ink(Color accent) =>
      dark ? const Color(0xFFF1EBDD) : const Color(0xFF141414);

  /// Fraction of the card (from the top) where text may go. Dusk keeps
  /// its figures clear at the bottom.
  EdgeInsets textArea(Size s) => switch (this) {
    CardTemplate.dusk => EdgeInsets.fromLTRB(
      s.width * 0.1,
      s.height * 0.08,
      s.width * 0.1,
      s.height * 0.5,
    ),
    CardTemplate.botanical => EdgeInsets.fromLTRB(
      s.width * 0.16,
      s.height * 0.16,
      s.width * 0.16,
      s.height * 0.16,
    ),
    _ => EdgeInsets.symmetric(
      horizontal: s.width * 0.1,
      vertical: s.height * 0.1,
    ),
  };
}

/// The card itself, drawn at any size. Everything scales from the card's
/// shorter side so previews and exports match exactly.
class ScriptureCard extends StatelessWidget {
  const ScriptureCard({
    super.key,
    required this.template,
    required this.text,
    required this.reference,
    required this.font,
    required this.alignment,
    required this.accent,
  });

  final CardTemplate template;
  final String text;
  final String reference;
  final CardFont font;
  final TextAlign alignment;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final size = Size(c.maxWidth, c.maxHeight);
        final unit = math.min(size.width, size.height) / 100;
        final ink = template.ink(accent);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              _background(size, unit),
              Padding(
                padding: template.textArea(size),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: alignment == TextAlign.center
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: _FitText(
                        text: '“$text”',
                        align: alignment,
                        style: fontStyle(
                          font.family,
                          size: unit * 7,
                          height: font == CardFont.caveat ? 1.15 : 1.32,
                          weight: font == CardFont.urbanist
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: ink,
                          variable: font.variable,
                          letterSpacing: font == CardFont.urbanist
                              ? -unit * 0.1
                              : 0,
                        ),
                        minSize: unit * 2.6,
                      ),
                    ),
                    SizedBox(height: unit * 5),
                    _reference(unit, ink),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _reference(double unit, Color ink) {
    final label = Text(
      reference.toUpperCase(),
      textAlign: alignment,
      style: fontStyle(
        Fonts.ui,
        size: unit * 2.8,
        weight: FontWeight.w700,
        letterSpacing: unit * 0.35,
        color: template == CardTemplate.sticker ? const Color(0xFF141414) : ink,
      ),
    );
    if (template == CardTemplate.sticker) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: unit * 4, vertical: unit * 2),
        decoration: const ShapeDecoration(
          color: Color(0xFFF6F0E6),
          shape: StadiumBorder(),
        ),
        child: label,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: unit * 6,
          height: unit * 0.5,
          color: template.dark
              ? const Color(0xFFFF7A33)
              : const Color(0xFFF5620F),
        ),
        SizedBox(width: unit * 2.5),
        Flexible(child: label),
      ],
    );
  }

  Widget _background(Size s, double unit) {
    switch (template) {
      case CardTemplate.paper:
        return Container(
          color: const Color(0xFFF6F0E6),
          child: CustomPaint(painter: _GrainPainter(const Color(0x10141414))),
        );
      case CardTemplate.botanical:
        return Image.asset(
          'assets/images/cards/card_botanical_corner.jpg',
          fit: BoxFit.cover,
        );
      case CardTemplate.dusk:
        return Image.asset(
          'assets/images/cards/card_dusk.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
        );
      case CardTemplate.blocks:
        return Container(
          color: const Color(0xFFF6F0E6),
          child: Stack(
            children: [
              Positioned(
                left: -s.width * 0.18,
                top: -s.height * 0.12,
                width: s.width * 0.75,
                height: s.width * 0.7,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: accent,
                    shape: const BlobBorder(seed: 2),
                  ),
                ),
              ),
              Positioned(
                right: -s.width * 0.2,
                bottom: -s.height * 0.1,
                width: s.width * 0.8,
                height: s.width * 0.72,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: accent == cardPastels[3]
                        ? cardPastels[4]
                        : cardPastels[3],
                    shape: const BlobBorder(seed: 5),
                  ),
                ),
              ),
            ],
          ),
        );
      case CardTemplate.sticker:
        return Container(
          color: accent,
          child: Stack(
            children: [
              Positioned(
                right: -unit * 12,
                top: -unit * 12,
                width: unit * 55,
                height: unit * 55,
                child: const DecoratedBox(
                  decoration: ShapeDecoration(
                    color: Color(0x33FFFFFF),
                    shape: ScallopBorder(lobes: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      case CardTemplate.grid:
        return Container(
          color: const Color(0xFFF7F3EC),
          child: CustomPaint(painter: _GridPainter(unit * 6)),
        );
      case CardTemplate.forest:
        return Container(
          color: const Color(0xFF1F312B),
          child: CustomPaint(painter: _FernPainter(unit)),
        );
      case CardTemplate.night:
        return Container(
          color: const Color(0xFF121110),
          child: CustomPaint(painter: _MoonPainter(unit)),
        );
    }
  }
}

/// Picks the largest font size (down to [minSize]) at which [text] fits.
class _FitText extends StatelessWidget {
  const _FitText({
    required this.text,
    required this.style,
    required this.align,
    required this.minSize,
  });

  final String text;
  final TextStyle style;
  final TextAlign align;
  final double minSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        var size = style.fontSize!;
        while (size > minSize) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: style.copyWith(fontSize: size),
            ),
            textAlign: align,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
          )..layout(maxWidth: c.maxWidth);
          final fits = tp.height <= c.maxHeight;
          tp.dispose();
          if (fits) break;
          size *= 0.92;
        }
        return Text(
          text,
          textAlign: align,
          textScaler: TextScaler.noScaling,
          overflow: TextOverflow.fade,
          style: style.copyWith(fontSize: size),
        );
      },
    );
  }
}

class _GrainPainter extends CustomPainter {
  _GrainPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    final paint = Paint()..color = color;
    final n = (size.width * size.height / 900).clamp(200, 6000).toInt();
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        rnd.nextDouble() * size.shortestSide / 900 + 0.3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => false;
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.step);
  final double step;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x1A141414)
      ..strokeWidth = math.max(1, step / 40);
    for (var x = step; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = step; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.step != step;
}

class _FernPainter extends CustomPainter {
  _FernPainter(this.unit);
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x55E6E1D3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 0.35
      ..strokeCap = StrokeCap.round;
    void frond(double x, double h, double lean) {
      final base = Offset(x, size.height + unit * 2);
      final tip = Offset(x + lean, size.height - h);
      canvas.drawLine(base, tip, paint);
      for (var t = 0.15; t < 0.95; t += 0.1) {
        final p = Offset.lerp(base, tip, t)!;
        final len = unit * 9 * (1 - t);
        canvas.drawLine(p, p + Offset(-len, -len * 0.5), paint);
        canvas.drawLine(p, p + Offset(len, -len * 0.5), paint);
      }
    }

    frond(size.width * 0.12, size.height * 0.28, unit * 4);
    frond(size.width * 0.86, size.height * 0.22, -unit * 3);
    final dot = Paint()..color = const Color(0x88E6E1D3);
    final rnd = math.Random(4);
    for (var i = 0; i < 14; i++) {
      canvas.drawCircle(
        Offset(
          rnd.nextDouble() * size.width,
          rnd.nextDouble() * size.height * 0.2,
        ),
        unit * (0.25 + rnd.nextDouble() * 0.35),
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_FernPainter old) => old.unit != unit;
}

class _MoonPainter extends CustomPainter {
  _MoonPainter(this.unit);
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width - unit * 16, unit * 16);
    final r = unit * 8;
    final moon = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: c, radius: r)),
      Path()..addOval(
        Rect.fromCircle(
          center: c + Offset(r * 0.45, -r * 0.2),
          radius: r * 0.85,
        ),
      ),
    );
    canvas.drawPath(
      moon,
      Paint()
        ..color = const Color(0xFFFF7A33)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.45,
    );
    _GrainPainter(const Color(0x14F1EBDD)).paint(canvas, size);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.unit != unit;
}
