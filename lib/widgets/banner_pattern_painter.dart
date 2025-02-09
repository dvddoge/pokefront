import 'package:flutter/material.dart';
import 'dart:math' as math;

class BannerPatternPainter extends CustomPainter {
  final Color color;
  final double progress;

  BannerPatternPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final maxRadius = size.width * 0.8;
    final center = Offset(size.width / 2, size.height / 2);

    // Desenha círculos concêntricos com movimento de onda
    for (var i = 0; i < 5; i++) {
      final radius = maxRadius * (0.2 + i * 0.2);
      final wave = math.sin(progress * math.pi * 2 + i * 0.5) * 10;
      
      canvas.drawCircle(
        center,
        radius + wave,
        paint,
      );
    }

    // Desenha linhas diagonais com movimento
    paint.strokeWidth = 1.0;
    final spacing = 40.0;
    final diagonal = math.sqrt(size.width * size.width + size.height * size.height);
    final offset = progress * spacing;

    for (var i = 0; i < diagonal / spacing; i++) {
      final y = i * spacing + offset;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y - size.width),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BannerPatternPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}