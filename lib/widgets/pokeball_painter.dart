import 'package:flutter/material.dart';
import 'dart:math' as math;

class PokeballPainter extends CustomPainter {
  final Color color;

  PokeballPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = math.min(size.width, size.height) / 2;

    // Desenha o círculo externo
    canvas.drawCircle(Offset(centerX, centerY), radius, paint);

    // Desenha a linha horizontal
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      paint,
    );

    // Desenha o círculo central
    canvas.drawCircle(
      Offset(centerX, centerY),
      radius / 4,
      paint,
    );
  }

  @override
  bool shouldRepaint(PokeballPainter oldDelegate) {
    return color != oldDelegate.color;
  }
} 