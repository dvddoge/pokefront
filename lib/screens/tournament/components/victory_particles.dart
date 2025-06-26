import 'package:flutter/material.dart';
import 'dart:math' as math;

class VictoryParticles extends StatefulWidget {
  final bool isActive;
  final Duration duration;

  const VictoryParticles({
    Key? key,
    required this.isActive,
    this.duration = const Duration(seconds: 3),
  }) : super(key: key);

  @override
  _VictoryParticlesState createState() => _VictoryParticlesState();
}

class _VictoryParticlesState extends State<VictoryParticles>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<Particle> particles;
  final random = math.Random();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    particles = List.generate(50, (index) => _createParticle());

    if (widget.isActive) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(VictoryParticles oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      particles = List.generate(50, (index) => _createParticle());
      _animationController.reset();
      _animationController.forward();
    }
  }

  Particle _createParticle() {
    return Particle(
      x: random.nextDouble(),
      y: random.nextDouble(),
      size: random.nextDouble() * 8 + 4,
      color: _getRandomColor(),
      velocityX: (random.nextDouble() - 0.5) * 2,
      velocityY: random.nextDouble() * -2 - 1,
      rotation: random.nextDouble() * math.pi * 2,
      rotationSpeed: (random.nextDouble() - 0.5) * 4,
    );
  }

  Color _getRandomColor() {
    final colors = [
      Colors.amber[300]!,
      Colors.amber[500]!,
      Colors.amber[700]!,
      Colors.orange[300]!,
      Colors.orange[500]!,
      Colors.yellow[300]!,
      Colors.yellow[500]!,
    ];
    return colors[random.nextInt(colors.length)];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return CustomPaint(
          painter: ParticlePainter(
            particles: particles,
            animationValue: _animationController.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class Particle {
  double x;
  double y;
  final double size;
  final Color color;
  final double velocityX;
  final double velocityY;
  double rotation;
  final double rotationSpeed;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.velocityX,
    required this.velocityY,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double animationValue;

  ParticlePainter({
    required this.particles,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(1.0 - animationValue)
        ..style = PaintingStyle.fill;

      // Atualiza posição da partícula
      final currentX = particle.x * size.width + 
          (particle.velocityX * animationValue * size.width * 0.5);
      final currentY = particle.y * size.height + 
          (particle.velocityY * animationValue * size.height * 0.5);
      final currentRotation = particle.rotation + 
          (particle.rotationSpeed * animationValue);

      canvas.save();
      canvas.translate(currentX, currentY);
      canvas.rotate(currentRotation);

      // Desenha diferentes formas de partículas
      final shapeType = particle.size.toInt() % 4;
      switch (shapeType) {
        case 0: // Círculo
          canvas.drawCircle(Offset.zero, particle.size, paint);
          break;
        case 1: // Estrela
          _drawStar(canvas, paint, particle.size);
          break;
        case 2: // Quadrado
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size * 2,
              height: particle.size * 2,
            ),
            paint,
          );
          break;
        case 3: // Triângulo
          _drawTriangle(canvas, paint, particle.size);
          break;
      }

      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final path = Path();
    final outerRadius = size;
    final innerRadius = size * 0.5;
    final points = 5;

    for (int i = 0; i < points * 2; i++) {
      final angle = (i * math.pi) / points;
      final radius = i.isEven ? outerRadius : innerRadius;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  void _drawTriangle(Canvas canvas, Paint paint, double size) {
    final path = Path();
    path.moveTo(0, -size);
    path.lineTo(-size, size);
    path.lineTo(size, size);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

class ConfettiExplosion extends StatefulWidget {
  final bool isActive;
  final Widget child;

  const ConfettiExplosion({
    Key? key,
    required this.isActive,
    required this.child,
  }) : super(key: key);

  @override
  _ConfettiExplosionState createState() => _ConfettiExplosionState();
}

class _ConfettiExplosionState extends State<ConfettiExplosion>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.5,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: math.pi * 2,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    if (widget.isActive) {
      _controller.forward();
    }
  }

  @override
  void didUpdateWidget(ConfettiExplosion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.isActive)
          Positioned.fill(
            child: VictoryParticles(isActive: widget.isActive),
          ),
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform.rotate(
                angle: _rotationAnimation.value,
                child: widget.child,
              ),
            );
          },
        ),
      ],
    );
  }
} 