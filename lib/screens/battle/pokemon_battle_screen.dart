import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../../models/pokemon.dart';
import '../../models/pokemon_move.dart';
import '../../models/status_condition.dart';
import '../../services/audio_service.dart';
import 'components/pokemon_info.dart';
import 'components/moves_list.dart';
import 'components/battle_background.dart';
import 'components/battle_transition.dart';
import 'services/battle_service.dart';
import 'services/pokemon_move_service.dart';
import 'utils/animation_utils.dart';

class PokemonBattleScreen extends StatefulWidget {
  final Pokemon pokemon1;
  final Pokemon pokemon2;
  final List<Pokemon>? playerTeam;
  final List<Pokemon>? opponentTeam;
  final bool playOpeningAnimation;

  const PokemonBattleScreen({
    Key? key,
    required this.pokemon1,
    required this.pokemon2,
    this.playerTeam,
    this.opponentTeam,
    this.playOpeningAnimation = true,
  }) : super(key: key);

  @override
  _PokemonBattleScreenState createState() => _PokemonBattleScreenState();
}

enum BattleActor { player, opponent }

enum BattleActionType { move, switchPokemon }

class BattleAction {
  const BattleAction._(this.type, {this.move, this.switchIndex});

  const BattleAction.move(PokemonMove move)
      : this._(BattleActionType.move, move: move);

  const BattleAction.switchPokemon(int index)
      : this._(BattleActionType.switchPokemon, switchIndex: index);

  final BattleActionType type;
  final PokemonMove? move;
  final int? switchIndex;
}

class _PokemonBattleScreenState extends State<PokemonBattleScreen>
    with TickerProviderStateMixin {
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

  late List<Pokemon> _playerTeam;
  late List<Pokemon> _opponentTeam;
  int _playerActiveIndex = 0;
  int _opponentActiveIndex = 0;
  final Map<int, List<PokemonMove>> _movesCache = {};
  final Map<int, List<int>> _ppTracker = {};
  bool _isResolvingTurn = false;
  bool isAnimating = false;
  bool isLoading = true;
  bool _showTransition = true;
  bool _battleScreenReady = false;
  bool _currentAttackerIsPlayer = true;
  String battleLog = '';
  late bool _isOpeningTransitionPlaying;

  @override
  void initState() {
    super.initState();
    
    try {
      print('Inicializando tela de batalha');
      _isOpeningTransitionPlaying = widget.playOpeningAnimation;
      _setupAnimations();

      _playerTeam = _prepareInitialTeam(widget.pokemon1, widget.playerTeam);
      _opponentTeam = _prepareInitialTeam(widget.pokemon2, widget.opponentTeam);

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

  List<Pokemon> _prepareInitialTeam(
    Pokemon lead,
    List<Pokemon>? additional,
  ) {
    final team = <Pokemon>[];
    void addUnique(Pokemon pokemon) {
      if (team.any((member) => member.id == pokemon.id)) {
        return;
      }
      team.add(pokemon);
    }

    addUnique(lead);
    if (additional != null) {
      for (final pokemon in additional) {
        addUnique(pokemon);
      }
    }
    return team;
  }

  Pokemon get _playerActive => _playerTeam[_playerActiveIndex];
  Pokemon get _opponentActive => _opponentTeam[_opponentActiveIndex];

  List<PokemonMove> _movesFor(Pokemon pokemon) {
    return _movesCache[pokemon.id] ?? PokemonMoveService.getDefaultMoves();
  }

  List<int> _remainingPpFor(Pokemon pokemon) {
    return _ppTracker[pokemon.id] ??
        List<int>.from(_movesFor(pokemon).map((move) => move.pp));
  }

  Future<Pokemon> _hydratePokemon(Pokemon pokemon) async {
    try {
      final detailed = await _fetchPokemonDetails(pokemon.id);
      return detailed.copyWith(
        level: pokemon.level,
        status: pokemon.status,
      );
    } catch (_) {
      return pokemon;
    }
  }

  BattleActor _opposite(BattleActor actor) {
    return actor == BattleActor.player
        ? BattleActor.opponent
        : BattleActor.player;
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
      final hydratedPlayerTeam =
          await Future.wait(_playerTeam.map(_hydratePokemon));
      final hydratedOpponentTeam =
          await Future.wait(_opponentTeam.map(_hydratePokemon));

      final combinedTeam = [...hydratedPlayerTeam, ...hydratedOpponentTeam];
      await Future.wait(combinedTeam.map((pokemon) async {
        final moves = await PokemonMoveService.fetchPokemonMoves(
          pokemon.id,
          level: pokemon.level,
        );
        final normalizedMoves =
            moves.isEmpty ? PokemonMoveService.getDefaultMoves() : moves;
        _movesCache[pokemon.id] = normalizedMoves;
        _ppTracker[pokemon.id] =
            List<int>.from(normalizedMoves.map((move) => move.pp));
      }));

      if (!mounted) return;

      setState(() {
        _playerTeam = hydratedPlayerTeam;
        _opponentTeam = hydratedOpponentTeam;
        isLoading = false;
        _battleScreenReady = true;
        battleLog = 'Um ${_opponentActive.name} selvagem apareceu!';
      });

      print('Dados carregados com sucesso. Tela de batalha pronta.');
      print(
          'Jogador (${_playerActive.name}) - Movimentos: ${_movesFor(_playerActive).length}, HP: ${_playerActive.hp}/${_playerActive.maxHp}');
      print(
          'Oponente (${_opponentActive.name}) - Movimentos: ${_movesFor(_opponentActive).length}, HP: ${_opponentActive.hp}/${_opponentActive.maxHp}');
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

  Future<void> _onPlayerMoveSelected(PokemonMove move) async {
    if (_isResolvingTurn || !_battleScreenReady) return;
    final moves = _movesFor(_playerActive);
    final moveIndex = moves.indexOf(move);
    final remainingPp = moveIndex >= 0
        ? _remainingPpFor(_playerActive)[moveIndex]
        : 0;

    if (remainingPp <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este movimento está sem PP!'),
        ),
      );
      return;
    }

    await _resolveTurn(BattleAction.move(move));
  }

  Future<void> _onPlayerSwitchRequested() async {
    if (_isResolvingTurn || !_battleScreenReady) return;

    final available = _playerTeam
        .asMap()
        .entries
        .where((entry) =>
            entry.key != _playerActiveIndex && entry.value.hp > 0)
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum Pokémon disponível para troca!'),
        ),
      );
      return;
    }

    final selectedIndex = await showModalBottomSheet<int>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Escolha o Pokémon para entrar',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              ...available.map((entry) {
                final pokemon = entry.value;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: CachedNetworkImageProvider(pokemon.imageUrl),
                  ),
                  title: Text(pokemon.name),
                  subtitle: Text(
                    '${pokemon.hp.toInt()}/${pokemon.maxHp.toInt()} HP',
                  ),
                  onTap: () => Navigator.of(context).pop(entry.key),
                );
              }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );

    if (selectedIndex == null) return;
    await _resolveTurn(BattleAction.switchPokemon(selectedIndex));
  }

  Future<void> _resolveTurn(BattleAction playerAction) async {
    if (_isResolvingTurn || !_battleScreenReady) return;
    _isResolvingTurn = true;

    final opponentAction = _decideOpponentAction(playerAction);
    final turnOrder = _determineActionOrder(playerAction, opponentAction);

    for (final actor in turnOrder) {
      if (mounted) {
        setState(() {
          _currentAttackerIsPlayer = actor == BattleActor.player;
          isAnimating = true;
        });
      }

      final action = actor == BattleActor.player ? playerAction : opponentAction;
      final didAct = await _performAction(actor, action);
      if (!didAct) {
        continue;
      }

      if (_checkBattleEnd()) {
        _isResolvingTurn = false;
        return;
      }
    }

    await _applyEndOfTurnEffects();

    _isResolvingTurn = false;
    if (mounted) {
      setState(() {
        isAnimating = false;
      });
    }
  }

  BattleAction _decideOpponentAction(BattleAction playerAction) {
    final current = _opponentActive;
    if (current.hp / current.maxHp < 0.3 && _hasAvailableSwitch(false)) {
      final targetIndex = _opponentTeam.asMap().entries.firstWhere(
        (entry) => entry.key != _opponentActiveIndex && entry.value.hp > 0,
      ).key;
      return BattleAction.switchPokemon(targetIndex);
    }

    final moves = _movesFor(current);
    final move = BattleService.selectAIMove(
      moves,
      current,
      _playerActive,
    );
    return BattleAction.move(move);
  }

  List<BattleActor> _determineActionOrder(
    BattleAction playerAction,
    BattleAction opponentAction,
  ) {
    if (playerAction.type == BattleActionType.switchPokemon &&
        opponentAction.type != BattleActionType.switchPokemon) {
      return const [BattleActor.player, BattleActor.opponent];
    }
    if (opponentAction.type == BattleActionType.switchPokemon &&
        playerAction.type != BattleActionType.switchPokemon) {
      return const [BattleActor.opponent, BattleActor.player];
    }

    if (playerAction.type == BattleActionType.switchPokemon &&
        opponentAction.type == BattleActionType.switchPokemon) {
      return _playerActive.speed >= _opponentActive.speed
          ? const [BattleActor.player, BattleActor.opponent]
          : const [BattleActor.opponent, BattleActor.player];
    }

    final playerMove = playerAction.move!;
    final opponentMove = opponentAction.move!;

    if (playerMove.priority != opponentMove.priority) {
      return playerMove.priority > opponentMove.priority
          ? const [BattleActor.player, BattleActor.opponent]
          : const [BattleActor.opponent, BattleActor.player];
    }

    final playerEffectiveSpeed = _effectiveSpeed(_playerActive);
    final opponentEffectiveSpeed = _effectiveSpeed(_opponentActive);

    if (playerEffectiveSpeed == opponentEffectiveSpeed) {
      return math.Random().nextBool()
          ? const [BattleActor.player, BattleActor.opponent]
          : const [BattleActor.opponent, BattleActor.player];
    }

    return playerEffectiveSpeed > opponentEffectiveSpeed
        ? const [BattleActor.player, BattleActor.opponent]
        : const [BattleActor.opponent, BattleActor.player];
  }

  int _effectiveSpeed(Pokemon pokemon) {
    var speed = pokemon.speed;
    if (pokemon.status == StatusCondition.paralysis) {
      speed = (speed * 0.5).floor();
    }
    return speed;
  }

  bool _hasAvailableSwitch(bool isPlayer) {
    final team = isPlayer ? _playerTeam : _opponentTeam;
    final activeIndex = isPlayer ? _playerActiveIndex : _opponentActiveIndex;
    return team.asMap().entries.any(
      (entry) => entry.key != activeIndex && entry.value.hp > 0,
    );
  }

  Future<bool> _performAction(BattleActor actor, BattleAction action) async {
    final isPlayer = actor == BattleActor.player;
    final activePokemon = isPlayer ? _playerActive : _opponentActive;

    if (activePokemon.hp <= 0 && action.type == BattleActionType.move) {
      return false;
    }

    switch (action.type) {
      case BattleActionType.switchPokemon:
        final index = action.switchIndex!;
        await _performSwitch(isPlayer, index);
        return true;
      case BattleActionType.move:
        final move = action.move!;
        return _performMove(isPlayer, move);
    }
  }

  Future<void> _performSwitch(bool isPlayer, int newIndex) async {
    setState(() {
      battleLog =
          '${isPlayer ? _playerActive.name : _opponentActive.name} foi retirado!';
    });

    await Future.delayed(const Duration(milliseconds: 350));

    if (mounted) {
      setState(() {
        if (isPlayer) {
          _playerActiveIndex = newIndex;
        } else {
          _opponentActiveIndex = newIndex;
        }
        battleLog =
            '${isPlayer ? _playerActive.name : _opponentActive.name} entrou na batalha!';
      });
    }
  }

  Future<bool> _performMove(bool isPlayer, PokemonMove move) async {
    final attacker = isPlayer ? _playerActive : _opponentActive;
    final defenderActor = _opposite(isPlayer ? BattleActor.player : BattleActor.opponent);
    final defender = isPlayer ? _opponentActive : _playerActive;

    if (_consumePp(attacker, move) == false) {
      return false;
    }

    if (!_canAct(attacker)) {
      setState(() {
        battleLog = '${attacker.name} está incapacitado!';
      });
      return true;
    }

    setState(() {
      battleLog = '${attacker.name} usa ${move.name}!';
    });

    await _attackAnimationController.forward();
    _attackAnimationController.reset();

    final hit = BattleService.checkHitSuccess(move.accuracy);
    if (!hit) {
      setState(() {
        battleLog = 'O ataque de ${attacker.name} errou!';
      });
      return true;
    }

    final damage = BattleService.calculateDamage(
      move: move,
      attacker: attacker,
      defender: defender,
      attackerStatus: attacker.status,
    );

    if (damage > 0) {
      await _applyDamage(
        defenderActor,
        damage,
        attacker: attacker,
        moveName: move.name,
      );
    } else if (move.healPercent != null && move.healPercent! > 0) {
      await _applyHealing(attacker, move.healPercent!);
    }

    _applyAilment(move, defenderActor);

    return true;
  }

  bool _consumePp(Pokemon attacker, PokemonMove move) {
    final moves = _movesFor(attacker);
    final index = moves.indexOf(move);
    if (index < 0) return true;

    final ppList = _ppTracker[attacker.id];
    if (ppList == null) return true;
    if (ppList[index] <= 0) return false;

    setState(() {
      ppList[index] = ppList[index] - 1;
    });
    return true;
  }

  bool _canAct(Pokemon pokemon) {
    if (pokemon.status == StatusCondition.paralysis) {
      return math.Random().nextDouble() > 0.25;
    }
    return true;
  }

  Future<void> _applyDamage(
    BattleActor defenderActor,
    double damage, {
    Pokemon? attacker,
    String? moveName,
  }) async {
    final isPlayer = defenderActor == BattleActor.player;
    final defender = isPlayer ? _playerActive : _opponentActive;
    final newHp = (defender.hp - damage).clamp(0, defender.maxHp).toDouble();

    final attackerName = attacker?.name ??
        (isPlayer ? _opponentActive.name : _playerActive.name);
    final logMoveName = moveName ?? '';

    setState(() {
      if (isPlayer) {
        _playerTeam[_playerActiveIndex] =
            defender.copyWith(hp: newHp.toDouble());
      } else {
        _opponentTeam[_opponentActiveIndex] =
            defender.copyWith(hp: newHp.toDouble());
      }
      battleLog = BattleService.generateBattleLog(
        attackerName: attackerName,
        moveName: logMoveName,
        isHit: true,
        damage: damage,
        remainingHP: newHp,
        maxHP: defender.maxHp,
      );
    });

    await _shakeAnimationController.forward();
    _shakeAnimationController.reset();
  }

  Future<void> _applyHealing(Pokemon attacker, double healPercent) async {
    final healedAmount = (attacker.maxHp * healPercent)
        .clamp(1, attacker.maxHp)
        .toDouble();
    final newHp = (attacker.hp + healedAmount)
        .clamp(0, attacker.maxHp)
        .toDouble();

    setState(() {
      if (_playerActive.id == attacker.id) {
        _playerTeam[_playerActiveIndex] =
            attacker.copyWith(hp: newHp);
      } else if (_opponentActive.id == attacker.id) {
        _opponentTeam[_opponentActiveIndex] =
            attacker.copyWith(hp: newHp);
      }
      battleLog =
          '${attacker.name} recuperou ${healedAmount.toInt()} HP!';
    });

    await Future.delayed(const Duration(milliseconds: 300));
  }

  void _applyAilment(PokemonMove move, BattleActor targetActor) {
    if (move.ailment == null || move.ailment == 'none') return;
    if (move.ailmentChance <= 0) return;

    if (math.Random().nextDouble() > move.ailmentChance) return;

    final target = targetActor == BattleActor.player ? _playerActive : _opponentActive;
    if (target.status != StatusCondition.none) return;

    final ailment = StatusConditionX.fromName(move.ailment);
    final updated = target.copyWith(status: ailment);

    setState(() {
      if (targetActor == BattleActor.player) {
        _playerTeam[_playerActiveIndex] = updated;
      } else {
        _opponentTeam[_opponentActiveIndex] = updated;
      }
      battleLog = '${target.name} foi afetado por ${ailment.name}!';
    });
  }

  Future<void> _applyEndOfTurnEffects() async {
    await _applyResidualStatus(BattleActor.player);
    await _applyResidualStatus(BattleActor.opponent);
    _checkBattleEnd();
  }

  Future<void> _applyResidualStatus(BattleActor actor) async {
    final pokemon = actor == BattleActor.player ? _playerActive : _opponentActive;
    if (pokemon.status == StatusCondition.none || pokemon.hp <= 0) return;

    if (pokemon.status == StatusCondition.burn ||
        pokemon.status == StatusCondition.poison) {
      final residual = (pokemon.maxHp / 16).clamp(1, pokemon.maxHp).toDouble();
      await _applyDamage(actor, residual);
      setState(() {
        battleLog = '${pokemon.name} sofre com ${pokemon.status.name}!';
      });
    }
  }

  bool _checkBattleEnd() {
    final playerAlive =
        _playerTeam.any((pokemon) => pokemon.hp > 0);
    final opponentAlive =
        _opponentTeam.any((pokemon) => pokemon.hp > 0);

    if (playerAlive && opponentAlive) {
      return false;
    }

    final playerWon = playerAlive && !opponentAlive;

    setState(() {
      battleLog = playerWon
          ? '${_playerActive.name} venceu a batalha!'
          : '${_opponentActive.name} venceu a batalha!';
      isAnimating = true;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _showBattleEndDialog(playerWon);
      }
    });

    return true;
  }

  void _showBattleEndDialog(bool playerWon) {
    _audioService.stopMusic();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Batalha Finalizada!'),
        content: Text(playerWon
            ? 'Você venceu a batalha!'
            : 'O oponente venceu a batalha.'),
        actions: [
          TextButton(
            onPressed: () {
              _audioService.stopMusic();
              Navigator.of(context).pop();
              Navigator.of(context).pop(playerWon);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPokemonImage(
    Pokemon pokemon,
    bool isPlayerSide,
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
        
        if ((isPlayerSide && _currentAttackerIsPlayer) ||
            (!isPlayerSide && !_currentAttackerIsPlayer)) {
          finalOffset += attackAnimation.value;
        }

        if ((isPlayerSide && !_currentAttackerIsPlayer) ||
            (!isPlayerSide && _currentAttackerIsPlayer)) {
          finalOffset += Offset(
            math.sin(_shakeAnimationController.value * math.pi * 8) * 5,
            0,
          );
        }

        finalOffset += Offset(
          math.sin(floatingAnimation.value * 2 * math.pi + (isPlayerSide ? math.pi : 0)) * 5,
          math.cos(floatingAnimation.value * 2 * math.pi + (isPlayerSide ? math.pi : 0)) * 8,
        );

        return Transform.translate(
          offset: finalOffset,
          child: Transform.rotate(
            angle: math.sin(
                  floatingAnimation.value * 2 * math.pi +
                      (isPlayerSide ? math.pi : 0),
                ) *
                0.05,
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
    final playerMoves =
        _battleScreenReady ? _movesFor(_playerActive) : <PokemonMove>[];
    final playerRemainingPp = _battleScreenReady
        ? _remainingPpFor(_playerActive)
        : <int>[];
    final canSwitch = _battleScreenReady && _hasAvailableSwitch(true);

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
                                        pokemon: _opponentActive,
                                        hp: _opponentActive.hp,
                                        maxHp: _opponentActive.maxHp,
                                        isLeft: true,
                                      ),
                                     ],
                                   ),
                                   const Spacer(),
                                   Row(
                                     mainAxisAlignment: MainAxisAlignment.start,
                                     children: [
                                      PokemonInfo(
                                        pokemon: _playerActive,
                                        hp: _playerActive.hp,
                                        maxHp: _playerActive.maxHp,
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
                                 _opponentActive,
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
                                 _playerActive,
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
                        // Movimentos do jogador (sempre visível)
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
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: (!isAnimating && canSwitch)
                                          ? _onPlayerSwitchRequested
                                          : null,
                                      icon: const Icon(Icons.swap_horiz),
                                      label: const Text('Trocar Pokémon'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red[600],
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MovesList(
                                moves: playerMoves,
                                remainingPP: playerRemainingPp,
                                isDisabled: isAnimating,
                                onMoveSelected: _onPlayerMoveSelected,
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
