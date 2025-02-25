import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../models/pokemon.dart';
import '../../models/pokemon_move.dart';
import '../../services/audio_service.dart';
import 'components/pokemon_info.dart';
import 'components/move_button.dart';
import 'components/moves_list.dart';
import 'components/battle_log.dart';
import 'components/battle_background.dart';
import 'components/battle_transition.dart';
import 'services/battle_service.dart';
import 'services/pokemon_move_service.dart';
import 'utils/animation_utils.dart';

class PokemonBattleScreen extends StatefulWidget {
  final Pokemon pokemon1;
  final Pokemon pokemon2;

  const PokemonBattleScreen({
    Key? key,
    required this.pokemon1,
    required this.pokemon2,
  }) : super(key: key);

  @override
  _PokemonBattleScreenState createState() => _PokemonBattleScreenState();
}

class _PokemonBattleScreenState extends State<PokemonBattleScreen> with TickerProviderStateMixin {
  final AudioService _audioService = AudioService();
  late AnimationController _battleAnimationController;
  late AnimationController _shakeAnimationController;
  late AnimationController _damageAnimationController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _floatingAnimationController;
  late AnimationController _flashAnimationController;
  late AnimationController _attackAnimationController;
  late Animation<Offset> _attackAnimation;
  late Animation<double> _backgroundAnimation;
  late Animation<double> _floatingAnimation;
  
  late double pokemon1MaxHP;
  late double pokemon2MaxHP;
  late double pokemon1HP;
  late double pokemon2HP;
  String battleLog = '';
  bool isPlayer1Turn = true;
  bool isAnimating = false;
  bool isLoading = true;
  List<PokemonMove> pokemon1Moves = [];
  List<PokemonMove> pokemon2Moves = [];
  bool _showTransition = true;
  bool _battleScreenReady = false;

  @override
  void initState() {
    super.initState();
    
    try {
      print('Inicializando tela de batalha');
      _setupAnimations();
      
      // Inicializa valores padrão para evitar erros
      pokemon1MaxHP = 100;
      pokemon2MaxHP = 100;
      pokemon1HP = 100;
      pokemon2HP = 100;
      
      // Inicializa com movimentos padrão para garantir que sempre haja algo para mostrar
      pokemon1Moves = PokemonMoveService.getDefaultMoves();
      pokemon2Moves = PokemonMoveService.getDefaultMoves();
      
      // Carrega os dados imediatamente para garantir que estejam disponíveis
      // quando a animação de transição terminar
      _loadPokemonData();
    } catch (e) {
      print('Erro ao inicializar tela de batalha: $e');
    }
  }

  void _setupAnimations() {
    _battleAnimationController = AnimationUtils.createBattleController(this);
    _shakeAnimationController = AnimationUtils.createShakeController(this);
    _damageAnimationController = AnimationUtils.createDamageController(this);
    _attackAnimationController = AnimationUtils.createAttackController(this);
    _backgroundAnimationController = AnimationUtils.createBackgroundController(this);
    _floatingAnimationController = AnimationUtils.createFloatingController(this);
    _flashAnimationController = AnimationUtils.createFlashController(this);

    _attackAnimation = AnimationUtils.createAttackAnimation(_attackAnimationController);
    _backgroundAnimation = AnimationUtils.createBackgroundAnimation(_backgroundAnimationController);
    _floatingAnimation = AnimationUtils.createFloatingAnimation(_floatingAnimationController);
  }

  Future<void> _startBattleMusic() async {
    try {
      // No ambiente web, os arquivos .ogg podem não ser suportados
      // Vamos apenas registrar que tentamos tocar a música, sem gerar erros
      print('Tentando iniciar música de batalha (desativado para web)');
      
      // Em um ambiente real, você precisaria converter os arquivos para MP3 ou outro formato compatível
      // await _audioService.playMusic('assets/sounds/music/wild-battle.mp3');
    } catch (e) {
      print('Erro ao tocar música de batalha: $e');
    }
  }

  @override
  void dispose() {
    _audioService.stopMusic();
    _attackAnimationController.dispose();
    _battleAnimationController.dispose();
    _shakeAnimationController.dispose();
    _damageAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _floatingAnimationController.dispose();
    _flashAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPokemonData() async {
    if (!mounted) return;
    
    print('Carregando dados dos Pokémon');
    
    try {
      // Carrega os movimentos dos Pokémon
      List<PokemonMove> moves1 = [];
      List<PokemonMove> moves2 = [];
      double hp1 = 100;
      double hp2 = 100;
      
      try {
        print('Tentando carregar movimentos para o Pokémon 1 (ID: ${widget.pokemon1.id})');
        moves1 = await PokemonMoveService.fetchPokemonMoves(widget.pokemon1.id);
        print('Movimentos do Pokémon 1 carregados: ${moves1.length}');
        for (var move in moves1) {
          print('Movimento: ${move.name}, Dano: ${move.damage}, Tipo: ${move.type}, Precisão: ${move.accuracy}');
        }
      } catch (e) {
        print('Erro ao carregar movimentos do Pokémon 1: $e');
        print('Usando movimentos padrão para o Pokémon 1');
        moves1 = PokemonMoveService.getDefaultMoves();
      }
      
      try {
        print('Tentando carregar movimentos para o Pokémon 2 (ID: ${widget.pokemon2.id})');
        moves2 = await PokemonMoveService.fetchPokemonMoves(widget.pokemon2.id);
        print('Movimentos do Pokémon 2 carregados: ${moves2.length}');
        for (var move in moves2) {
          print('Movimento: ${move.name}, Dano: ${move.damage}, Tipo: ${move.type}, Precisão: ${move.accuracy}');
        }
      } catch (e) {
        print('Erro ao carregar movimentos do Pokémon 2: $e');
        print('Usando movimentos padrão para o Pokémon 2');
        moves2 = PokemonMoveService.getDefaultMoves();
      }
      
      // Carrega os dados dos Pokémon
      try {
        print('Tentando carregar dados do Pokémon 1 (ID: ${widget.pokemon1.id})');
        final response1 = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon1.id}'),
        );
        
        if (response1.statusCode == 200) {
          final data1 = json.decode(response1.body);
          final stats1 = data1['stats'] as List;
          final hpStat = stats1.firstWhere(
            (stat) => stat['stat']['name'] == 'hp',
            orElse: () => {'base_stat': 100},
          );
          hp1 = (hpStat['base_stat'] as int).toDouble();
          print('HP do Pokémon 1 carregado: $hp1');
        } else {
          print('Erro na resposta da API para Pokémon 1: ${response1.statusCode}');
        }
      } catch (e) {
        print('Erro ao carregar dados do Pokémon 1: $e');
      }
      
      try {
        print('Tentando carregar dados do Pokémon 2 (ID: ${widget.pokemon2.id})');
        final response2 = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon2.id}'),
        );
        
        if (response2.statusCode == 200) {
          final data2 = json.decode(response2.body);
          final stats2 = data2['stats'] as List;
          final hpStat = stats2.firstWhere(
            (stat) => stat['stat']['name'] == 'hp',
            orElse: () => {'base_stat': 100},
          );
          hp2 = (hpStat['base_stat'] as int).toDouble();
          print('HP do Pokémon 2 carregado: $hp2');
        } else {
          print('Erro na resposta da API para Pokémon 2: ${response2.statusCode}');
        }
      } catch (e) {
        print('Erro ao carregar dados do Pokémon 2: $e');
      }

      // Verifica se os movimentos foram carregados corretamente
      if (moves1.isEmpty) {
        print('ALERTA: Lista de movimentos do Pokémon 1 está vazia! Usando movimentos padrão.');
        moves1 = PokemonMoveService.getDefaultMoves();
      }
      
      if (moves2.isEmpty) {
        print('ALERTA: Lista de movimentos do Pokémon 2 está vazia! Usando movimentos padrão.');
        moves2 = PokemonMoveService.getDefaultMoves();
      }

      // Atualiza o estado com os dados carregados ou valores padrão
      if (mounted) {
        setState(() {
          pokemon1Moves = moves1;
          pokemon2Moves = moves2;
          pokemon1MaxHP = hp1;
          pokemon2MaxHP = hp2;
          pokemon1HP = pokemon1MaxHP;
          pokemon2HP = pokemon2MaxHP;
          isLoading = false;
          _battleScreenReady = true;
          battleLog = 'Um ${widget.pokemon2.name} selvagem apareceu!';
        });
        print('Dados carregados com sucesso. Tela de batalha pronta.');
        print('Pokémon 1 (${widget.pokemon1.name}) - Movimentos: ${pokemon1Moves.length}, HP: $pokemon1HP/$pokemon1MaxHP');
        print('Pokémon 2 (${widget.pokemon2.name}) - Movimentos: ${pokemon2Moves.length}, HP: $pokemon2HP/$pokemon2MaxHP');
      }
    } catch (e) {
      print('Erro geral ao carregar dados: $e');
      if (mounted) {
        setState(() {
          pokemon1MaxHP = 100;
          pokemon2MaxHP = 100;
          pokemon1HP = 100;
          pokemon2HP = 100;
          pokemon1Moves = PokemonMoveService.getDefaultMoves();
          pokemon2Moves = PokemonMoveService.getDefaultMoves();
          isLoading = false;
          _battleScreenReady = true;
          battleLog = 'Um ${widget.pokemon2.name} selvagem apareceu!';
        });
        print('Usando valores padrão devido a erros.');
      }
    }
  }

  Future<void> _executeMove(PokemonMove move) async {
    if (isAnimating) return;

    setState(() {
      isAnimating = true;
      battleLog = '${isPlayer1Turn ? widget.pokemon1.name : widget.pokemon2.name} usa ${move.name}!';
    });

    bool hitSuccess = BattleService.checkHitSuccess(move.accuracy);

    if (!hitSuccess) {
      try {
        // Desativado para web
        // await _audioService.playSound('assets/sounds/effects/miss.ogg');
        print('Som de erro (desativado para web)');
      } catch (e) {
        print('Erro ao tocar som de erro: $e');
      }
      setState(() {
        battleLog = 'O ataque de ${isPlayer1Turn ? widget.pokemon1.name : widget.pokemon2.name} errou!';
        isAnimating = false;
        isPlayer1Turn = !isPlayer1Turn;
      });
      
      if (!isPlayer1Turn) {
        await Future.delayed(Duration(milliseconds: 1000));
        await _executeAIMove();
      }
      return;
    }

    // Sequência de animação de ataque
    try {
      // Desativado para web
      // await _audioService.playSound('assets/sounds/effects/attack.ogg');
      print('Som de ataque (desativado para web)');
    } catch (e) {
      print('Erro ao tocar som de ataque: $e');
    }
    await _attackAnimationController.forward();
    await _attackAnimationController.reverse();

    // Flash de ataque
    _flashAnimationController.forward();
    await Future.delayed(Duration(milliseconds: 50));
    await _flashAnimationController.reverse();

    // Animação de dano no oponente
    try {
      // Desativado para web
      // await _audioService.playSound('assets/sounds/effects/hit.ogg');
      print('Som de acerto (desativado para web)');
    } catch (e) {
      print('Erro ao tocar som de acerto: $e');
    }
    await _shakeAnimationController.forward();
    await _shakeAnimationController.reverse();

    // Calcula e aplica o dano
    double damage = BattleService.calculateDamage(move);
    setState(() {
      if (isPlayer1Turn) {
        pokemon2HP = math.max(0, pokemon2HP - damage);
        battleLog = '${widget.pokemon1.name} causou ${damage.toInt()} de dano! (${pokemon2HP.toInt()}/${pokemon2MaxHP.toInt()} HP)';
      } else {
        pokemon1HP = math.max(0, pokemon1HP - damage);
        battleLog = '${widget.pokemon2.name} causou ${damage.toInt()} de dano! (${pokemon1HP.toInt()}/${pokemon1MaxHP.toInt()} HP)';
      }
    });

    await _damageAnimationController.forward();
    await _damageAnimationController.reverse();

    // Verifica se a batalha acabou
    if (pokemon1HP <= 0 || pokemon2HP <= 0) {
      try {
        // Desativado para web
        // await _audioService.playSound('assets/sounds/effects/faint.ogg');
        print('Som de derrota (desativado para web)');
      } catch (e) {
        print('Erro ao tocar som de derrota: $e');
      }
      setState(() {
        battleLog = '${pokemon1HP <= 0 ? widget.pokemon2.name : widget.pokemon1.name} venceu a batalha!';
      });
      _showBattleEndDialog();
    } else {
      setState(() {
        isAnimating = false;
        isPlayer1Turn = !isPlayer1Turn;
      });

      if (!isPlayer1Turn) {
        await Future.delayed(Duration(milliseconds: 1000));
        await _executeAIMove();
      }
    }
  }

  Future<void> _executeAIMove() async {
    if (pokemon1HP <= 0 || pokemon2HP <= 0) return;

    final selectedMove = BattleService.selectAIMove(
      pokemon2Moves,
      pokemon2HP,
      pokemon1HP,
      pokemon2MaxHP,
    );

    await _executeMove(selectedMove);
  }

  void _showBattleEndDialog() {
    _audioService.stopMusic();
    try {
      // Desativado para web
      // _audioService.playMusic('assets/sounds/music/victory.ogg');
      print('Música de vitória (desativada para web)');
    } catch (e) {
      print('Erro ao tocar música de vitória: $e');
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Batalha Finalizada!'),
        content: Text('${pokemon1HP <= 0 ? widget.pokemon2.name : widget.pokemon1.name} é o vencedor!'),
        actions: [
          TextButton(
            onPressed: () {
              _audioService.stopMusic();
              Navigator.of(context).pop(); // Fecha o diálogo
              Navigator.of(context).pop(); // Volta para a tela anterior
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPokemonImage(
    Pokemon pokemon,
    bool isPlayer1,
    Animation<double> floatingAnimation,
    Animation<Offset> attackAnimation,
  ) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _shakeAnimationController,
        floatingAnimation,
        _attackAnimationController
      ]),
      builder: (context, child) {
        Offset finalOffset = Offset.zero;
        
        if ((isPlayer1 && isPlayer1Turn) || (!isPlayer1 && !isPlayer1Turn)) {
          finalOffset += attackAnimation.value;
        }
        
        if ((isPlayer1 && !isPlayer1Turn) || (!isPlayer1 && isPlayer1Turn)) {
          finalOffset += Offset(
            math.sin(_shakeAnimationController.value * math.pi * 8) * 5,
            0,
          );
        }
        
        finalOffset += Offset(
          math.sin(floatingAnimation.value * 2 * math.pi + (isPlayer1 ? math.pi : 0)) * 5,
          math.cos(floatingAnimation.value * 2 * math.pi + (isPlayer1 ? math.pi : 0)) * 8,
        );

        return Transform.translate(
          offset: finalOffset,
          child: Transform.rotate(
            angle: math.sin(floatingAnimation.value * 2 * math.pi + (isPlayer1 ? math.pi : 0)) * 0.05,
            child: child,
          ),
        );
      },
      child: CachedNetworkImage(
        imageUrl: pokemon.imageUrl,
        height: 200,
      ),
    );
  }

  // Chamado quando a animação de transição está na fase de cortinas fechadas
  void _onTransitionMidpoint() {
    if (!mounted) return;
    
    try {
      print('Ponto médio da transição atingido');
      // Quando chegamos ao meio da animação (cortinas fechadas),
      // verificamos se os dados já foram carregados
      if (isLoading) {
        print('Dados ainda não carregados no ponto médio da transição');
        // Se ainda estiver carregando, atualizamos o estado para mostrar que estamos prontos
        // quando os dados terminarem de carregar
        setState(() {
          _battleScreenReady = true;
        });
      } else {
        print('Dados já carregados, tela de batalha pronta');
        setState(() {
          _battleScreenReady = true;
        });
      }
    } catch (e) {
      print('Erro no callback de ponto médio: $e');
      // Em caso de erro, ainda tentamos marcar a tela como pronta
      if (mounted) {
        setState(() => _battleScreenReady = true);
      }
    }
  }

  // Chamado quando a animação de transição está completa
  void _onTransitionComplete() {
    if (!mounted) return;
    
    try {
      print('Animação de transição completa');
      // Quando a animação termina, mostramos a tela de batalha e iniciamos a música
      setState(() {
        _showTransition = false;
        if (isLoading) {
          battleLog = 'Carregando dados do Pokémon...';
        }
      });
      // Não iniciamos a música no ambiente web para evitar erros
      // _startBattleMusic();
    } catch (e) {
      print('Erro no callback de conclusão da transição: $e');
      // Em caso de erro, ainda tentamos mostrar a tela de batalha
      if (mounted) {
        setState(() => _showTransition = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Garante que a música seja parada ao sair da tela
        _audioService.stopMusic();
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[100],
        appBar: AppBar(
          title: Text('Batalha Pokémon'),
          backgroundColor: Colors.red[900],
        ),
        body: Stack(
          children: [
            // Conteúdo da batalha (oculto enquanto a transição está ativa)
            if (!_showTransition) Stack(
              children: [
                // Fundo animado com vermelho mais intenso
                AnimatedBuilder(
                  animation: _backgroundAnimation,
                  builder: (context, child) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.red[900]!.withOpacity(0.95),
                            Colors.red[800]!.withOpacity(0.9),
                            Colors.red[700]!.withOpacity(0.85),
                          ],
                        ),
                      ),
                      child: CustomPaint(
                        painter: BattleBackgroundPainter(
                          animation: _backgroundAnimation.value,
                        ),
                        size: Size.infinite,
                      ),
                    );
                  },
                ),

                Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // Flash de ataque
                          AnimatedBuilder(
                            animation: _flashAnimationController,
                            builder: (context, child) {
                              return Container(
                                color: Colors.white.withOpacity(_flashAnimationController.value * 0.3),
                              );
                            },
                          ),

                          // Informações dos Pokémon
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    PokemonInfo(
                                      pokemon: widget.pokemon2,
                                      hp: pokemon2HP,
                                      maxHp: pokemon2MaxHP,
                                      isLeft: false,
                                    ),
                                  ],
                                ),
                                Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    PokemonInfo(
                                      pokemon: widget.pokemon1,
                                      hp: pokemon1HP,
                                      maxHp: pokemon1MaxHP,
                                      isLeft: true,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Pokémon 2 (Oponente)
                          Positioned(
                            right: 30,
                            top: 120,
                            child: _buildPokemonImage(
                              widget.pokemon2,
                              false,
                              _floatingAnimation,
                              _attackAnimation,
                            ),
                          ),

                          // Pokémon 1 (Jogador)
                          Positioned(
                            left: 30,
                            bottom: 80,
                            child: _buildPokemonImage(
                              widget.pokemon1,
                              true,
                              _floatingAnimation,
                              _attackAnimation,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Log de batalha
                    Container(
                      padding: EdgeInsets.all(8),
                      color: Colors.white,
                      width: double.infinity,
                      child: Text(
                        battleLog,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Movimentos
                    if (isPlayer1Turn) Container(
                      width: MediaQuery.of(context).size.width,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            margin: EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.red[700],
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.shade900.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'ESCOLHA SEU MOVIMENTO',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1,
                                fontFamily: 'Roboto',
                              ),
                            ),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.center,
                              children: pokemon1Moves.map((move) => MoveButton(
                                move: move,
                                isDisabled: isAnimating,
                                onMoveSelected: _executeMove,
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Animação de transição (sempre visível no início)
            if (_showTransition)
              BattleTransition(
                onTransitionComplete: _onTransitionComplete,
                onMidpoint: _onTransitionMidpoint,
                waitForBattleScreen: false, // Não esperamos pela tela de batalha, a animação roda completa
              ),
          ],
        ),
      ),
    );
  }
}

class BattleBackgroundPainter extends CustomPainter {
  final double animation;

  BattleBackgroundPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    // Desenha círculos concêntricos com branco forte
    for (int i = 0; i < 5; i++) {
      paint.color = Colors.white.withOpacity(0.5 - (i * 0.05));
      final radius = 120.0 + (i * 60.0) + (math.sin(animation * 2 * math.pi) * 10);
      canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.5),
        radius,
        paint,
      );
    }

    // Desenha linhas diagonais
    paint.color = Colors.white.withOpacity(0.15);
    paint.strokeWidth = 1.5;
    for (int i = 0; i < 12; i++) {
      final spacing = 120.0;
      final startX = -size.width + (i * spacing) + (animation * spacing);
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BattleBackgroundPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
