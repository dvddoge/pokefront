import 'package:flutter/material.dart';

class PokeballPainter extends CustomPainter {
  final Color color;

  PokeballPainter({
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width < size.height ? size.width / 2 : size.height / 2;

    // Desenha o círculo externo
    canvas.drawCircle(center, radius, paint);

    // Desenha a linha horizontal
    final linePaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius / 15;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );

    // Desenha o círculo central
    final centerCirclePaint = Paint()
      ..color = color.withOpacity(0.9)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius / 5, centerCirclePaint);

    // Desenha o anel do círculo central
    final ringPaint = Paint()
      ..color = color.withOpacity(0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius / 25;

    canvas.drawCircle(center, radius / 5, ringPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 