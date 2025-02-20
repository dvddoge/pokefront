import 'package:flutter/material.dart';
import 'dart:math' as math;

class BattleBackground extends StatelessWidget {
  final Animation<double> animation;

  const BattleBackground({
    Key? key,
    required this.animation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.red[900]!.withOpacity(0.95),
                Colors.red[800]!.withOpacity(0.9),
                Colors.red[700]!.withOpacity(0.85),
              ],
            ),
          ),
          child: CustomPaint(
            painter: BattleBackgroundPainter(
              animation: animation.value,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }
}

class BattleBackgroundPainter extends CustomPainter {
  final double animation;

  BattleBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    // Desenha círculos concêntricos com branco forte
    for (int i = 0; i < 5; i++) {
      paint.color = Colors.white.withOpacity(0.8 - (i * 0.12));
      final radius = 100.0 + (i * 80.0) + (math.sin(animation * 2 * math.pi) * 10);
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BattleBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
} 