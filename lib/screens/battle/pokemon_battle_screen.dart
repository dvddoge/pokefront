import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../models/pokemon.dart';
import '../../models/pokemon_move.dart';
import 'components/pokemon_info.dart';
import 'components/move_button.dart';
import 'components/moves_list.dart';
import 'components/battle_log.dart';
import 'components/battle_background.dart';
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

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPokemonData();
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

  @override
  void dispose() {
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
    try {
      pokemon1Moves = await PokemonMoveService.fetchPokemonMoves(widget.pokemon1.id);
      pokemon2Moves = await PokemonMoveService.fetchPokemonMoves(widget.pokemon2.id);

      // Carrega dados do Pokémon 1
      final response1 = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon1.id}'),
      );
      
      if (response1.statusCode == 200) {
        final data1 = json.decode(response1.body);
        final stats1 = data1['stats'] as List;
        pokemon1MaxHP = (stats1.firstWhere((stat) => stat['stat']['name'] == 'hp')['base_stat'] as int).toDouble();
        pokemon1HP = pokemon1MaxHP;
      }

      // Carrega dados do Pokémon 2
      final response2 = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon2.id}'),
      );
      
      if (response2.statusCode == 200) {
        final data2 = json.decode(response2.body);
        final stats2 = data2['stats'] as List;
        pokemon2MaxHP = (stats2.firstWhere((stat) => stat['stat']['name'] == 'hp')['base_stat'] as int).toDouble();
        pokemon2HP = pokemon2MaxHP;
      }

      setState(() => isLoading = false);
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        pokemon1MaxHP = 100;
        pokemon2MaxHP = 100;
        pokemon1HP = 100;
        pokemon2HP = 100;
        pokemon1Moves = PokemonMoveService.getDefaultMoves();
        pokemon2Moves = PokemonMoveService.getDefaultMoves();
        isLoading = false;
      });
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
    await _attackAnimationController.forward();
    await _attackAnimationController.reverse();

    // Flash de ataque
    _flashAnimationController.forward();
    await Future.delayed(Duration(milliseconds: 50));
    await _flashAnimationController.reverse();

    // Animação de dano no oponente
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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Batalha Finalizada!'),
        content: Text('${pokemon1HP <= 0 ? widget.pokemon2.name : widget.pokemon1.name} é o vencedor!'),
        actions: [
          TextButton(
            onPressed: () {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
              ),
              SizedBox(height: 16),
              Text(
                'Carregando habilidades...',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Batalha Pokémon'),
        backgroundColor: Colors.red[900],
      ),
      body: Stack(
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
