import 'package:flutter/material.dart';

class ThreeDGridBackground extends StatefulWidget {
  const ThreeDGridBackground({super.key});

  @override
  State<ThreeDGridBackground> createState() => _ThreeDGridBackgroundState();
}

class _ThreeDGridBackgroundState extends State<ThreeDGridBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: GridPainter(_controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class GridPainter extends CustomPainter {
  final double progress;
  GridPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A5CFF).withOpacity(0.08)
      ..strokeWidth = 1.0;

    const int lines = 20;
    final double spacing = size.width / lines;

    // Draw perspective grid
    canvas.save();
    
    // Create perspective matrix
    final matrix = Matrix4.identity()
      ..setEntry(3, 2, 0.001)
      ..rotateX(0.8);
    
    canvas.transform(matrix.storage);

    // Moving horizontal lines
    for (int i = -10; i < 30; i++) {
      double y = (i * spacing) + (progress * spacing);
      canvas.drawLine(
        Offset(-size.width, y),
        Offset(size.width * 2, y),
        paint,
      );
    }

    // Vertical lines
    for (int i = -10; i < lines + 10; i++) {
      double x = i * spacing;
      canvas.drawLine(
        Offset(x, -size.height),
        Offset(x, size.height * 2),
        paint,
      );
    }

    canvas.restore();

    // Add a dark glow/gradient at the horizon
    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF0F172A).withOpacity(0.0),
        const Color(0xFF0F172A).withOpacity(0.9),
        const Color(0xFF0F172A),
      ],
      stops: const [0.0, 0.6, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) => true;
}
