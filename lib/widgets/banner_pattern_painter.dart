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
    
    // Animação mais dinâmica para batalha
    for (var i = 0; i < 3; i++) {
      final phase = progress * 2 * math.pi;
      final wave = math.sin(phase + i * math.pi / 3) * 12;
      final scale = 1.0 + math.cos(phase * 0.5 + i * math.pi / 3) * 0.15;
      final radius = (maxRadius * (0.5 + i * 0.25) + wave) * scale;
      
      // Movimento orbital mais pronunciado
      final orbitRadius = 8.0;
      final rotationOffset = Offset(
        math.cos(phase * 1.5 + i * math.pi / 3) * orbitRadius,
        math.sin(phase * 1.5 + i * math.pi / 3) * orbitRadius
      );
      
      // Adiciona efeito de pulso
      final pulseOpacity = (math.sin(phase * 2 + i * math.pi / 3) * 0.3 + 0.7).clamp(0.0, 1.0);
      _paint.color = color.withOpacity(pulseOpacity);
      
      canvas.drawCircle(
        center + rotationOffset,
        radius,
        _paint,
      );
    }
  }

  void _paintDefaultPattern(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    
    // Animação suave para o padrão padrão
    for (var i = 0; i < 3; i++) {
      final phase = progress * 2 * math.pi;
      final pulseOffset = math.sin(phase + i * math.pi / 3) * 6;
      
      // Movimento orbital suave
      final orbitRadius = 4.0;
      final rotationOffset = Offset(
        math.cos(phase + i * math.pi / 2) * orbitRadius,
        math.sin(phase + i * math.pi / 2) * orbitRadius
      );
      
      // Efeito de pulso suave
      final pulseOpacity = (math.sin(phase + i * math.pi / 3) * 0.2 + 0.8).clamp(0.0, 1.0);
      _paint.color = color.withOpacity(pulseOpacity);
      
      final radius = maxRadius * (0.5 + i * 0.25) + pulseOffset;
      canvas.drawCircle(
        center + rotationOffset,
        radius,
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