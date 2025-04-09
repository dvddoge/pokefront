import 'package:flutter/material.dart';
import 'dart:math' as math;

class BattleTransition extends StatefulWidget {
  final VoidCallback onTransitionComplete;
  final VoidCallback onMidpoint;
  final bool waitForBattleScreen;

  const BattleTransition({
    Key? key,
    required this.onTransitionComplete,
    required this.onMidpoint,
    this.waitForBattleScreen = false,
  }) : super(key: key);

  @override
  _BattleTransitionState createState() => _BattleTransitionState();
}

class _BattleTransitionState extends State<BattleTransition> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _curtainAnimation;
  late Animation<double> _pokeballRotation;
  late Animation<double> _pokeballScale;
  late Animation<double> _openingAnimation;
  bool _midpointReached = false;
  bool _midpointCallbackCalled = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    print('Inicializando BattleTransition');
    _controller = AnimationController(
      duration: Duration(milliseconds: 3000),
      vsync: this,
    );

    // Animação das cortinas fechando (0.0 - 0.3)
    _curtainAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 0.3, curve: Curves.easeInOut),
    ));

    // Animação da pokebola girando (0.0 - 1.0) - agora gira durante toda a animação
    _pokeballRotation = Tween<double>(
      begin: 0.0,
      end: 8 * math.pi, // 4 rotações completas
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.0, 1.0, curve: Curves.easeInOut),
    ));

    // Animação da pokebola pulsando (0.3 - 0.7)
    _pokeballScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3),
        weight: 1.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0),
        weight: 1.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.3, 0.7, curve: Curves.easeInOut),
    ));

    // Animação das cortinas abrindo (0.7 - 1.0)
    _openingAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Interval(0.7, 1.0, curve: Curves.easeInOut),
    ));

    _controller.addListener(_checkMidpoint);
    _controller.addStatusListener(_checkCompletion);

    // Inicia a animação até o ponto médio
    _startInitialAnimation();
  }

  void _startInitialAnimation() {
    // Anima até o ponto médio (cortinas fechadas)
    if (_disposed) return;
    
    try {
      print('Iniciando animação de transição da batalha');
      // Inicia a animação completa sem pausas
      _controller.animateTo(0.3, duration: Duration(milliseconds: 900)).then((_) {
        if (_disposed || !mounted) return;
        
        print('Primeiro estágio da animação concluído (cortinas fechadas)');
        // Chama o callback do ponto médio
        _midpointReached = true;
        try {
          print('Chamando callback de ponto médio');
          widget.onMidpoint();
        } catch (e) {
          print('Erro ao chamar onMidpoint: $e');
        }
        
        // Pausa por um momento nas cortinas fechadas (tempo aumentado para 1500ms)
        Future.delayed(Duration(milliseconds: 1500), () {
          if (_disposed || !mounted) return;
          
          print('Continuando animação após pausa (cortinas abrindo)');
          // Continua a animação até o final
          try {
            _controller.animateTo(1.0, duration: Duration(milliseconds: 1500));
          } catch (e) {
            print('Erro ao completar animação de transição: $e');
          }
        });
      });
    } catch (e) {
      print('Erro ao iniciar animação de transição: $e');
    }
  }

  void _checkMidpoint() {
    // Verifica o progresso da animação para debugging
    if (_controller.value > 0.0 && _controller.value < 0.1 && !_midpointCallbackCalled) {
      print('Animação iniciada: ${(_controller.value * 100).toStringAsFixed(1)}%');
    }
  }

  void _checkCompletion(AnimationStatus status) {
    // Verifica se o widget ainda está montado
    if (_disposed) return;
    
    if (status == AnimationStatus.completed) {
      print('Animação de transição completada');
      try {
        widget.onTransitionComplete();
      } catch (e) {
        print('Erro ao chamar onTransitionComplete: $e');
      }
    }
  }

  @override
  void didUpdateWidget(BattleTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Não precisamos mais reagir a mudanças no waitForBattleScreen
  }

  @override
  void dispose() {
    print('Disposing BattleTransition');
    _disposed = true;
    _controller.removeListener(_checkMidpoint);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // Calcula a posição da pokebola durante a animação
        double pokeballPositionX;
        double pokeballPositionY = screenHeight / 2 - 30; // Centro vertical
        
        if (_controller.value <= 0.3) {
          // Durante o fechamento das cortinas (0.0 - 0.3)
          // A pokebola começa na direita e se move para o centro
          double progress = _controller.value / 0.3; // 0.0 -> 1.0 durante esta fase
          pokeballPositionX = screenWidth - 90 - (progress * (screenWidth / 2 - 30));
        } else if (_controller.value >= 0.7) {
          // Durante a abertura das cortinas (0.7 - 1.0)
          // A pokebola se move do centro para a esquerda
          double progress = (_controller.value - 0.7) / 0.3; // 0.0 -> 1.0 durante esta fase
          pokeballPositionX = (screenWidth / 2 - 30) - (progress * (screenWidth / 2 + 30));
        } else {
          // Quando as cortinas estão fechadas (0.3 - 0.7)
          // A pokebola fica no centro
          pokeballPositionX = screenWidth / 2 - 30;
        }
        
        return Stack(
          children: [
            // Fundo preto (para garantir que não haja espaços vazios)
            Container(
              color: Colors.black,
              width: screenWidth,
              height: screenHeight,
            ),
            
            // Cortina esquerda
            Positioned(
              left: -screenWidth * (1 - _curtainAnimation.value),
              top: 0,
              bottom: 0,
              width: screenWidth,
              child: Container(
                color: Colors.black,
              ),
            ),
            
            // Cortina direita
            Positioned(
              right: -screenWidth * (1 - _curtainAnimation.value),
              top: 0,
              bottom: 0,
              width: screenWidth,
              child: Container(
                color: Colors.black,
              ),
            ),
            
            // Pokebola (sempre visível, posição calculada dinamicamente)
            Positioned(
              left: pokeballPositionX,
              top: pokeballPositionY,
              child: _buildPokeball(),
            ),
            
            // Cortinas abrindo
            if (_controller.value > 0.7) ...[
              Positioned(
                left: -screenWidth * _openingAnimation.value,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: Container(
                  color: Colors.black,
                ),
              ),
              Positioned(
                right: -screenWidth * _openingAnimation.value,
                top: 0,
                bottom: 0,
                width: screenWidth,
                child: Container(
                  color: Colors.black,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPokeball() {
    // Aplica rotação e escala à pokebola
    return Transform.rotate(
      angle: _pokeballRotation.value,
      child: Transform.scale(
        scale: _controller.value >= 0.3 && _controller.value <= 0.7
            ? _pokeballScale.value
            : 1.0,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Stack(
              children: [
                // Parte superior da pokebola (vermelha)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 30,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ),
                
                // Linha central da pokebola
                Positioned(
                  top: 27.5,
                  left: 0,
                  right: 0,
                  height: 5,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
                
                // Círculo central da pokebola
                Positioned(
                  top: 22.5,
                  left: 22.5,
                  child: Container(
                    width: 15,
                    height: 15,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.black,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Mantido para compatibilidade
  void _continueToBattleScreen() {
    // Método vazio para compatibilidade
  }
} 