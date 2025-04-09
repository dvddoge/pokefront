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
                Colors.red[900]!.withOpacity(0.9),
                Colors.red[700]!.withOpacity(0.8),
                Colors.red[500]!.withOpacity(0.7),
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
    // Desenha círculos concêntricos no centro
    _drawConcentricCircles(canvas, size);
    
    // Desenha formas geométricas no centro
    _drawGeometricShapes(canvas, size);
  }
  
  void _drawConcentricCircles(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.white.withOpacity(0.4);
    
    // Centro entre os dois Pokémon (centro da tela, um pouco acima do meio)
    final center = Offset(size.width * 0.5, size.height * 0.35);
    
    // Desenha círculos concêntricos pulsantes
    for (int i = 0; i < 4; i++) {
      final circlePhase = (i / 4) + animation;
      final circleProgress = (circlePhase % 1.0);
      
      // Varia a opacidade com base na fase
      final opacity = 0.4 - (circleProgress * 0.2);
      
      if (opacity > 0) {
        circlePaint.color = Colors.white.withOpacity(opacity);
        
        // Raio do círculo - cresce com o progresso
        // Tamanho maior para ocupar mais espaço entre os Pokémon
        final radius = circleProgress * size.width * 0.3;
        
        canvas.drawCircle(center, radius, circlePaint);
      }
    }
  }
  
  void _drawGeometricShapes(Canvas canvas, Size size) {
    // Centro entre os dois Pokémon (centro da tela, um pouco acima do meio)
    final center = Offset(size.width * 0.5, size.height * 0.35);
    
    // Desenha retângulos que giram
    _drawRotatingRectangles(canvas, size, center);
    
    // Desenha triângulos que giram
    _drawRotatingTriangles(canvas, size, center);
    
    // Desenha hexágono que gira
    _drawRotatingHexagon(canvas, size, center);
  }
  
  void _drawRotatingRectangles(Canvas canvas, Size size, Offset center) {
    final rectPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.3);
    
    // Desenha retângulos que giram
    for (int i = 0; i < 3; i++) {
      // Direção de rotação
      final angle = animation * math.pi * 2;
      
      // Tamanho do retângulo - maior para ocupar mais espaço
      final rectSize = 80.0 + (i * 60.0);
      
      // Salva o estado atual do canvas
      canvas.save();
      
      // Translada para o centro
      canvas.translate(center.dx, center.dy);
      
      // Rotaciona o canvas
      canvas.rotate(angle + (i * math.pi / 6));
      
      // Desenha o retângulo centralizado
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: rectSize,
        height: rectSize,
      );
      
      canvas.drawRect(rect, rectPaint);
      
      // Restaura o estado do canvas
      canvas.restore();
    }
  }
  
  void _drawRotatingTriangles(Canvas canvas, Size size, Offset center) {
    final trianglePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.3);
    
    // Desenha triângulos que giram
    for (int i = 0; i < 2; i++) {
      // Direção de rotação oposta aos retângulos
      final angle = -animation * math.pi * 2;
      
      // Salva o estado atual do canvas
      canvas.save();
      
      // Translada para o centro
      canvas.translate(center.dx, center.dy);
      
      // Rotaciona o canvas
      canvas.rotate(angle + (i * math.pi / 3));
      
      // Tamanho do triângulo - maior para ocupar mais espaço
      final triangleSize = 120.0 + (i * 60.0);
      
      // Desenha o triângulo
      final path = Path();
      path.moveTo(0, -triangleSize / 2);
      path.lineTo(triangleSize / 2, triangleSize / 2);
      path.lineTo(-triangleSize / 2, triangleSize / 2);
      path.close();
      
      canvas.drawPath(path, trianglePaint);
      
      // Restaura o estado do canvas
      canvas.restore();
    }
  }
  
  void _drawRotatingHexagon(Canvas canvas, Size size, Offset center) {
    final hexagonPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white.withOpacity(0.3);
    
    // Salva o estado atual do canvas
    canvas.save();
    
    // Translada para o centro
    canvas.translate(center.dx, center.dy);
    
    // Rotaciona o canvas em velocidade diferente
    canvas.rotate(animation * math.pi);
    
    // Tamanho do hexágono
    final hexagonSize = 100.0;
    
    // Desenha o hexágono
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi / 3);
      final x = hexagonSize * math.cos(angle);
      final y = hexagonSize * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    
    canvas.drawPath(path, hexagonPaint);
    
    // Restaura o estado do canvas
    canvas.restore();
  }

  @override
  bool shouldRepaint(BattleBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
} 