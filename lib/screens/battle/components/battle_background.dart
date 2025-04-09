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
    // Desenha apenas os círculos concêntricos pulsantes
    _drawConcentricCircles(canvas, size);
  }
  
  void _drawConcentricCircles(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..style = PaintingStyle.stroke;
      // ..strokeWidth = 2.0; // Ajustaremos a largura dinamicamente
      // ..color = Colors.white.withOpacity(0.4); // Ajustaremos cor/opacidade dinamicamente
    
    // Centro da tela, ajustado mais para cima para não ser coberto pela UI inferior
    final center = Offset(size.width * 0.5, size.height * 0.30); // Ajustado de 0.35 para 0.30
    
    // Número de círculos pulsantes
    final int numCircles = 5;
    // Raio máximo (um pouco menor que metade da largura para não tocar as bordas)
    final double maxRadius = size.width * 0.4;

    for (int i = 0; i < numCircles; i++) {
      // Calcula uma fase de animação para cada círculo, ligeiramente defasada
      // Usando seno para criar um movimento de pulsação suave (vai de -1 a 1)
      final double phaseOffset = i / numCircles;
      final double pulse = math.sin((animation + phaseOffset) * math.pi * 2);
      
      // Normaliza o pulso para 0 a 1 (0 = menor, 1 = maior)
      final double normalizedPulse = (pulse + 1) / 2;

      // Calcula o raio atual baseado na pulsação
      final double currentRadius = maxRadius * normalizedPulse;
      
      // Calcula a opacidade e a largura do traço baseado na pulsação
      // Mais opaco e grosso quando maior, mais tênue e fino quando menor
      final double opacity = 0.1 + (normalizedPulse * 0.3); // Opacidade entre 0.1 e 0.4
      final double strokeWidth = 1.0 + (normalizedPulse * 2.0); // Largura entre 1.0 e 3.0

      if (currentRadius > 0 && opacity > 0.1) { // Desenha apenas se visível
        circlePaint
          ..color = Colors.white.withOpacity(opacity)
          ..strokeWidth = strokeWidth;
        
        canvas.drawCircle(center, currentRadius, circlePaint);
      }
    }
  }
  
  // Remover as funções de desenho de formas geométricas
  /*
  void _drawGeometricShapes(Canvas canvas, Size size) { ... }
  void _drawRotatingRectangles(Canvas canvas, Size size, Offset center) { ... }
  void _drawRotatingTriangles(Canvas canvas, Size size, Offset center) { ... }
  void _drawRotatingHexagon(Canvas canvas, Size size, Offset center) { ... }
  */

  @override
  bool shouldRepaint(BattleBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
} 