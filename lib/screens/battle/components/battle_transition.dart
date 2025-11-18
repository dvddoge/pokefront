import 'package:flutter/material.dart';
import 'dart:math' as math;

// Enum para definir a fase da animação
enum TransitionPhase { full, closing, opening }

class BattleTransition extends StatefulWidget {
  final VoidCallback onTransitionComplete;
  final VoidCallback onMidpoint;
  final TransitionPhase phase;

  const BattleTransition({
    Key? key,
    required this.onTransitionComplete,
    required this.onMidpoint,
    this.phase = TransitionPhase.full,
  }) : super(key: key);

  @override
  _BattleTransitionState createState() => _BattleTransitionState();
}

class _BattleTransitionState extends State<BattleTransition>
    with TickerProviderStateMixin {
  late AnimationController _curtainController;
  late AnimationController _spinController;
  late AnimationController _flashController; // Controlador para o flash branco
  bool _disposed = false;
  bool _openingCompleted = false;

  final double pokeballSize = 80.0; // Aumentei um pouco para mais destaque

  @override
  void initState() {
    super.initState();

    _curtainController = AnimationController(
      duration: const Duration(milliseconds: 800),
      value: widget.phase == TransitionPhase.opening ? 1.0 : 0.0,
      vsync: this,
    );

    _spinController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _flashController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _curtainController.addListener(() => setState(() {}));
    _spinController.addListener(() => setState(() {}));
    _flashController.addListener(() => setState(() {}));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_disposed) return;
      if (widget.phase == TransitionPhase.closing) {
        _startClosingSequence();
      } else if (widget.phase == TransitionPhase.opening) {
        _startOpeningSequence();
      } else {
        _startFullSequence();
      }
    });
  }

  void _startFullSequence() async {
    await _closeCurtains();
    await _spinPokeball();
    // Inicia o flash junto com a abertura
    _flashController.forward(from: 0.0);
    await _openCurtains();
    _completeTransition();
  }

  void _startClosingSequence() async {
    await _closeCurtains();
    _completeTransition(isClosingOnly: true);
  }

  void _startOpeningSequence() async {
    try {
      await Future.delayed(const Duration(milliseconds: 50));
      if (_disposed) return;
      widget.onMidpoint();
    } catch (e) {
      print('Erro ao chamar onMidpoint: $e');
    }

    await _spinPokeball();
    _flashController.forward(from: 0.0);
    await _openCurtains();
    _completeTransition();
  }

  Future<void> _closeCurtains() async {
    if (_disposed) return;
    try {
      await _curtainController
          .animateTo(1.0,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeInExpo // Batida mais seca e rápida
              )
          .orCancel;

      if (_disposed) return;

      if (widget.phase != TransitionPhase.opening) {
        try {
          widget.onMidpoint();
        } catch (e) {
          print('Erro ao chamar onMidpoint: $e');
        }
      }
    } on TickerCanceled {
      // Ignorar cancelamento
    } catch (e) {
      print('Erro ao fechar cortinas: $e');
    }
  }

  Future<void> _spinPokeball() async {
    if (_disposed) return;
    try {
      // Gira e pulsa
      await _spinController.forward().orCancel;
      if (_disposed) return;
      _spinController.reset();
    } on TickerCanceled {
      // Ignorar
    } catch (e) {
      print('Erro ao girar pokebola: $e');
    }
  }

  Future<void> _openCurtains() async {
    if (_disposed) return;
    try {
      await _curtainController
          .animateTo(0.0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutExpo // Abertura explosiva
              )
          .orCancel;
    } on TickerCanceled {
      // Ignorar
    } catch (e) {
      print('Erro ao abrir cortinas: $e');
    }
  }

  void _completeTransition({bool isClosingOnly = false}) {
    if (_disposed || _openingCompleted) return;
    _openingCompleted = true;
    try {
      widget.onTransitionComplete();
    } catch (e) {
      print('Erro ao chamar onTransitionComplete: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _curtainController.dispose();
    _spinController.dispose();
    _flashController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final halfScreenWidth = screenWidth / 2;

    final curtainProgress = _curtainController.value;
    final leftCurtainWidth = halfScreenWidth * curtainProgress;
    final rightCurtainLeft = screenWidth - (halfScreenWidth * curtainProgress);

    // Se estiver girando (fase fechada), trava no centro.
    // Caso contrário (abrindo/fechando), segue a cortina.
    final isSpinning = _spinController.isAnimating;
    final pokeballPositionX = isSpinning
        ? (screenWidth / 2) - (pokeballSize / 2)
        : rightCurtainLeft - (pokeballSize / 2);
    final pokeballPositionY = (screenHeight / 2) - (pokeballSize / 2);

    // Animação da Pokebola
    final spinValue = _spinController.value;
    final pokeballSpinAngle = spinValue * 6 * math.pi;
    // Escala pulsante: cresce e diminui com energia
    final pokeballScale = 1.0 + (0.3 * math.sin(spinValue * 3 * math.pi)).abs();
    final glowOpacity =
        (math.sin(spinValue * 3 * math.pi)).abs().clamp(0.0, 1.0);

    // Flash branco
    final flashOpacity = (1.0 - _flashController.value).clamp(0.0, 1.0);
    final showFlash = _flashController.isAnimating ||
        (_flashController.value > 0 && _flashController.value < 1);

    return IgnorePointer(
      ignoring: widget.phase != TransitionPhase.opening ||
          _curtainController.isAnimating ||
          _spinController.isAnimating,
      child: Stack(
        children: [
          // Fundo escuro base
          if (curtainProgress > 0)
            Container(color: Colors.black.withOpacity(curtainProgress * 0.5)),

          // Cortina Esquerda
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: leftCurtainWidth,
            child: _buildCyberCurtain(isLeft: true),
          ),

          // Cortina Direita
          Positioned(
            left: rightCurtainLeft,
            top: 0,
            bottom: 0,
            right: 0,
            child: _buildCyberCurtain(isLeft: false),
          ),

          // Pokebola acompanha a cortina direita
          if (curtainProgress > 0.0 || _spinController.isAnimating)
            Positioned(
              left: pokeballPositionX,
              top: pokeballPositionY,
              child: Transform.scale(
                scale: pokeballScale,
                child: Transform.rotate(
                  angle: pokeballSpinAngle,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // Aura de energia
                      if (glowOpacity > 0.1)
                        OverflowBox(
                          maxWidth: pokeballSize * 2,
                          maxHeight: pokeballSize * 2,
                          child: Container(
                            width: pokeballSize * 1.5,
                            height: pokeballSize * 1.5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.cyanAccent
                                      .withOpacity(0.6 * glowOpacity),
                                  Colors.blue.withOpacity(0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      _buildPokeball(),
                    ],
                  ),
                ),
              ),
            ),

          // Flash Branco de Transição
          if (showFlash)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(flashOpacity),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCyberCurtain({required bool isLeft}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: const [
            Color(0xFF050505), // Quase preto
            Color(0xFF1A1A1A), // Cinza escuro metálico
            Color(0xFF000000), // Preto na junção
          ],
          stops: const [0.0, 0.8, 1.0],
        ),
        boxShadow: [
          // Sombra interna para profundidade
          if (isLeft)
            const BoxShadow(
              color: Color(0xFF00FFFF), // Brilho Cyan na borda
              offset: Offset(2, 0),
              blurRadius: 15,
              spreadRadius: -5,
            )
          else
            const BoxShadow(
              color: Color(0xFF00FFFF),
              offset: Offset(-2, 0),
              blurRadius: 15,
              spreadRadius: -5,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Padrão de grade sutil (Tech Grid)
          Opacity(
            opacity: 0.05,
            child: CustomPaint(
              painter: GridPainter(),
              size: Size.infinite,
            ),
          ),
          // Linha de energia na borda de encontro
          Align(
            alignment: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 3,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.cyanAccent.withOpacity(0.0),
                    Colors.cyanAccent,
                    Colors.cyanAccent.withOpacity(0.0),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.cyanAccent,
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPokeball() {
    return Container(
      width: pokeballSize,
      height: pokeballSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.3, -0.3),
          radius: 1.2,
          colors: [
            Colors.white, // Highlight
            Colors.grey, // Base
          ],
          stops: [0.0, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            spreadRadius: 2,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipOval(
        child: Stack(
          children: [
            // Parte Vermelha (Superior) com gradiente
            Positioned.fill(
              bottom: pokeballSize / 2,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.3, 0.5),
                    radius: 1.0,
                    colors: [
                      Color(0xFFFF5555),
                      Color(0xFFCC0000),
                    ],
                  ),
                ),
              ),
            ),
            // Parte Branca (Inferior) já é o fundo do container, mas reforçamos
            Positioned.fill(
              top: pokeballSize / 2,
              child: Container(color: Colors.white),
            ),
            // Faixa Preta Central
            Center(
              child: Container(
                height: pokeballSize * 0.12,
                width: double.infinity,
                color: const Color(0xFF222222),
              ),
            ),
            // Botão Central
            Center(
              child: Container(
                width: pokeballSize * 0.35,
                height: pokeballSize * 0.35,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF222222),
                    width: pokeballSize * 0.04,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ],
                ),
                // Luz do botão
                child: Center(
                  child: Container(
                    width: pokeballSize * 0.15,
                    height: pokeballSize * 0.15,
                    decoration: BoxDecoration(
                      color: Colors.white, // Botão brilha quando ativo
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.cyanAccent,
                          blurRadius: 5,
                          spreadRadius: 1,
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Painter para o efeito de grade sutil nas cortinas
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const double gridSize = 40.0;

    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
