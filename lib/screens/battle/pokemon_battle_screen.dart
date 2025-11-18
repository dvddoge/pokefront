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

class _BindingEffect {
  _BindingEffect({required this.remainingTurns, required this.damageFraction});

  int remainingTurns;
  final double damageFraction;
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
  final math.Random _random = math.Random();
  final Map<int, _BindingEffect> _bindingEffects = {};
  final Map<int, int> _confusionCounters = {};
  final Set<int> _flinchNextTurn = {};
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
      debugPrint('Inicializando tela de batalha');
      _isOpeningTransitionPlaying = widget.playOpeningAnimation;
      _setupAnimations();

      _playerTeam = _prepareInitialTeam(widget.pokemon1, widget.playerTeam);
      _opponentTeam = _prepareInitialTeam(widget.pokemon2, widget.opponentTeam);

      // Certifica-se de que a transição seja exibida ao iniciar a tela
      setState(() {
        _showTransition = true;
        _battleScreenReady = false;
      });

      debugPrint('Estado inicial da tela de batalha:');
      debugPrint('- _showTransition: $_showTransition');
      debugPrint('- _battleScreenReady: $_battleScreenReady');

      // Carrega os dados imediatamente para garantir que estejam disponíveis
      // quando a animação de transição terminar
      _loadPokemonData();
    } catch (e) {
      debugPrint('Erro ao inicializar tela de batalha: $e');
    }
  }

  void _setupAnimations() {
    _battleAnimationController = AnimationUtils.createBattleController(this);
    _shakeAnimationController = AnimationUtils.createShakeController(this);
    _damageAnimationController = AnimationUtils.createDamageController(this);
    _attackAnimationController = AnimationUtils.createAttackController(this);
    _backgroundAnimationController =
        AnimationUtils.createBackgroundController(this);
    _floatingAnimationController =
        AnimationUtils.createFloatingController(this);
    _flashAnimationController = AnimationUtils.createFlashController(this);

    _attackAnimation =
        AnimationUtils.createAttackAnimation(_attackAnimationController);
    _backgroundAnimation = AnimationUtils.createBackgroundAnimation(
        _backgroundAnimationController);
    _floatingAnimation =
        AnimationUtils.createFloatingAnimation(_floatingAnimationController);
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
        statusCounter: pokemon.statusCounter,
        hp: pokemon.hp,
        maxHp: pokemon.maxHp,
        statStages: pokemon.statStages,
        ability:
            detailed.ability.isNotEmpty ? detailed.ability : pokemon.ability,
        heldItem: detailed.heldItem ?? pokemon.heldItem,
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

  bool _hasAbility(Pokemon pokemon, String ability) {
    return pokemon.ability.toLowerCase() == ability.toLowerCase();
  }

  bool _blocksSecondaryEffects(Pokemon pokemon) {
    return _hasAbility(pokemon, 'shield-dust');
  }

  Pokemon get _playerActive => _playerTeam[_playerActiveIndex];
  Pokemon get _opponentActive => _opponentTeam[_opponentActiveIndex];

  void _updateActivePokemon(BattleActor actor, Pokemon updated) {
    if (actor == BattleActor.player) {
      _playerTeam[_playerActiveIndex] = updated;
    } else {
      _opponentTeam[_opponentActiveIndex] = updated;
    }
  }

  void _log(String message) {
    setState(() {
      battleLog = message;
    });
  }

  void _setStatus(
    BattleActor actor,
    StatusCondition status, {
    int counter = 0,
    String? message,
  }) {
    setState(() {
      final current =
          actor == BattleActor.player ? _playerActive : _opponentActive;
      final updated = current.copyWith(status: status, statusCounter: counter);
      _updateActivePokemon(actor, updated);
      if (message != null && message.isNotEmpty) {
        battleLog = message;
      }
    });
  }

  void _setStatusCounter(BattleActor actor, int counter) {
    final current =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    final updated = current.copyWith(statusCounter: counter);
    setState(() {
      _updateActivePokemon(actor, updated);
    });
  }

  String _formatStatName(String stat) {
    switch (stat) {
      case 'attack':
        return 'ataque';
      case 'defense':
        return 'defesa';
      case 'special-attack':
        return 'ataque especial';
      case 'special-defense':
        return 'defesa especial';
      case 'speed':
        return 'velocidade';
      case 'accuracy':
        return 'precisão';
      case 'evasion':
        return 'evasão';
      default:
        return stat;
    }
  }

  String _statusDescription(StatusCondition status) {
    switch (status) {
      case StatusCondition.burn:
        return 'sofreu uma queimadura';
      case StatusCondition.paralysis:
        return 'ficou paralisado';
      case StatusCondition.poison:
        return 'foi envenenado';
      case StatusCondition.toxic:
        return 'foi gravemente envenenado';
      case StatusCondition.sleep:
        return 'adormeceu';
      case StatusCondition.freeze:
        return 'foi congelado';
      case StatusCondition.none:
        return 'está saudável';
    }
  }

  Future<void> _healPokemon(
    BattleActor actor,
    double amount, {
    String? reason,
  }) async {
    if (amount <= 0) return;
    final pokemon =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    if (pokemon.hp <= 0 || pokemon.hp >= pokemon.maxHp) {
      if (reason != null && reason.isNotEmpty) {
        _log(reason);
      }
      return;
    }

    final newHp = (pokemon.hp + amount).clamp(0, pokemon.maxHp).toDouble();
    final healed = newHp - pokemon.hp;
    if (healed <= 0) {
      if (reason != null && reason.isNotEmpty) {
        _log(reason);
      }
      return;
    }

    setState(() {
      final updated = pokemon.copyWith(hp: newHp);
      _updateActivePokemon(actor, updated);
      if (reason != null && reason.isNotEmpty) {
        battleLog = reason;
      } else {
        battleLog = '${pokemon.name} recuperou ${healed.toInt()} HP!';
      }
    });

    await Future.delayed(const Duration(milliseconds: 200));
  }

  String? _statusImmunityMessage(Pokemon pokemon, StatusCondition status) {
    final types = pokemon.types.map((t) => t.toLowerCase()).toList();
    final ability = pokemon.ability.toLowerCase();

    if (pokemon.status != StatusCondition.none &&
        status != StatusCondition.none) {
      return '${pokemon.name} já possui uma condição de status.';
    }

    switch (status) {
      case StatusCondition.burn:
        if (types.contains('fire') ||
            ability == 'water-veil' ||
            ability == 'flash-fire') {
          return '${pokemon.name} é imune a queimaduras.';
        }
        break;
      case StatusCondition.paralysis:
        if (types.contains('electric') || ability == 'limber') {
          return '${pokemon.name} não pode ser paralisado.';
        }
        break;
      case StatusCondition.poison:
        if (types.contains('poison') ||
            types.contains('steel') ||
            ability == 'immunity') {
          return '${pokemon.name} não pode ser envenenado.';
        }
        break;
      case StatusCondition.toxic:
        if (types.contains('poison') ||
            types.contains('steel') ||
            ability == 'immunity') {
          return '${pokemon.name} não pode ser gravemente envenenado.';
        }
        break;
      case StatusCondition.sleep:
        if (ability == 'insomnia' || ability == 'vital-spirit') {
          return '${pokemon.name} não pode adormecer.';
        }
        break;
      case StatusCondition.freeze:
        if (types.contains('ice') || ability == 'magma-armor') {
          return '${pokemon.name} não pode ser congelado.';
        }
        break;
      case StatusCondition.none:
        return null;
    }

    return null;
  }

  void _changeStatStage(BattleActor actor, String stat, int delta) {
    final current =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    final stages = Map<String, int>.from(current.statStages);
    final currentValue = stages[stat] ?? 0;
    final newStage = (currentValue + delta).clamp(-6, 6);

    if (newStage == currentValue) {
      final message = delta > 0
          ? '${current.name} não pode aumentar mais ${_formatStatName(stat)}.'
          : '${current.name} não pode reduzir mais ${_formatStatName(stat)}.';
      _log(message);
      return;
    }

    stages[stat] = newStage;
    setState(() {
      final updated = current.copyWith(statStages: stages);
      _updateActivePokemon(actor, updated);
      battleLog = delta > 0
          ? '${current.name} aumentou ${_formatStatName(stat)}!'
          : '${current.name} teve ${_formatStatName(stat)} reduzido!';
    });
  }

  void _applyStatChanges(
    PokemonMove move,
    BattleActor attackerActor,
    BattleActor defenderActor,
  ) {
    if (move.statChanges.isEmpty) return;
    if (move.statChance < 1.0 && _random.nextDouble() > move.statChance) {
      return;
    }

    move.statChanges.forEach((stat, change) {
      if (change == 0) return;
      final targetActor = move.targetsSelf ? attackerActor : defenderActor;
      _changeStatStage(targetActor, stat, change);
    });
  }

  int _determineHits(PokemonMove move) {
    final minHits = move.minHits ?? 1;
    final maxHits = move.maxHits ?? minHits;
    if (maxHits <= minHits) return minHits;
    return _random.nextInt(maxHits - minHits + 1) + minHits;
  }

  Future<bool> _handleAbilityPreHit(
    BattleActor defenderActor,
    PokemonMove move,
  ) async {
    final defender =
        defenderActor == BattleActor.player ? _playerActive : _opponentActive;
    final ability = defender.ability.toLowerCase();
    if (ability.isEmpty) return false;

    if (ability == 'levitate' && move.type == 'ground') {
      _log('${defender.name} evitou o ataque graças a Levitate!');
      return true;
    }

    if (ability == 'water-absorb' && move.type == 'water') {
      await _healPokemon(
        defenderActor,
        defender.maxHp * 0.25,
        reason: '${defender.name} absorveu o ataque de água!',
      );
      return true;
    }

    if (ability == 'volt-absorb' && move.type == 'electric') {
      await _healPokemon(
        defenderActor,
        defender.maxHp * 0.25,
        reason: '${defender.name} converteu o ataque elétrico em energia!',
      );
      return true;
    }

    if (ability == 'flash-fire' && move.type == 'fire') {
      _log('${defender.name} absorveu o fogo com Flash Fire!');
      return true;
    }

    return false;
  }

  Future<void> _checkItemAfterDamage(BattleActor actor) async {
    final pokemon =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    final item = pokemon.heldItem?.toLowerCase();
    if (item == null || item.isEmpty) return;

    if (item == 'sitrus-berry' &&
        pokemon.hp > 0 &&
        pokemon.hp <= pokemon.maxHp * 0.5) {
      final healAmount = pokemon.maxHp * 0.25;
      setState(() {
        final updated = pokemon.copyWith(heldItem: null);
        _updateActivePokemon(actor, updated);
      });
      await _healPokemon(
        actor,
        healAmount,
        reason: '${pokemon.name} recuperou forças com a Sitrus Berry!',
      );
    }
  }

  Future<void> _handleEndTurnItems(BattleActor actor) async {
    final pokemon =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    final item = pokemon.heldItem?.toLowerCase();
    if (item == null || item.isEmpty || pokemon.hp <= 0) return;

    if (item == 'leftovers' && pokemon.hp < pokemon.maxHp) {
      await _healPokemon(
        actor,
        pokemon.maxHp / 16,
        reason: '${pokemon.name} recuperou um pouco de HP com Restos.',
      );
    }
  }

  Future<void> _startBattleMusic() async {
    try {
      await _audioService
          .playMusic('sounds/music/assets_audio_music_wild-battle.ogg');
    } catch (e) {
      debugPrint('Erro ao tocar música de batalha: $e');
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

    debugPrint('Carregando dados dos Pokémon');

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

      _bindingEffects.clear();
      _confusionCounters.clear();
      _flinchNextTurn.clear();

      setState(() {
        _playerTeam = hydratedPlayerTeam;
        _opponentTeam = hydratedOpponentTeam;
        isLoading = false;
        _battleScreenReady = true;
        battleLog = 'Um ${_opponentActive.name} selvagem apareceu!';
      });

      debugPrint('Dados carregados com sucesso. Tela de batalha pronta.');
      debugPrint(
          'Jogador (${_playerActive.name}) - Movimentos: ${_movesFor(_playerActive).length}, HP: ${_playerActive.hp}/${_playerActive.maxHp}');
      debugPrint(
          'Oponente (${_opponentActive.name}) - Movimentos: ${_movesFor(_opponentActive).length}, HP: ${_opponentActive.hp}/${_opponentActive.maxHp}');
    } catch (e) {
      debugPrint('Erro ao carregar dados da batalha: $e');
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
    final remainingPp =
        moveIndex >= 0 ? _remainingPpFor(_playerActive)[moveIndex] : 0;

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
        .where((entry) => entry.key != _playerActiveIndex && entry.value.hp > 0)
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
                    backgroundImage:
                        CachedNetworkImageProvider(pokemon.imageUrl),
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

      final action =
          actor == BattleActor.player ? playerAction : opponentAction;
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
      final targetIndex = _opponentTeam
          .asMap()
          .entries
          .firstWhere(
            (entry) => entry.key != _opponentActiveIndex && entry.value.hp > 0,
          )
          .key;
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
      return _random.nextBool()
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
    final stage = pokemon.statStages['speed'] ?? 0;
    final modifier = stage >= 0 ? (2 + stage) / 2.0 : 2.0 / (2 - stage);
    return (speed * modifier).floor();
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
    final leavingPokemon = isPlayer ? _playerActive : _opponentActive;
    _bindingEffects.remove(leavingPokemon.id);
    _confusionCounters.remove(leavingPokemon.id);
    _flinchNextTurn.remove(leavingPokemon.id);

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
            'Vai! ${isPlayer ? _playerActive.name : _opponentActive.name}!';
      });
    }
  }

  Future<bool> _performMove(bool isPlayer, PokemonMove move) async {
    final attackerActor = isPlayer ? BattleActor.player : BattleActor.opponent;
    final defenderActor = isPlayer ? BattleActor.opponent : BattleActor.player;

    if (!await _canAct(attackerActor)) {
      return true;
    }

    if (!_consumePp(isPlayer ? _playerActive : _opponentActive, move)) {
      _log('Sem PP para este movimento!');
      return false;
    }

    _log(BattleService.generateBattleLog(
      attackerName: isPlayer ? _playerActive.name : _opponentActive.name,
      moveName: move.name,
      isHit: true,
    ));

    await _attackAnimationController.forward();
    _attackAnimationController.reset();

    if (await _handleAbilityPreHit(defenderActor, move)) {
      return true;
    }

    final attacker = isPlayer ? _playerActive : _opponentActive;
    final defender = isPlayer ? _opponentActive : _playerActive;

    if (!BattleService.checkHitSuccess(
        move.accuracy.toDouble(), attacker, defender)) {
      _log(BattleService.generateBattleLog(
        attackerName: attacker.name,
        moveName: move.name,
        isHit: false,
      ));
      return true;
    }

    final hits = _determineHits(move);
    double totalDamage = 0;
    bool flinchApplied = false;

    for (var i = 0; i < hits; i++) {
      final attacker =
          attackerActor == BattleActor.player ? _playerActive : _opponentActive;
      final defender =
          defenderActor == BattleActor.player ? _playerActive : _opponentActive;

      final damage = BattleService.calculateDamage(
        move: move,
        attacker: attacker,
        defender: defender,
        attackerStatus: attacker.status,
      );

      if (damage <= 0) {
        break;
      }

      final inflicted = await _applyDamage(
        defenderActor,
        damage,
        attacker: attacker,
        moveName: move.name,
        moveType: move.type,
      );

      totalDamage += inflicted;

      final defenderAfter =
          defenderActor == BattleActor.player ? _playerActive : _opponentActive;
      if (!flinchApplied &&
          move.flinchChance != null &&
          move.flinchChance! > 0 &&
          defenderAfter.hp > 0) {
        final roll = _random.nextDouble();
        if (roll < move.flinchChance!) {
          if (_hasAbility(defenderAfter, 'inner-focus')) {
            _log('${defenderAfter.name} manteve o foco e não se abalou!');
          } else if (_blocksSecondaryEffects(defenderAfter)) {
            _log(
                '${defenderAfter.name} ignorou o efeito adicional graças a Shield Dust!');
          } else {
            _flinchNextTurn.add(defenderAfter.id);
            _log('${defenderAfter.name} ficou atordoado!');
          }
          flinchApplied = true;
        }
      }
      if (defenderAfter.hp <= 0) {
        break;
      }
    }

    if (move.healPercent != null && move.healPercent! > 0) {
      final healer =
          attackerActor == BattleActor.player ? _playerActive : _opponentActive;
      await _healPokemon(
        attackerActor,
        healer.maxHp * move.healPercent!,
        reason: '${healer.name} recuperou energia!',
      );
    }

    if (totalDamage > 0 && move.drain != null) {
      final lifesteal =
          attackerActor == BattleActor.player ? _playerActive : _opponentActive;
      await _healPokemon(
        attackerActor,
        totalDamage * move.drain!,
        reason: '${lifesteal.name} drenou vida do adversário!',
      );
    }

    if (totalDamage > 0 && move.recoil != null) {
      final recoilTarget =
          attackerActor == BattleActor.player ? _playerActive : _opponentActive;
      await _applyDamage(
        attackerActor,
        totalDamage * move.recoil!,
        attacker: recoilTarget,
        moveName: 'recuo',
        suppressLog: true,
      );
      _log('${recoilTarget.name} sofreu dano de recuo!');
    }

    _applyStatChanges(move, attackerActor, defenderActor);
    _applyAilment(move, attackerActor, defenderActor);

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

  Future<bool> _canAct(BattleActor actor) async {
    final pokemon =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    final pokemonId = pokemon.id;

    if (_flinchNextTurn.remove(pokemonId)) {
      _log('${pokemon.name} recuou e não conseguiu agir!');
      return false;
    }

    if (_confusionCounters.containsKey(pokemonId)) {
      final remaining = _confusionCounters[pokemonId] ?? 0;
      final selfHit = _random.nextDouble() < 0.33;
      final newRemaining = remaining - 1;

      if (newRemaining <= 0) {
        _confusionCounters.remove(pokemonId);
        _log('${pokemon.name} se recuperou da confusão!');
      } else {
        _confusionCounters[pokemonId] = newRemaining;
        _log('${pokemon.name} está confuso!');
      }

      if (selfHit) {
        final damage = (pokemon.maxHp / 8).clamp(1, pokemon.maxHp).toDouble();
        await _applyDamage(
          actor,
          damage,
          moveName: 'confusão',
          suppressLog: true,
        );
        _log('${pokemon.name} se machucou na confusão!');
        return false;
      }
    }

    switch (pokemon.status) {
      case StatusCondition.sleep:
        if (pokemon.statusCounter <= 0) {
          _setStatus(actor, StatusCondition.none,
              message: '${pokemon.name} acordou!');
          return true;
        }
        _setStatusCounter(actor, pokemon.statusCounter - 1);
        _log('${pokemon.name} está dormindo.');
        return false;
      case StatusCondition.freeze:
        if (_random.nextDouble() < 0.2) {
          _setStatus(actor, StatusCondition.none,
              message: '${pokemon.name} descongelou!');
          return true;
        }
        _log('${pokemon.name} está congelado e não pode atacar!');
        return false;
      case StatusCondition.paralysis:
        if (_random.nextDouble() < 0.25) {
          _log('${pokemon.name} está paralisado e não se moveu!');
          return false;
        }
        return true;
      case StatusCondition.burn:
      case StatusCondition.poison:
      case StatusCondition.toxic:
      case StatusCondition.none:
        return true;
    }
  }

  Future<double> _applyDamage(
    BattleActor defenderActor,
    double damage, {
    Pokemon? attacker,
    String? moveName,
    String? moveType,
    bool suppressLog = false,
  }) async {
    final isPlayer = defenderActor == BattleActor.player;
    final defender = isPlayer ? _playerActive : _opponentActive;
    final inflicted = math.min(damage, defender.hp);
    final newHp = (defender.hp - damage).clamp(0, defender.maxHp).toDouble();

    final attackerName = attacker?.name ??
        (isPlayer ? _opponentActive.name : _playerActive.name);
    final logMoveName = moveName ?? '';

    setState(() {
      final updated = defender.copyWith(hp: newHp);
      _updateActivePokemon(defenderActor, updated);
      if (!suppressLog) {
        battleLog = BattleService.generateBattleLog(
          attackerName: attackerName,
          moveName: logMoveName,
          isHit: true,
          damage: damage,
          remainingHP: newHp,
          maxHP: defender.maxHp,
        );
      }
    });

    await _shakeAnimationController.forward();
    _shakeAnimationController.reset();

    if (moveType == 'fire') {
      final current =
          defenderActor == BattleActor.player ? _playerActive : _opponentActive;
      if (current.status == StatusCondition.freeze) {
        _setStatus(defenderActor, StatusCondition.none,
            message: '${current.name} descongelou!');
      }
    }

    await _checkItemAfterDamage(defenderActor);

    if (newHp <= 0) {
      _bindingEffects.remove(defender.id);
      _confusionCounters.remove(defender.id);
      _flinchNextTurn.remove(defender.id);
    }

    return inflicted;
  }

  void _applyAilment(
    PokemonMove move,
    BattleActor attackerActor,
    BattleActor targetActor,
  ) {
    if (move.ailment == null || move.ailment == 'none') return;
    if (move.ailmentChance <= 0) return;
    if (_random.nextDouble() > move.ailmentChance) return;

    final effectActor = move.targetsSelf ? attackerActor : targetActor;
    final target =
        effectActor == BattleActor.player ? _playerActive : _opponentActive;

    if (!move.targetsSelf && _blocksSecondaryEffects(target)) {
      _log('${target.name} ignorou o efeito adicional graças a Shield Dust!');
      return;
    }

    if (move.ailment == 'trap') {
      _applyBindingEffect(effectActor, move);
      return;
    }

    if (move.ailment == 'confusion') {
      _applyConfusion(effectActor);
      return;
    }

    final ailment = StatusConditionX.fromName(move.ailment);
    if (ailment == StatusCondition.none) {
      return;
    }
    final immunityMessage = _statusImmunityMessage(target, ailment);
    if (immunityMessage != null) {
      _log(immunityMessage);
      return;
    }

    int counter = 0;
    switch (ailment) {
      case StatusCondition.sleep:
        counter = _random.nextInt(3) + 1;
        break;
      case StatusCondition.toxic:
        counter = 1;
        break;
      default:
        counter = 0;
    }

    final description = _statusDescription(ailment);
    _setStatus(
      effectActor,
      ailment,
      counter: counter,
      message: '${target.name} $description!',
    );
  }

  void _applyBindingEffect(BattleActor targetActor, PokemonMove move) {
    final target =
        targetActor == BattleActor.player ? _playerActive : _opponentActive;
    final minTurns = (move.minTurns ?? 4).clamp(1, 10);
    final maxTurns = (move.maxTurns ?? minTurns).clamp(minTurns, minTurns + 4);
    final turns = maxTurns > minTurns
        ? _random.nextInt(maxTurns - minTurns + 1) + minTurns
        : minTurns;

    _bindingEffects[target.id] =
        _BindingEffect(remainingTurns: turns, damageFraction: 1 / 16);
    _log('${target.name} ficou preso pelo ataque!');
  }

  void _applyConfusion(BattleActor targetActor) {
    final target =
        targetActor == BattleActor.player ? _playerActive : _opponentActive;
    if (_hasAbility(target, 'own-tempo')) {
      _log('${target.name} manteve o ritmo e evitou a confusão!');
      return;
    }

    final turns = _random.nextInt(4) + 1;
    _confusionCounters[target.id] = turns;
    _log('${target.name} ficou confuso!');
  }

  Future<void> _applyEndOfTurnEffects() async {
    await _applyResidualStatus(BattleActor.player);
    await _applyResidualStatus(BattleActor.opponent);
    await _applyBindingEffects();
    await _handleEndTurnItems(BattleActor.player);
    await _handleEndTurnItems(BattleActor.opponent);
    _checkBattleEnd();
  }

  Future<void> _applyBindingEffects() async {
    final affectedIds = List<int>.from(_bindingEffects.keys);
    for (final id in affectedIds) {
      BattleActor? actor;
      if (_playerActive.id == id) {
        actor = BattleActor.player;
      } else if (_opponentActive.id == id) {
        actor = BattleActor.opponent;
      } else {
        _bindingEffects.remove(id);
        continue;
      }

      final effect = _bindingEffects[id];
      if (effect == null) continue;

      final pokemon =
          actor == BattleActor.player ? _playerActive : _opponentActive;
      if (pokemon.hp <= 0) {
        _bindingEffects.remove(id);
        continue;
      }

      final damage = (pokemon.maxHp * effect.damageFraction)
          .clamp(1, pokemon.maxHp)
          .toDouble();
      await _applyDamage(
        actor,
        damage,
        moveName: 'dano contínuo',
        suppressLog: true,
      );
      _log('${pokemon.name} sofre com a restrição!');

      effect.remainingTurns -= 1;
      if (effect.remainingTurns <= 0 || pokemon.hp <= 0) {
        _bindingEffects.remove(id);
        if (pokemon.hp > 0) {
          _log('${pokemon.name} se libertou!');
        }
      } else {
        _bindingEffects[id] = effect;
      }
    }
  }

  Future<void> _applyResidualStatus(BattleActor actor) async {
    final pokemon =
        actor == BattleActor.player ? _playerActive : _opponentActive;
    if (pokemon.status == StatusCondition.none || pokemon.hp <= 0) return;

    if (pokemon.status == StatusCondition.poison &&
        (_hasAbility(pokemon, 'poison-heal'))) {
      await _healPokemon(
        actor,
        pokemon.maxHp / 8,
        reason: '${pokemon.name} recuperou HP com Poison Heal!',
      );
      return;
    }

    if (pokemon.status == StatusCondition.toxic) {
      final stage = pokemon.statusCounter <= 0 ? 1 : pokemon.statusCounter;
      final residual =
          (pokemon.maxHp / 16 * stage).clamp(1, pokemon.maxHp).toDouble();
      await _applyDamage(
        actor,
        residual,
        moveName: 'veneno severo',
        suppressLog: true,
      );
      _log('${pokemon.name} sofre com o veneno severo!');
      _setStatusCounter(actor, stage + 1);
      return;
    }

    if (pokemon.status == StatusCondition.burn ||
        pokemon.status == StatusCondition.poison) {
      final residual = (pokemon.maxHp / 16).clamp(1, pokemon.maxHp).toDouble();
      await _applyDamage(
        actor,
        residual,
        moveName: 'dano residual',
        suppressLog: true,
      );
      final statusText =
          pokemon.status == StatusCondition.burn ? 'a queimadura' : 'o veneno';
      _log('${pokemon.name} sofre com $statusText!');
    }
  }

  bool _checkBattleEnd() {
    final playerAlive = _playerTeam.any((pokemon) => pokemon.hp > 0);
    final opponentAlive = _opponentTeam.any((pokemon) => pokemon.hp > 0);

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
          math.sin(floatingAnimation.value * 2 * math.pi +
                  (isPlayerSide ? math.pi : 0)) *
              5,
          math.cos(floatingAnimation.value * 2 * math.pi +
                  (isPlayerSide ? math.pi : 0)) *
              8,
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
    debugPrint("Animação de abertura completa.");
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
    final playerRemainingPp =
        _battleScreenReady ? _remainingPpFor(_playerActive) : <int>[];
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
                                  color: Colors.white.withValues(
                                      alpha: _flashAnimationController.value *
                                          0.3),
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
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 8,
                              offset: const Offset(0, -4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                color: Colors.red[700],
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.shade900
                                        .withValues(alpha: 0.3),
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
                phase: TransitionPhase.opening,
                onMidpoint: () {
                  debugPrint(
                      "BattleTransition (opening): Midpoint Callback Triggered. Battle Ready: $_battleScreenReady");
                },
                onTransitionComplete: _onOpeningTransitionComplete,
              ),
          ],
        ),
      ),
    );
  }
}
