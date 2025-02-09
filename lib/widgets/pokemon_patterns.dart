import 'package:flutter/material.dart';
import 'dart:math' as math;

abstract class PokemonPattern {
  void draw(Canvas canvas, Size size, Paint paint, double progress);
}

class FirePattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final flamePath = Path();
    final flameHeight = size.height * 0.6;
    final flameWidth = size.width * 0.2;

    for (var i = 0; i < 5; i++) {
      final x = size.width * (i / 4);
      final y = size.height - (flameHeight * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + i)));
      flamePath.moveTo(x, size.height);
      flamePath.lineTo(x + flameWidth / 2, y);
      flamePath.lineTo(x - flameWidth / 2, y);
      flamePath.close();
    }

    canvas.drawPath(flamePath, paint);
  }
}

class WaterPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final wavePath = Path();
    final waveHeight = size.height * 0.1;
    final waveLength = size.width * 0.2;

    for (var i = 0; i < size.width / waveLength; i++) {
      final x = waveLength * i;
      final y = size.height * 0.5 + waveHeight * math.sin(progress * math.pi * 2 + i);
      wavePath.moveTo(x, y);
      wavePath.quadraticBezierTo(
        x + waveLength / 4, y - waveHeight,
        x + waveLength / 2, y,
      );
      wavePath.quadraticBezierTo(
        x + 3 * waveLength / 4, y + waveHeight,
        x + waveLength, y,
      );
    }

    canvas.drawPath(wavePath, paint);
  }
}

class GrassPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final bladePath = Path();
    final bladeHeight = size.height * 0.6;
    final bladeWidth = size.width * 0.05;

    for (var i = 0; i < 10; i++) {
      final x = size.width * (i / 9);
      final y = size.height - (bladeHeight * (0.5 + 0.5 * math.sin(progress * math.pi * 2 + i)));
      bladePath.moveTo(x, size.height);
      bladePath.lineTo(x + bladeWidth / 2, y);
      bladePath.lineTo(x - bladeWidth / 2, y);
      bladePath.close();
    }

    canvas.drawPath(bladePath, paint);
  }
}

class ElectricPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final boltPath = Path();
    final numBolts = 5;
    final boltWidth = size.width / numBolts;

    for (var i = 0; i < numBolts; i++) {
      final startX = i * boltWidth;
      final points = <Offset>[];
      
      for (var j = 0; j < 6; j++) {
        final y = size.height * j / 5;
        final phase = progress * math.pi * 2 + i;
        final x = startX + math.sin(phase + j) * (boltWidth * 0.3);
        points.add(Offset(x, y));
      }

      boltPath.moveTo(points[0].dx, points[0].dy);
      for (var j = 1; j < points.length; j++) {
        boltPath.lineTo(points[j].dx, points[j].dy);
      }
    }

    canvas.drawPath(boltPath, paint);
  }
}

class DragonPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final path = Path();
    final radius = size.width * 0.3;
    final center = Offset(size.width / 2, size.height / 2);
    
    for (var i = 0; i < 3; i++) {
      final angle = progress * math.pi * 2 + (i * math.pi * 2 / 3);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      final controlAngle = angle + math.pi / 6;
      final controlRadius = radius * 1.5;
      final controlX = center.dx + math.cos(controlAngle) * controlRadius;
      final controlY = center.dy + math.sin(controlAngle) * controlRadius;
      
      path.quadraticBezierTo(controlX, controlY, x, y);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }
}

class PsychicPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.4;
    
    for (var i = 0; i < 3; i++) {
      final path = Path();
      final radius = maxRadius * (1 + math.sin(progress * math.pi * 2 + i)) / 2;
      
      for (var angle = 0.0; angle <= math.pi * 2; angle += 0.1) {
        final offset = math.sin(angle * 3 + progress * math.pi * 2) * 20;
        final x = center.dx + math.cos(angle) * (radius + offset);
        final y = center.dy + math.sin(angle) * (radius + offset);
        
        if (angle == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }
}

class GhostPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final wavePath = Path();
    final waveCount = 5;
    final amplitude = size.height * 0.1;
    
    for (var i = 0; i < waveCount; i++) {
      final startX = size.width * i / (waveCount - 1);
      final endX = startX + size.width / (waveCount - 1);
      final y = size.height * 0.5 + 
                math.sin(progress * math.pi * 2 + i) * amplitude;
      
      if (i == 0) {
        wavePath.moveTo(startX, y);
      }
      
      final controlPoint1 = Offset(
        startX + (endX - startX) * 0.5,
        y + amplitude * math.cos(progress * math.pi * 2 + i),
      );
      
      final controlPoint2 = Offset(
        startX + (endX - startX) * 0.5,
        y - amplitude * math.cos(progress * math.pi * 2 + i),
      );
      
      wavePath.cubicTo(
        controlPoint1.dx, controlPoint1.dy,
        controlPoint2.dx, controlPoint2.dy,
        endX, y,
      );
    }
    
    canvas.drawPath(wavePath, paint);
  }
}

class FairyPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
    final starCount = 5;
    final starPoints = 5;
    
    for (var i = 0; i < starCount; i++) {
      final center = Offset(
        size.width * ((i + 0.5) / starCount),
        size.height * 0.5 + math.sin(progress * math.pi * 2 + i) * 20,
      );
      
      final path = Path();
      final outerRadius = size.width * 0.1;
      final innerRadius = outerRadius * 0.4;
      
      for (var j = 0; j < starPoints * 2; j++) {
        final angle = (j * math.pi) / starPoints;
        final radius = j.isEven ? outerRadius : innerRadius;
        final x = center.dx + math.cos(angle + progress) * radius;
        final y = center.dy + math.sin(angle + progress) * radius;
        
        if (j == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      path.close();
      canvas.drawPath(path, paint);
    }
  }
}

class DefaultPattern extends PokemonPattern {
  @override
  void draw(Canvas canvas, Size size, Paint paint, double progress) {
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
}

class PokemonPatternFactory {
  static PokemonPattern getPattern(String type) {
    switch (type.toLowerCase()) {
      case 'fire':
        return FirePattern();
      case 'water':
        return WaterPattern();
      case 'grass':
        return GrassPattern();
      case 'electric':
        return ElectricPattern();
      case 'dragon':
        return DragonPattern();
      case 'psychic':
        return PsychicPattern();
      case 'ghost':
        return GhostPattern();
      case 'fairy':
        return FairyPattern();
      default:
        return DefaultPattern();
    }
  }
}