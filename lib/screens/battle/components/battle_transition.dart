import 'package:flutter/material.dart';
import 'dart:math' as math;

// Enum para definir a fase da animação
enum TransitionPhase { full, closing, opening }

class BattleTransition extends StatefulWidget {
  final VoidCallback onTransitionComplete;
  final VoidCallback onMidpoint;
  // Adicionar o parâmetro phase, default é full
  final TransitionPhase phase;

  const BattleTransition({
    Key? key,
    required this.onTransitionComplete,
    required this.onMidpoint,
    // Definir o default como full para não quebrar usos existentes
    this.phase = TransitionPhase.full,
  }) : super(key: key);

  @override
  _BattleTransitionState createState() => _BattleTransitionState();
}

class _BattleTransitionState extends State<BattleTransition> with TickerProviderStateMixin { // Alterado para TickerProvider
  late AnimationController _curtainController; // Controla cortinas e pokeball horizontal
  late AnimationController _spinController;    // Controla giro da pokeball
  bool _disposed = false;
  bool _openingCompleted = false; // Flag para evitar múltiplas chamadas

  final double pokeballSize = 60.0;

  @override
  void initState() {
    super.initState();
    print('Inicializando BattleTransition (Phase: ${widget.phase})');

    _curtainController = AnimationController(
      duration: const Duration(milliseconds: 1000), // 1s para fechar/abrir
      // Define o valor inicial baseado na fase
      value: widget.phase == TransitionPhase.opening ? 1.0 : 0.0,
      vsync: this,
    );

    _spinController = AnimationController(
      duration: const Duration(seconds: 2), // 2s de giro
      vsync: this,
    );

    // Listeners para reconstruir a UI
    _curtainController.addListener(() => setState(() {}));
    _spinController.addListener(() => setState(() {})); // Listener que faltava

    // Inicia a sequência apropriada baseada na fase
    // Adiciona um pequeno delay para garantir que o build inicial ocorra
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

  // Sequência completa (original refatorada)
  void _startFullSequence() async {
    await _closeCurtains();
    await _spinPokeball();
    await _openCurtains();
    _completeTransition();
  }

  // Sequência apenas de fechamento
  void _startClosingSequence() async {
    await _closeCurtains();
    // Para a fase 'closing', onTransitionComplete é chamado aqui
    _completeTransition(isClosingOnly: true);
  }

  // Sequência apenas de abertura (começa com cortinas fechadas)
  void _startOpeningSequence() async {
    // Chama onMidpoint imediatamente pois já estamos no meio
    try {
      // Delay mínimo para garantir que a UI esteja pronta para receber o callback
      await Future.delayed(const Duration(milliseconds: 50));
      if (_disposed) return;
      print('Chamando onMidpoint (início da fase de abertura)');
      widget.onMidpoint();
    } catch (e) {
      print('Erro ao chamar onMidpoint na abertura: $e');
    }
    await _spinPokeball();
    await _openCurtains();
    _completeTransition();
  }

   // Ação de fechar cortinas
  Future<void> _closeCurtains() async {
     if (_disposed) return;
     try {
       print('Fechando cortinas (Heavy Door Effect)...');
       // Usar animateTo com curva easeInQuint para fechamento pesado
       await _curtainController.animateTo(
           1.0,
           duration: _curtainController.duration, // Usar a duração definida no controller
           curve: Curves.easeInQuint
       ).orCancel;
       if (_disposed) return;
       print('Cortinas fechadas, chamando onMidpoint...');
       if (widget.phase != TransitionPhase.opening) {
           try {
             widget.onMidpoint();
           } catch (e) {
             print('Erro ao chamar onMidpoint: $e');
           }
       }
     } on TickerCanceled {
       print('Animação de fechar cortinas cancelada.');
     } catch (e) {
       print('Erro ao fechar cortinas: $e');
     }
  }

  // Ação de girar pokebola
  Future<void> _spinPokeball() async {
    if (_disposed) return;
    try {
      print('Girando pokebola...');
      await _spinController.forward().orCancel;
      if (_disposed) return;
      _spinController.reset();
    } on TickerCanceled {
       print('Animação de giro cancelada.');
    } catch (e) {
       print('Erro ao girar pokebola: $e');
    }
  }

   // Ação de abrir cortinas
  Future<void> _openCurtains() async {
    if (_disposed) return;
    try {
      print('Abrindo cortinas (Heavy Door Effect)...');
      // Usar animateTo (voltando para 0.0) com curva easeOutExpo para abertura rápida inicial
      await _curtainController.animateTo(
          0.0,
          duration: _curtainController.duration, // Usar a duração definida no controller
          curve: Curves.easeOutExpo
      ).orCancel;
    } on TickerCanceled {
      print('Animação de abrir cortinas cancelada.');
    } catch(e) {
      print('Erro ao abrir cortinas: $e');
    }
  }

  // Chama o callback de conclusão final
  void _completeTransition({bool isClosingOnly = false}) {
     if (_disposed || _openingCompleted) return;
     _openingCompleted = true; // Evita chamadas múltiplas
     print('Transição completa (isClosingOnly: $isClosingOnly).');
     try {
       widget.onTransitionComplete();
     } catch (e) {
       print('Erro ao chamar onTransitionComplete: $e');
     }
  }


  @override
  void dispose() {
    print('Disposing BattleTransition');
    _disposed = true;
    _curtainController.dispose();
    _spinController.dispose();
    super.dispose();
  }

  // --- O método build --- 
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final halfScreenWidth = screenWidth / 2;

    final curtainProgress = _curtainController.value;

    final leftCurtainWidth = halfScreenWidth * curtainProgress;

    final rightCurtainLeft = screenWidth - (halfScreenWidth * curtainProgress);

    final pokeballPositionX = rightCurtainLeft - (pokeballSize / 2);
    final pokeballPositionY = screenHeight / 2 - (pokeballSize / 2);

    final pokeballSpinAngle = _spinController.value * 4 * math.pi; // Multiplicador para mais giros

    // Use IgnorePointer para prevenir interações com a UI por baixo durante a transição
    return IgnorePointer(
      // Ignora toques se não for apenas abertura OU se alguma animação estiver ativa
      ignoring: widget.phase != TransitionPhase.opening || _curtainController.isAnimating || _spinController.isAnimating,
      child: Stack(
        children: [
           // Camada semi-transparente (opcional, pode remover se não gostar)
           // Container(color: Colors.black.withOpacity(curtainProgress * 0.3)),

           Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: leftCurtainWidth,
            child: Container(color: Colors.black),
          ),

          Positioned(
            left: rightCurtainLeft,
            top: 0,
            bottom: 0,
            right: 0,
            child: Container(color: Colors.black),
          ),

          // Só mostra a pokebola se as cortinas estiverem se movendo ou fechadas
          if (curtainProgress > 0.01 || _spinController.isAnimating || widget.phase == TransitionPhase.opening)
            Positioned(
              left: pokeballPositionX,
              top: pokeballPositionY,
              child: Transform.rotate(
                angle: pokeballSpinAngle,
                child: _buildPokeball(),
              ),
            ),
        ],
      ),
    );
  }

  // _buildPokeball permanece igual
  Widget _buildPokeball() {
    return Container(
      width: pokeballSize,
      height: pokeballSize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ClipOval(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: 0.5,
                  child: Container(color: Colors.red),
                ),
              ),
            ),
            Container(
              height: 5,
              color: Colors.black,
            ),
            Container(
              width: pokeballSize * 0.3,
              height: pokeballSize * 0.3,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black,
                  width: pokeballSize * 0.05,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 