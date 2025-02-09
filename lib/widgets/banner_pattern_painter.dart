import 'package:flutter/material.dart';
import 'pokemon_patterns.dart';

class BannerPatternPainter extends CustomPainter {
  final Color color;
  final double progress;
  final String type;

  BannerPatternPainter({
    required this.color,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pattern = PokemonPatternFactory.getPattern(type);
    pattern.draw(canvas, size, paint, progress);
  }

  @override
  bool shouldRepaint(BannerPatternPainter oldDelegate) {
    return oldDelegate.progress != progress || 
           oldDelegate.color != color || 
           oldDelegate.type != type;
  }
}