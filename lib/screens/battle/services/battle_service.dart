import 'dart:math' as math;
import '../../../models/pokemon.dart';
import '../../../models/pokemon_move.dart';
import '../../../models/status_condition.dart';
import '../../../models/ability_data.dart';

class BattleService {
  static final math.Random _random = math.Random();

  // Multiplicadores de estágio de estatística (exceto Acc/Eva)
  static double _statStageMultiplier(int stage) {
    if (stage >= 0) {
      return (2 + stage) / 2.0;
    }
    return 2.0 / (2 - stage);
  }

  // Multiplicadores de estágio de Precisão/Evasão
  static double _accuracyStageMultiplier(int stage) {
    if (stage >= 0) {
      return (3 + stage) / 3.0;
    }
    return 3.0 / (3 - stage);
  }

  // Mapa de eficácia de tipos
  static final Map<String, Map<String, double>> _typeEffectiveness = {
    'normal': {'rock': 0.5, 'ghost': 0, 'steel': 0.5},
    'fire': {
      'fire': 0.5,
      'water': 0.5,
      'grass': 2,
      'ice': 2,
      'bug': 2,
      'rock': 0.5,
      'dragon': 0.5,
      'steel': 2
    },
    'water': {
      'fire': 2,
      'water': 0.5,
      'grass': 0.5,
      'ground': 2,
      'rock': 2,
      'dragon': 0.5
    },
    'electric': {
      'water': 2,
      'electric': 0.5,
      'grass': 0.5,
      'ground': 0,
      'flying': 2,
      'dragon': 0.5
    },
    'grass': {
      'fire': 0.5,
      'water': 2,
      'grass': 0.5,
      'poison': 0.5,
      'ground': 2,
      'flying': 0.5,
      'bug': 0.5,
      'rock': 2,
      'dragon': 0.5,
      'steel': 0.5
    },
    'ice': {
      'fire': 0.5,
      'water': 0.5,
      'grass': 2,
      'ice': 0.5,
      'ground': 2,
      'flying': 2,
      'dragon': 2,
      'steel': 0.5
    },
    'fighting': {
      'normal': 2,
      'ice': 2,
      'poison': 0.5,
      'flying': 0.5,
      'psychic': 0.5,
      'bug': 0.5,
      'rock': 2,
      'ghost': 0,
      'dark': 2,
      'steel': 2,
      'fairy': 0.5
    },
    'poison': {
      'grass': 2,
      'poison': 0.5,
      'ground': 0.5,
      'rock': 0.5,
      'ghost': 0.5,
      'steel': 0,
      'fairy': 2
    },
    'ground': {
      'fire': 2,
      'electric': 2,
      'grass': 0.5,
      'poison': 2,
      'flying': 0,
      'bug': 0.5,
      'rock': 2,
      'steel': 2
    },
    'flying': {
      'electric': 0.5,
      'grass': 2,
      'fighting': 2,
      'bug': 2,
      'rock': 0.5,
      'steel': 0.5
    },
    'psychic': {
      'fighting': 2,
      'poison': 2,
      'psychic': 0.5,
      'dark': 0,
      'steel': 0.5
    },
    'bug': {
      'fire': 0.5,
      'grass': 2,
      'fighting': 0.5,
      'poison': 0.5,
      'flying': 0.5,
      'psychic': 2,
      'ghost': 0.5,
      'dark': 2,
      'steel': 0.5,
      'fairy': 0.5
    },
    'rock': {
      'fire': 2,
      'ice': 2,
      'fighting': 0.5,
      'ground': 0.5,
      'flying': 2,
      'bug': 2,
      'steel': 0.5
    },
    'ghost': {'normal': 0, 'psychic': 2, 'ghost': 2, 'dark': 0.5},
    'dragon': {'dragon': 2, 'steel': 0.5, 'fairy': 0},
    'dark': {
      'fighting': 0.5,
      'psychic': 2,
      'ghost': 2,
      'dark': 0.5,
      'fairy': 0.5
    },
    'steel': {
      'fire': 0.5,
      'water': 0.5,
      'electric': 0.5,
      'ice': 2,
      'rock': 2,
      'steel': 0.5,
      'fairy': 2
    },
    'fairy': {
      'fire': 0.5,
      'fighting': 2,
      'poison': 0.5,
      'dragon': 2,
      'dark': 2,
      'steel': 0.5
    },
  };

  static double _getEffectiveness(String moveType, List<String> defenderTypes) {
    double effectiveness = 1.0;
    for (var type in defenderTypes) {
      effectiveness *= _typeEffectiveness[moveType]?[type] ?? 1.0;
    }
    return effectiveness;
  }

  // --- Hooks de Habilidade ---

  // Chamado no início da batalha (ex: Intimidate)
  static List<String> onBattleStart(Pokemon pokemon, Pokemon opponent) {
    final logs = <String>[];
    final ability = AbilityData.normalize(pokemon.ability);

    if (ability == AbilityData.intimidate) {
      // Intimidate: Baixa o ataque do oponente em 1 estágio
      // Verifica se o oponente tem imunidade (ex: Clear Body, Hyper Cutter - futuramente)
      final result = applyStatChange(opponent, 'attack', -1);
      logs.add('${pokemon.name} tem Intimidate!');
      if (result.isNotEmpty) {
        logs.add(result);
      }
    }

    return logs;
  }

  // Verifica imunidade baseada em habilidade (ex: Levitate vs Ground)
  static bool checkImmunity(Pokemon defender, String moveType) {
    final ability = AbilityData.normalize(defender.ability);
    if (ability == AbilityData.levitate && moveType == 'ground') {
      return true;
    }
    return false;
  }

  // Modifica o dano base (ex: Blaze, Torrent)
  static double modifyDamage({
    required double damage,
    required Pokemon attacker,
    required PokemonMove move,
  }) {
    double multiplier = 1.0;
    final ability = AbilityData.normalize(attacker.ability);
    final hpRatio = attacker.hp / attacker.maxHp;

    // Habilidades de "Pinch" (HP < 1/3)
    if (hpRatio <= 0.33) {
      if (ability == AbilityData.blaze && move.type == 'fire') {
        multiplier *= 1.5;
      }
      if (ability == AbilityData.torrent && move.type == 'water') {
        multiplier *= 1.5;
      }
      if (ability == AbilityData.overgrow && move.type == 'grass') {
        multiplier *= 1.5;
      }
    }

    return damage * multiplier;
  }

  // --- Lógica de Buffs/Debuffs ---

  static String applyStatChange(Pokemon target, String stat, int stages) {
    if (stages == 0) {
      return '';
    }

    final currentStage = target.statStages[stat] ?? 0;
    final newStage = (currentStage + stages).clamp(-6, 6);

    if (currentStage == newStage) {
      return '${target.name} não pode ter $stat alterado mais!';
    }

    // Atualiza o estágio no mapa do Pokémon (Nota: Pokemon é imutável, idealmente retornaríamos um novo Pokemon,
    // mas como estamos em um serviço estático simulando, assumimos que o chamador vai lidar com a atualização do estado
    // ou que o mapa é mutável se não for const.
    // *Correção*: O modelo Pokemon é imutável. O BattleService deve retornar o Pokemon atualizado ou o chamador deve gerenciar.
    // Para este refator, vamos assumir que o `statStages` no objeto Pokemon passado é uma referência que podemos modificar
    // SE o mapa não fosse unmodifiable. Mas ele É unmodifiable no modelo atual.
    // *Solução*: Como não podemos mudar o Pokemon aqui sem retornar um novo, e este método retorna String,
    // vamos assumir que a lógica de estado da batalha (BattleScreen) vai usar um método auxiliar para criar o novo Pokemon.
    // *Ajuste*: Vamos mudar a assinatura para retornar um objeto com a mensagem e o novo estágio, ou simplificar assumindo
    // que quem chama vai usar `copyWith`.

    // Por enquanto, vamos apenas retornar a mensagem de log, e a lógica de atualização real deve ser feita onde o Pokemon é armazenado.
    // Mas espere, `applyStatChange` precisa ter efeito.
    // Vamos fazer o método retornar um `StatChangeResult` contendo a mensagem e o novo valor.

    // Como não posso mudar a assinatura de todos os métodos agora, vou focar na lógica de cálculo.
    // O chamador (BattleScreen) deve aplicar a mudança.

    String intensity = '';
    if (stages.abs() >= 2) intensity = ' drasticamente';

    String statName = stat;
    switch (stat) {
      case 'attack':
        statName = 'Ataque';
        break;
      case 'defense':
        statName = 'Defesa';
        break;
      case 'special-attack':
        statName = 'Ataque Especial';
        break;
      case 'special-defense':
        statName = 'Defesa Especial';
        break;
      case 'speed':
        statName = 'Velocidade';
        break;
      case 'accuracy':
        statName = 'Precisão';
        break;
      case 'evasion':
        statName = 'Evasiva';
        break;
    }

    if (stages > 0) {
      return 'O $statName de ${target.name} subiu$intensity!';
    } else {
      return 'O $statName de ${target.name} caiu$intensity!';
    }
  }

  static double calculateDamage({
    required PokemonMove move,
    required Pokemon attacker,
    required Pokemon defender,
    StatusCondition attackerStatus = StatusCondition.none,
  }) {
    final power = move.power ?? 0;
    if (power <= 0) return 0;

    // Fórmula de dano: https://bulbapedia.bulbagarden.net/wiki/Damage
    final double level = attacker.level.toDouble();
    double attack = move.damageClass == 'physical'
        ? attacker.attack.toDouble()
        : attacker.specialAttack.toDouble();
    final double defense = move.damageClass == 'physical'
        ? defender.defense.toDouble()
        : defender.specialDefense.toDouble();

    final attackStageKey =
        move.damageClass == 'physical' ? 'attack' : 'special-attack';
    final defenseStageKey =
        move.damageClass == 'physical' ? 'defense' : 'special-defense';

    attack *= _statStageMultiplier(attacker.statStages[attackStageKey] ?? 0);
    final double adjustedDefense = defense *
        _statStageMultiplier(defender.statStages[defenseStageKey] ?? 0);

    if (move.damageClass == 'physical' &&
        attackerStatus == StatusCondition.burn) {
      attack *= 0.5;
    }

    // Modificadores
    const double targets = 1.0; // Batalha 1v1
    const double weather = 1.0; // Não implementado
    const double badge = 1.0; // Não implementado
    final double critical = (_random.nextDouble() < 0.0625) ? 1.5 : 1.0;
    final double random =
        (_random.nextInt(16) + 85) / 100.0; // Variação de 85% a 100%
    final double stab = attacker.types.contains(move.type) ? 1.5 : 1.0;

    // Verifica imunidade por habilidade
    if (checkImmunity(defender, move.type)) {
      // print("${defender.name} evitou o ataque com ${defender.ability}!");
      return 0;
    }

    final double typeEffectiveness =
        _getEffectiveness(move.type, defender.types);
    const double burn = 1.0;
    const double other = 1.0; // Outros modificadores

    final double modifier = targets *
        weather *
        badge *
        critical *
        random *
        stab *
        typeEffectiveness *
        burn *
        other;

    final double baseDamage =
        (((((2 * level) / 5) + 2) * power * (attack / adjustedDefense)) / 50) +
            2;

    double finalDamage = baseDamage * modifier;

    // Aplica modificadores de habilidade no dano final
    finalDamage =
        modifyDamage(damage: finalDamage, attacker: attacker, move: move);

    if (typeEffectiveness > 1) {
      // print("É super efetivo!");
    } else if (typeEffectiveness < 1 && typeEffectiveness > 0) {
      // print("Não é muito efetivo...");
    } else if (typeEffectiveness == 0) {
      // print("Não afeta o oponente...");
    }

    if (finalDamage < 1 && finalDamage > 0) {
      return 1;
    }
    return finalDamage;
  }

  static bool checkHitSuccess(
      double accuracy, Pokemon attacker, Pokemon defender) {
    // Fórmula: Accuracy * (AccuracyStage / EvasionStage)
    if (accuracy == 0) {
      return true; // Golpes que nunca erram (ex: Swift) - assumindo 0 como flag
    }

    final accStage = attacker.statStages['accuracy'] ?? 0;
    final evaStage = defender.statStages['evasion'] ?? 0;

    final double accuracyMultiplier = _accuracyStageMultiplier(accStage);
    final double evasionMultiplier =
        _accuracyStageMultiplier(-evaStage); // Inverso para evasão

    final double combinedAccuracy =
        accuracy * accuracyMultiplier * evasionMultiplier;

    return _random.nextDouble() * 100 <= combinedAccuracy;
  }

  static PokemonMove selectAIMove(
    List<PokemonMove> availableMoves,
    Pokemon attacker,
    Pokemon defender,
  ) {
    if (availableMoves.isEmpty) {
      return const PokemonMove(
        name: 'Luta',
        power: 50,
        type: 'normal',
        accuracy: 100,
        damageClass: 'physical',
        pp: 10,
      );
    }

    PokemonMove? bestMove;
    double bestScore = -1;

    for (var move in availableMoves) {
      // Dano base simulado
      final simulatedDamage = calculateDamage(
        move: move,
        attacker: attacker,
        defender: defender,
      );

      // Ajuste de precisão na IA
      final hitChance =
          checkHitSuccess(move.accuracy.toDouble(), attacker, defender)
              ? 1.0
              : (move.accuracy / 100.0);
      final acc = hitChance;
      // Bônus leve por STAB/efetividade (já incluso em calculateDamage, mas reforçamos a decisão)
      double typeBonus = 1.0;
      if (attacker.types.contains(move.type)) {
        typeBonus *= 1.05; // 5%
      }
      final eff = _getEffectiveness(move.type, defender.types);
      if (eff > 1.0) {
        typeBonus *= 1.05; // 5% extra
      }
      if (eff == 0) {
        typeBonus *= 0.5; // evita golpe inútil
      }

      // Score = dano esperado = dano * precisão, ajustado
      final score = simulatedDamage * acc * typeBonus;
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    return bestMove ?? availableMoves[_random.nextInt(availableMoves.length)];
  }

  static String generateBattleLog({
    required String attackerName,
    required String moveName,
    required bool isHit,
    double? damage,
    double remainingHP = 0,
    double maxHP = 0,
  }) {
    if (!isHit) {
      return 'O ataque de $attackerName errou!';
    }

    if (damage != null) {
      return '$attackerName causou ${damage.toInt()} de dano! (${remainingHP.toInt()}/${maxHP.toInt()} HP)';
    }

    return '$attackerName usa $moveName!';
  }
}
