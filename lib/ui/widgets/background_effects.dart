import 'dart:math';
import 'package:flutter/material.dart';

class BackgroundEffects extends StatefulWidget {
  const BackgroundEffects({super.key});

  @override
  State<BackgroundEffects> createState() => _BackgroundEffectsState();
}

class _BackgroundEffectsState extends State<BackgroundEffects>
    with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          size: MediaQuery.of(context).size,
          painter: _BackgroundPainter(
            animationValue: _controller.value,
            size: MediaQuery.of(context).size,
          ),
        );
      },
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animationValue;
  final Size size;
  final Random _random = Random(42);

  _BackgroundPainter({required this.animationValue, required this.size});

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);
    _drawParticles(canvas, size);
    _drawCrystal(canvas, size);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00ff88).withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 60.0;
    final offset = (animationValue * spacing);

    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }
    for (double y = offset; y < size.height; y += spacing) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    const particleCount = 40;
    for (int i = 0; i < particleCount; i++) {
      final x = (i * 37 + _random.nextDouble() * 50) % size.width;
      final speed = 0.3 + _random.nextDouble() * 0.7;
      final y = ((animationValue * size.height * speed + i * 50) % (size.height + 100)) - 50;
      final radius = 1.5 + _random.nextDouble() * 3;
      final isCyan = i % 7 == 0;
      final color = isCyan ? const Color(0xFF00ffff) : const Color(0xFF00ff88);

      final paint = Paint()
        ..color = color.withOpacity(0.6)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _drawCrystal(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final crystalSize = 140.0;

    // Orbits
    final orbitPaint = Paint()
      ..color = const Color(0xFF00ff88).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < 3; i++) {
      final orbitRadius = 160.0 + i * 50;
      final rotation = animationValue * 2 * pi * (i % 2 == 0 ? 1 : -1) * (0.5 + i * 0.2);
      final path = Path();
      for (double a = 0; a <= 2 * pi; a += 0.1) {
        final x = centerX + cos(a + rotation) * orbitRadius;
        final y = centerY + sin(a + rotation) * orbitRadius * 0.5;
        if (a == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, orbitPaint);
    }

    // Voxel crystal
    final pattern = [
      [0,0,0,1,1,0,0,0],
      [0,0,1,2,3,1,0,0],
      [0,1,2,4,3,2,1,0],
      [0,1,3,4,4,3,1,0],
      [1,2,3,4,4,3,2,1],
      [1,2,3,3,3,3,2,1],
      [1,2,2,3,3,2,2,1],
      [0,1,2,2,2,2,1,0],
      [0,1,1,2,2,1,1,0],
      [0,0,1,5,5,1,0,0],
    ];

    final colors = [
      Colors.transparent,
      const Color(0xFF00ff88).withOpacity(0.9),
      const Color(0xFF006633).withOpacity(0.8),
      const Color(0xFF00cc6a).withOpacity(0.85),
      const Color(0xFF88ffcc).withOpacity(0.9),
      const Color(0xFF0099ff).withOpacity(0.7),
    ];

    final voxelW = crystalSize / 8;
    final voxelH = crystalSize / 10;
    final startX = centerX - crystalSize / 2;
    final startY = centerY - crystalSize * 0.6;

    for (int row = 0; row < 10; row++) {
      for (int col = 0; col < 8; col++) {
        final type = pattern[row][col];
        if (type == 0) continue;

        final rect = Rect.fromLTWH(
          startX + col * voxelW,
          startY + row * voxelH,
          voxelW - 1,
          voxelH - 1,
        );

        final paint = Paint()
          ..color = colors[type]
          ..maskFilter = type == 1 || type == 4
              ? const MaskFilter.blur(BlurStyle.normal, 4)
              : null;

        canvas.drawRect(rect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
