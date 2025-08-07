import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../widgets/pokemon_net_image.dart';
import 'dart:math' as math;
import '../../../models/opponent.dart';
import '../../../models/pokemon.dart';
import '../../../models/tournament_progress.dart';

class TournamentBracket extends StatefulWidget {
  final List<Opponent> opponents;
  final Pokemon playerPokemon;
  final TournamentProgress progress;
  final VoidCallback? onPlayerTap;
  final Function(Opponent)? onOpponentTap;
  final bool isBattling;

  const TournamentBracket({
    Key? key,
    required this.opponents,
    required this.playerPokemon,
    required this.progress,
    this.onPlayerTap,
    this.onOpponentTap,
    this.isBattling = false,
  }) : super(key: key);

  @override
  _TournamentBracketState createState() => _TournamentBracketState();
}

class _TournamentBracketState extends State<TournamentBracket>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late List<AnimationController> _nodeAnimationControllers;
  late AnimationController _pulseController;
  late AnimationController _confirmationController;
  late ScrollController _scrollController;
  
  Opponent? _selectedOpponent;
  bool _showConfirmation = false;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    
    _selectedOpponent = null;
    _showConfirmation = false;
    _overlayEntry = null;
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _confirmationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scrollController = ScrollController();

    _nodeAnimationControllers = List.generate(
      widget.opponents.length + 1,
      (index) => AnimationController(
        duration: Duration(milliseconds: 500 + (index * 100)),
        vsync: this,
      ),
    );

    _startAnimations();
  }

  void _startAnimations() {
    if (mounted) {
      _animationController.forward();
      for (int i = 0; i < _nodeAnimationControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 200), () {
          if (mounted) {
            _nodeAnimationControllers[i].forward();
          }
        });
      }
    }
  }

  void forceReset() {
    _cleanupState();
    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _startAnimations();
      }
    });
  }

  @override
  void didUpdateWidget(TournamentBracket oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Apenas limpa seleção se houve mudança significativa
    if (oldWidget.progress.currentOpponentIndex != widget.progress.currentOpponentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _selectedOpponent = null;
          _showConfirmation = false;
          if (_pulseController.isAnimating) {
            _pulseController.stop();
            _pulseController.reset();
          }
          _hideGlobalConfirmationBar();
        }
      });
    }
  }

  void _onOpponentSelected(Opponent opponent, int index) {
    if (_selectedOpponent == opponent) return;
    
    _selectedOpponent = opponent;
    _showConfirmation = false;
    
    // Para animação anterior
    if (_pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }
    
    // Centralizar o card selecionado
    _centerOpponentCard(index);
    
    // Inicia pulsação
    _pulseController.repeat();
    
    // Mostrar confirmação após um delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _selectedOpponent == opponent) {
        _showGlobalConfirmationBar();
      }
    });
    
    // Força rebuild para mostrar mudanças
    if (mounted) {
      setState(() {});
    }
  }

  void _centerOpponentCard(int opponentIndex) {
    final bracketWidth = math.max(1000.0, MediaQuery.of(context).size.width);
    final totalSteps = widget.opponents.length + 1;
    final stepWidth = (bracketWidth - 200) / totalSteps;
    final opponentX = 100 + ((opponentIndex + 1) * stepWidth);
    final screenWidth = MediaQuery.of(context).size.width;
    final targetScrollPosition = opponentX - (screenWidth / 2);
    
    _scrollController.animateTo(
      math.max(0, targetScrollPosition),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _confirmBattle() {
    if (_selectedOpponent != null && widget.onOpponentTap != null) {
      final selectedOpponent = _selectedOpponent!;
      
      // Para animações de forma segura
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.reset();
      
      _confirmationController.reverse();
      _hideGlobalConfirmationBar();
      
      setState(() {
        _showConfirmation = false;
        _selectedOpponent = null;
      });
      
      widget.onOpponentTap!(selectedOpponent);
    }
  }

  void _cancelSelection() {
    // Para animações de forma segura
    if (_pulseController.isAnimating) {
      _pulseController.stop();
    }
    _pulseController.reset();
    
    _confirmationController.reverse();
    _hideGlobalConfirmationBar();
    
    setState(() {
      _showConfirmation = false;
      _selectedOpponent = null;
    });
  }

  void _showGlobalConfirmationBar() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: AnimatedBuilder(
          animation: _confirmationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, (1 - _confirmationController.value) * 150),
              child: Opacity(
                opacity: _confirmationController.value,
                child: _buildGlobalConfirmationBar(),
              ),
            );
          },
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
    _confirmationController.forward();
  }

  void _hideGlobalConfirmationBar() {
    try {
      if (_overlayEntry != null) {
        _overlayEntry!.remove();
        _overlayEntry = null;
      }
    } catch (e) {
      // Ignore erro se overlay já foi removido
      _overlayEntry = null;
    }
  }

  void _cleanupState() {
    // Para e reseta todas as animações de forma completa
    try {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
      }
      _pulseController.reset();
      
      if (_confirmationController.isAnimating) {
        _confirmationController.stop();
      }
      _confirmationController.reset();
      
      // Para animações dos nós sem resetar a animação principal
      for (final controller in _nodeAnimationControllers) {
        if (controller.isAnimating) {
          controller.stop();
        }
      }
    } catch (e) {
      // Ignora erros de controllers já dispostos
    }
    
    // Remove overlay se existir
    _hideGlobalConfirmationBar();
    
    // Reset do estado sem setState se possível
    final needsUpdate = _selectedOpponent != null || _showConfirmation;
    _selectedOpponent = null;
    _showConfirmation = false;
    
    // Só chama setState se realmente precisar e estiver montado
    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _cleanupState();
    _animationController.dispose();
    _pulseController.dispose();
    _confirmationController.dispose();
    _scrollController.dispose();
    for (final controller in _nodeAnimationControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bracketWidth = math.max(1000.0, MediaQuery.of(context).size.width);
    final bracketHeight = 400.0;
    
    return Stack(
      children: [
        // Timeline principal expandida para quebrar padding externo
        Transform.translate(
          offset: const Offset(-16, 0), // Compensa o padding horizontal do pai
          child: Container(
            width: MediaQuery.of(context).size.width + 32, // +32 para compensar -16 de cada lado
            height: bracketHeight,
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              child: Container(
                width: bracketWidth + 32, // Ajusta a largura do conteúdo
                height: bracketHeight,
                padding: const EdgeInsets.fromLTRB(32, 16, 16, 16), // Padding ajustado
                child: AnimatedBuilder(
                  animation: Listenable.merge([_animationController, _pulseController]),
                  builder: (context, child) {
                    return CustomPaint(
                      painter: BracketPainter(
                        progress: widget.progress,
                        opponents: widget.opponents,
                        animationValue: _animationController.value,
                        bracketWidth: bracketWidth,
                        selectedOpponent: _selectedOpponent,
                        pulseValue: _selectedOpponent != null ? _pulseController.value : 0.0,
                      ),
                      child: Stack(
                        children: [
                          // Jogador (lado esquerdo)
                          Positioned(
                            left: 20,
                            top: bracketHeight / 2 - 150,
                            child: _buildPlayerNode(),
                          ),
                          
                          // Oponentes distribuídos ao longo da timeline
                          ...widget.opponents.asMap().entries.map((entry) {
                            final index = entry.key;
                            final opponent = entry.value;
                            final isDefeated = index < widget.progress.currentOpponentIndex;
                            final isCurrent = index == widget.progress.currentOpponentIndex && !widget.progress.isCompleted;
                            final isSelected = _selectedOpponent == opponent;
                            
                            final totalSteps = widget.opponents.length + 1;
                            final stepWidth = (bracketWidth - 200) / totalSteps;
                            final opponentX = 100 + ((index + 1) * stepWidth) - 60;
                            
                            return Positioned(
                              left: opponentX,
                              top: (bracketHeight / 2 - 150) - (isSelected ? 30 : 0),
                              child: _buildOpponentNode(opponent, isDefeated, isCurrent, isSelected, index),
                            );
                          }).toList(),
                          
                          // Centro - Troféu final
                          Positioned(
                            right: 20,
                            top: bracketHeight / 2 - 110,
                            child: _buildTrophyNode(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerNode() {
    return AnimatedBuilder(
      animation: _nodeAnimationControllers[0],
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + (_nodeAnimationControllers[0].value * 0.7),
          child: Opacity(
            opacity: _nodeAnimationControllers[0].value,
            child: GestureDetector(
              onTap: widget.onPlayerTap,
              child: Container(
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blue[700]!, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PokemonNetImage(
                      imageUrl: widget.playerPokemon.imageUrl,
                      pokemonId: widget.playerPokemon.id,
                      height: 45,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'VOCÊ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOpponentNode(Opponent opponent, bool isDefeated, bool isCurrent, bool isSelected, int index) {
    Color borderColor = Colors.grey[400]!;
    Color backgroundColor = Colors.grey[100]!;
    double cardScale = 1.0;
    
    if (isDefeated) {
      borderColor = Colors.green[700]!;
      backgroundColor = Colors.green[50]!;
    } else if (isCurrent || isSelected) {
      borderColor = Colors.amber[700]!;
      backgroundColor = Colors.amber[50]!;
      cardScale = isSelected ? 1.3 : 1.0;
    }

    return AnimatedBuilder(
      animation: _nodeAnimationControllers[index + 1],
      builder: (context, child) {
        return Transform.scale(
          scale: (0.5 + (_nodeAnimationControllers[index + 1].value * 0.7)) * cardScale,
          child: Opacity(
            opacity: _nodeAnimationControllers[index + 1].value,
            child: GestureDetector(
              onTap: isCurrent && !widget.isBattling
                  ? () => _onOpponentSelected(opponent, index)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                width: 120,
                height: 100,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withOpacity(0.4),
                      blurRadius: isSelected ? 20 : 12,
                      spreadRadius: isSelected ? 4 : 0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: CachedNetworkImageProvider(opponent.avatarUrl),
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      opponent.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (isDefeated)
                      Icon(
                        Icons.check_circle,
                        color: Colors.green[600],
                        size: 16,
                      )
                    else if (isCurrent && !widget.isBattling && !isSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber[700],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'LUTAR',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      )
                    else if (isCurrent && widget.isBattling)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[700]!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrophyNode() {
    final isCompleted = widget.progress.isCompleted;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: isCompleted 
              ? 1.2 + (0.1 * math.sin(_animationController.value * math.pi * 2))
              : 0.5 + (_animationController.value * 0.7),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            width: 120,
            height: 100,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.amber[50] : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCompleted ? Colors.amber[700]! : Colors.grey[400]!,
                width: 3,
              ),
              boxShadow: isCompleted
                  ? [
                      BoxShadow(
                        color: Colors.amber[300]!.withOpacity(0.6),
                        blurRadius: 20,
                        spreadRadius: 6,
                      ),
                      BoxShadow(
                        color: Colors.amber[600]!.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 3,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.grey[300]!.withOpacity(0.5),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.emoji_events,
                  color: isCompleted ? Colors.amber[700] : Colors.grey[400],
                  size: 45,
                ),
                const SizedBox(height: 8),
                Text(
                  'VITÓRIA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCompleted ? Colors.amber[700] : Colors.grey[400],
                  ),
                ),
                if (isCompleted)
                  Icon(
                    Icons.star,
                    color: Colors.amber[300],
                    size: 16,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirmationBar() {
    if (_selectedOpponent == null) return const SizedBox.shrink();
    
    return Container(
      width: MediaQuery.of(context).size.width,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber[600]!, Colors.amber[800]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.amber[300]!.withOpacity(0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: CachedNetworkImageProvider(_selectedOpponent!.avatarUrl),
                backgroundColor: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lutar contra',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _selectedOpponent!.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _cancelSelection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.white.withOpacity(0.5)),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _confirmBattle,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.amber[800],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.flash_on, size: 20),
                      const SizedBox(width: 4),
                      const Text(
                        'INICIAR BATALHA',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalConfirmationBar() {
    if (_selectedOpponent == null) return const SizedBox.shrink();
    
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber[600]!, Colors.amber[800]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: CachedNetworkImageProvider(_selectedOpponent!.avatarUrl),
                    backgroundColor: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lutar contra',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _selectedOpponent!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _cancelSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _confirmBattle,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.amber[800],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.flash_on, size: 20),
                          const SizedBox(width: 4),
                          const Text(
                            'INICIAR BATALHA',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BracketPainter extends CustomPainter {
  final TournamentProgress progress;
  final List<Opponent> opponents;
  final double animationValue;
  final double bracketWidth;
  final Opponent? selectedOpponent;
  final double pulseValue;

  BracketPainter({
    required this.progress,
    required this.opponents,
    required this.animationValue,
    required this.bracketWidth,
    this.selectedOpponent,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final timelineY = size.height / 2;
    final startX = 100.0;
    final endX = bracketWidth - 100.0;
    final timelineLength = endX - startX;
    
    final totalSteps = opponents.length + 1;
    final stepWidth = timelineLength / totalSteps;
    final playerX = startX;
    final trophyX = endX;
    
    // 1. CAMADA DE FUNDO: Linha base da timeline
    paint.color = Colors.grey[300]!;
    paint.strokeWidth = 8;
    canvas.drawLine(
      Offset(startX, timelineY),
      Offset(endX, timelineY),
      paint,
    );

    // 2. CAMADA INTERMEDIÁRIA: Linhas de progresso (atrás dos círculos)
    for (int i = 0; i < opponents.length; i++) {
      final opponentX = startX + ((i + 1) * stepWidth);
      final isDefeated = i < progress.currentOpponentIndex;
      final isCurrent = i == progress.currentOpponentIndex && !progress.isCompleted;
      
      if (isDefeated || isCurrent) {
        final progressPaint = Paint()
          ..color = isDefeated ? Colors.green[600]! : Colors.amber[700]!
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round;
        
        final progressStart = i == 0 ? playerX : startX + (i * stepWidth);
        canvas.drawLine(
          Offset(progressStart, timelineY),
          Offset(opponentX, timelineY),
          progressPaint,
        );
      }
    }
    
    // Linha final de progresso (se completado)
    if (progress.isCompleted) {
      final finalProgressPaint = Paint()
        ..color = Colors.amber[700]!
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(startX + (opponents.length * stepWidth), timelineY),
        Offset(trophyX, timelineY),
        finalProgressPaint,
      );
    }

    // 3. CAMADA DA FRENTE: Círculos dos marcos (na frente das linhas)
    // Marco inicial (jogador)
    _drawTimelineMilestone(
      canvas, 
      Offset(playerX, timelineY), 
      Colors.blue[700]!, 
      Icons.person, 
      "INÍCIO",
      true
    );

    // Marcos dos oponentes
    for (int i = 0; i < opponents.length; i++) {
      final opponentX = startX + ((i + 1) * stepWidth);
      final isDefeated = i < progress.currentOpponentIndex;
      final isCurrent = i == progress.currentOpponentIndex && !progress.isCompleted;
      final isSelected = selectedOpponent == opponents[i];
      
      Color milestoneColor = Colors.grey[400]!;
      IconData milestoneIcon = Icons.sports_kabaddi;
      bool isActive = false;
      
      if (isDefeated) {
        milestoneColor = Colors.green[600]!;
        milestoneIcon = Icons.check_circle;
        isActive = true;
      } else if (isCurrent || isSelected) {
        milestoneColor = Colors.amber[700]!;
        milestoneIcon = Icons.flash_on;
        isActive = true;
      }
      
      _drawTimelineMilestone(
        canvas, 
        Offset(opponentX, timelineY), 
        milestoneColor, 
        milestoneIcon, 
        "ROUND ${i + 1}",
        isActive,
        isSelected: isSelected,
      );
    }

    // Marco final (troféu)
    _drawTimelineMilestone(
      canvas, 
      Offset(trophyX, timelineY), 
      progress.isCompleted ? Colors.amber[700]! : Colors.grey[400]!, 
      Icons.emoji_events, 
      "VITÓRIA",
      progress.isCompleted
    );

    // 4. CAMADA DE EFEITOS: Partículas e brilhos (por cima de tudo)
    _drawTimelineEffects(canvas, size, timelineY, animationValue);
  }

  void _drawTimelineMilestone(
    Canvas canvas, 
    Offset position, 
    Color color, 
    IconData icon, 
    String label,
    bool isActive,
    {bool isSelected = false}
  ) {
    final paint = Paint()..color = color;
    
    final radius = isActive ? 28.0 : 20.0;
    canvas.drawCircle(position, radius, paint);
    
    final innerPaint = Paint()..color = Colors.white;
    canvas.drawCircle(position, radius - 4, innerPaint);
    
    // Efeito de pulsação para o selecionado
    if (isSelected && selectedOpponent != null) {
      final pulsePaint = Paint()
        ..color = color.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      
      // Usa pulseValue apenas se for válido (entre 0 e 1)
      final normalizedPulseValue = pulseValue.clamp(0.0, 1.0);
      final pulseRadius = radius + 8 + (8 * math.sin(normalizedPulseValue * math.pi * 2));
      canvas.drawCircle(position, pulseRadius, pulsePaint);
      
      final innerPulsePaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawCircle(position, pulseRadius + 6, innerPulsePaint);
    }
    
    final iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontFamily: icon.fontFamily,
          fontSize: isActive ? 24 : 20,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    iconPainter.paint(
      canvas,
      Offset(
        position.dx - iconPainter.width / 2,
        position.dy - iconPainter.height / 2,
      ),
    );
    
    final labelPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    labelPainter.layout();
    labelPainter.paint(
      canvas,
      Offset(
        position.dx - labelPainter.width / 2,
        position.dy + 40,
      ),
    );
  }

  void _drawTimelineEffects(Canvas canvas, Size size, double timelineY, double animationValue) {
    final particlePaint = Paint()..color = Colors.amber[300]!.withOpacity(0.6);
    
    for (int i = 0; i < 12; i++) {
      final x = 150 + (i * 80) + (30 * math.sin(animationValue * 2 + i));
      final y = timelineY - 80 + (15 * math.cos(animationValue * 3 + i));
      canvas.drawCircle(Offset(x, y), 4, particlePaint);
    }
    
    if (progress.isCompleted) {
      final glowPaint = Paint()
        ..color = Colors.amber[300]!.withOpacity(0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12;
      
      final trophyX = bracketWidth - 100.0;
      canvas.drawCircle(
        Offset(trophyX, timelineY), 
        45 + (8 * math.sin(animationValue * math.pi * 2)), 
        glowPaint
      );
    }
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.opponents != opponents ||
           oldDelegate.animationValue != animationValue ||
           oldDelegate.selectedOpponent != selectedOpponent ||
           oldDelegate.pulseValue != pulseValue ||
           oldDelegate.bracketWidth != bracketWidth;
  }
} 