import 'package:flutter/material.dart';
import 'dart:math' as math;

class BannerPatternPainter extends CustomPainter {
  final Color color;
  final double progress;
  final String type;
  final Paint _paint;

  BannerPatternPainter({
    required this.color,
    required this.progress,
    required this.type,
  }) : _paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2.0
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    if (type == 'battle') {
      _paintBattlePattern(canvas, size);
    } else {
      _paintDefaultPattern(canvas, size);
    }
  }

  void _paintBattlePattern(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    
    // Otimização: Pre-calcular o seno
    final wave = math.sin(progress * math.pi * 2) * 5;

    // Desenhar círculos com animação de onda
    for (var i = 0; i < 3; i++) {
      final radius = maxRadius * (0.5 + i * 0.25);
      canvas.drawCircle(
        center,
        radius + wave,
        _paint,
      );
    }

    // Desenhar linhas diagonais
    _paint.strokeWidth = 1.0;
    final spacing = 40.0;
    final diagonalCount = (size.width + size.height) ~/ spacing;
    final offset = (progress * spacing * 2) % spacing;

    for (var i = 0; i < diagonalCount; i++) {
      final start = Offset(-size.width, i * spacing + offset);
      final end = Offset(size.width * 2, i * spacing + offset - size.height);
      canvas.drawLine(start, end, _paint);
    }
  }

  void _paintDefaultPattern(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        maxRadius * (0.5 + i * 0.25),
        _paint,
      );
    }
  }

  @override
  bool shouldRepaint(BannerPatternPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color || 
           oldDelegate.type != type;
  }
}