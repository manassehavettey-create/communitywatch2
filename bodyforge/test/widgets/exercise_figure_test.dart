import 'dart:io';
import 'dart:ui' as ui;

import 'package:bodyforge/domain/catalog/exercises.dart';
import 'package:bodyforge/features/exercise/exercise_figure.dart';
import 'package:bodyforge/features/exercise/figure_demos.dart';
import 'package:bodyforge/features/exercise/figure_rig.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every exercise has an animated demo', () {
    final missing = {for (final e in kExercises) if (!kDemos.containsKey(e.demo)) e.demo};
    expect(missing, isEmpty);
  });

  test('every pose solves to finite joints', () {
    kDemos.forEach((key, demo) {
      for (var t = 0.0; t < 1; t += 0.1) {
        final k = Skeleton.solve(demo.at(t));
        for (final p in [k.hip, k.shoulder, k.head, k.nElbow, k.nHand, k.fElbow, k.fHand, k.nKnee, k.nAnkle, k.fKnee, k.fAnkle]) {
          expect(p.dx.isFinite && p.dy.isFinite, isTrue, reason: '$key @ $t');
        }
      }
    });
  });

  testWidgets('figure renders and animates', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Center(child: SizedBox(width: 320, child: ExerciseFigure(demo: 'push_up')))));
    await tester.pump(const Duration(milliseconds: 450));
    expect(find.byType(ExerciseFigure), findsOneWidget);
  });

  // Visual check: BF_RENDER_DIR=/path flutter test test/widgets/exercise_figure_test.dart
  final dir = Platform.environment['BF_RENDER_DIR'];
  testWidgets('render contact sheet', (tester) async {
    final keys = kDemos.keys.toList();
    final boundary = GlobalKey();
    await tester.binding.setSurfaceSize(const Size(1600, 2600));
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: boundary,
        child: Container(
          color: const Color(0xFFD4F55A),
          child: Wrap(children: [
            for (final k in keys)
              for (final t in [0.0, 0.5])
                SizedBox(
                  width: 200,
                  height: 140,
                  child: Stack(children: [
                    Positioned.fill(child: _Still(demo: k, t: t)),
                    Positioned(left: 4, top: 2, child: Text(k, style: const TextStyle(fontSize: 11, color: Colors.black))),
                  ]),
                ),
          ]),
        ),
      ),
    ));
    await tester.runAsync(() async {
      final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await ro.toImage(pixelRatio: 1);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/figures.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: dir == null);
}

class _Still extends StatelessWidget {
  const _Still({required this.demo, required this.t});
  final String demo;
  final double t;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _P(demoFor(demo), t));
}

class _P extends CustomPainter {
  _P(this.d, this.t);
  final Demo d;
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / Rig.stageW;
    canvas.scale(s);
    final paint = Paint()..color = const Color(0x33000000);
    canvas.drawRect(const Rect.fromLTWH(0, Rig.floor, Rig.stageW, 0.01), paint);
    if (d.wallX != null) canvas.drawRect(Rect.fromLTWH(d.wallX!, 0, 0.03, Rig.floor), paint);
    for (final p in d.props) {
      canvas.drawRect(p.rect, paint);
    }
    final k = Skeleton.solve(d.at(t));
    final near = Paint()
      ..color = const Color(0xFF111113)
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final far = Paint()
      ..color = const Color(0x88111113)
      ..strokeWidth = 0.05
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void limb(Offset a, Offset b, Offset c, Paint p) => canvas.drawPath(Path()..moveTo(a.dx, a.dy)..lineTo(b.dx, b.dy)..lineTo(c.dx, c.dy), p);
    limb(k.hip, k.fKnee, k.fAnkle, far);
    limb(k.shoulder, k.fElbow, k.fHand, far);
    canvas.drawLine(k.hip, k.neckTop, near..strokeWidth = 0.08);
    near.strokeWidth = 0.05;
    canvas.drawCircle(k.head, Rig.headR, Paint()..color = const Color(0xFF111113));
    limb(k.hip, k.nKnee, k.nAnkle, near);
    limb(k.shoulder, k.nElbow, k.nHand, near);
  }

  @override
  bool shouldRepaint(_P o) => false;
}
