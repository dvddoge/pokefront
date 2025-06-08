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
  final bool playOpeningAnimation;

  const PokemonBattleScreen({
    Key? key,
    required this.pokemon1,
    required this.pokemon2,
    this.playOpeningAnimation = true,
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
  
  late Pokemon player1;
  late Pokemon player2;
  String battleLog = '';
  bool isPlayer1Turn = true;
  bool isAnimating = false;
  bool isLoading = true;
  List<PokemonMove> pokemon1Moves = [];
  List<PokemonMove> pokemon2Moves = [];
  bool _showTransition = true;
  bool _battleScreenReady = false;
  late bool _isOpeningTransitionPlaying;

  @override
  void initState() {
    super.initState();
    
    try {
      print('Inicializando tela de batalha');
      _isOpeningTransitionPlaying = widget.playOpeningAnimation;
      _setupAnimations();
      
      // Inicializa com os pokémons passados como widget, serão substituídos pelos dados completos
      player1 = widget.pokemon1;
      player2 = widget.pokemon2;
      
      // Inicializa com movimentos padrão para garantir que sempre haja algo para mostrar
      pokemon1Moves = PokemonMoveService.getDefaultMoves();
      pokemon2Moves = PokemonMoveService.getDefaultMoves();
      
      // Certifica-se de que a transição seja exibida ao iniciar a tela
      setState(() {
        _showTransition = true;
        _battleScreenReady = false;
      });
      
      print('Estado inicial da tela de batalha:');
      print('- _showTransition: $_showTransition');
      print('- _battleScreenReady: $_battleScreenReady');
      
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
      await _audioService.playMusic('sounds/music/assets_audio_music_wild-battle.ogg');
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

  Future<Pokemon> _fetchPokemonDetails(int pokemonId) async {
    final response = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
    );
    if (response.statusCode == 200) {
      return Pokemon.fromDetailJson(json.decode(response.body));
    } else {
      throw Exception('Falha ao carregar detalhes do Pokémon $pokemonId');
    }
  }

  Future<void> _loadPokemonData() async {
    if (!mounted) return;
    
    print('Carregando dados dos Pokémon');
    
    try {
      // Carrega os dados detalhados e os movimentos em paralelo
      final results = await Future.wait([
        _fetchPokemonDetails(widget.pokemon1.id),
        _fetchPokemonDetails(widget.pokemon2.id),
        PokemonMoveService.fetchPokemonMoves(widget.pokemon1.id),
        PokemonMoveService.fetchPokemonMoves(widget.pokemon2.id),
      ]);

      if (mounted) {
        setState(() {
          player1 = results[0] as Pokemon;
          player2 = results[1] as Pokemon;
          pokemon1Moves = results[2] as List<PokemonMove>;
          pokemon2Moves = results[3] as List<PokemonMove>;

          // Garante que as listas de movimentos não estão vazias
          if (pokemon1Moves.isEmpty) {
            pokemon1Moves = PokemonMoveService.getDefaultMoves();
          }
          if (pokemon2Moves.isEmpty) {
            pokemon2Moves = PokemonMoveService.getDefaultMoves();
          }

          isLoading = false;
          _battleScreenReady = true;
          battleLog = 'Um ${player2.name} selvagem apareceu!';
        });
        print('Dados carregados com sucesso. Tela de batalha pronta.');
        print('Jogador 1 (${player1.name}) - Movimentos: ${pokemon1Moves.length}, HP: ${player1.hp}/${player1.maxHp}');
        print('Jogador 2 (${player2.name}) - Movimentos: ${pokemon2Moves.length}, HP: ${player2.hp}/${player2.maxHp}');
      }
    } catch (e) {
      print('Erro ao carregar dados da batalha: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          battleLog = 'Erro ao carregar a batalha. Tente novamente.';
        });
      }
    }
  }

  void _executeMove(PokemonMove move) {
    final attacker = isPlayer1Turn ? player1 : player2;
    final defender = isPlayer1Turn ? player2 : player1;
    
    setState(() {
      battleLog = '${attacker.name} usa ${move.name}!';
      isAnimating = true;
    });

    _attackAnimationController.forward().then((_) async {
      final isHit = BattleService.checkHitSuccess(move.accuracy);
      
      if (isHit) {
        final damage = BattleService.calculateDamage(
          move,
          attacker,
          defender,
        );
        
        if (isPlayer1Turn) {
          final newHP = (player2.hp - damage).clamp(0, player2.maxHp);
          setState(() => player2 = player2.copyWith(hp: newHP.toDouble()));
        } else {
          final newHP = (player1.hp - damage).clamp(0, player1.maxHp);
          setState(() => player1 = player1.copyWith(hp: newHP.toDouble()));
        }

        await _shakeAnimationController.forward();
        _shakeAnimationController.reset();

        setState(() {
          battleLog = BattleService.generateBattleLog(
            attackerName: attacker.name,
            moveName: move.name,
            isHit: true,
            damage: damage,
            remainingHP: (isPlayer1Turn ? player2.hp : player1.hp).toDouble(),
            maxHP: (isPlayer1Turn ? player2.maxHp : player1.maxHp).toDouble(),
          );
        });
      } else {
        setState(() {
          battleLog = 'O ataque de ${attacker.name} errou!';
        });
      }

      if (player1.hp <= 0 || player2.hp <= 0) {
        _handleBattleEnd();
        return;
      }

      setState(() {
        isPlayer1Turn = !isPlayer1Turn;
      });

      if (!isPlayer1Turn) {
        Future.delayed(const Duration(milliseconds: 1500), _aiMakesMove);
      } else {
        setState(() {
          isAnimating = false;
        });
      }
    });
  }

  void _playerMakesMove(PokemonMove move) {
    if (isAnimating) return;
    _executeMove(move);
  }

  void _aiMakesMove() {
    final move = BattleService.selectAIMove(
      pokemon2Moves,
      player2,
      player1,
    );
    _executeMove(move);
  }

  void _handleBattleEnd() {
    setState(() {
      battleLog = '${player1.hp <= 0 ? player2.name : player1.name} venceu!';
      isAnimating = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showBattleEndDialog();
      }
    });
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
        title: const Text('Batalha Finalizada!'),
        content: Text('${player1.hp <= 0 ? player2.name : player1.name} é o vencedor!'),
        actions: [
          TextButton(
            onPressed: () {
              _audioService.stopMusic();
              final isPlayer1Winner = player1.hp > 0;
              Navigator.of(context).pop(); // Fecha o diálogo
              Navigator.of(context).pop(isPlayer1Winner); // Volta para a tela anterior com o resultado
            },
            child: const Text('OK'),
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

  // Callback para quando a transição de ABERTURA terminar
  void _onOpeningTransitionComplete() {
     if (!mounted) return;
     print("Animação de abertura completa.");
     setState(() {
       _isOpeningTransitionPlaying = false; // Esconde a transição
     });
     // Pode iniciar a música de batalha aqui
     _startBattleMusic();
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
          title: const Text('Batalha Pokémon'),
          backgroundColor: Colors.red[900],
        ),
        body: Stack(
          children: [
            // Conteúdo da batalha
            // Renderiza assim que _battleScreenReady for true (após _loadPokemonData)
            if (_battleScreenReady)
              Stack(
                 children: [
                   // Fundo animado
                   BattleBackground(animation: _backgroundAnimation),
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
                               padding: const EdgeInsets.all(16),
                               child: Column(
                                 children: [
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.end,
                                     children: [
                                       PokemonInfo(
                                         pokemon: player2,
                                         hp: player2.hp,
                                         maxHp: player2.maxHp,
                                         isLeft: true,
                                       ),
                                     ],
                                   ),
                                   const Spacer(),
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.start,
                                     children: [
                                       PokemonInfo(
                                         pokemon: player1,
                                         hp: player1.hp,
                                         maxHp: player1.maxHp,
                                         isLeft: false,
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
                                 player2,
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
                                 player1,
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
                          padding: const EdgeInsets.all(8),
                          color: Colors.white,
                          width: double.infinity,
                          child: Text(
                            battleLog,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        // Movimentos (Container já deve estar sem o if isPlayer1Turn)
                        Container(
                          width: MediaQuery.of(context).size.width,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(24),
                              topRight: Radius.circular(24),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  color: Colors.red[700],
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.shade900.withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Text(
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
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  alignment: WrapAlignment.center,
                                  children: pokemon1Moves.map((move) => MoveButton(
                                    move: move,
                                    isDisabled: isAnimating,
                                    onMoveSelected: _playerMakesMove,
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

            // Indicador de Loading
            // Mostra se os dados ainda não carregaram E a transição de abertura não está tocando
            if (!_battleScreenReady && !_isOpeningTransitionPlaying)
               const Center(child: CircularProgressIndicator()),

            // Transição de ABERTURA
            // Mostra se o estado _isOpeningTransitionPlaying for true
            if (_isOpeningTransitionPlaying)
              BattleTransition(
                phase: TransitionPhase.opening, // Executa apenas a abertura
                onMidpoint: () {
                   // Chamado no início da fase de abertura.
                   // _battleScreenReady pode ou não ser true aqui, dependendo do _loadPokemonData.
                   print("BattleTransition (opening): Midpoint Callback Triggered. Battle Ready: $_battleScreenReady");
                },
                onTransitionComplete: _onOpeningTransitionComplete, // Callback para esconder a transição
              ),
          ],
        ),
      ),
    );
  }
}
