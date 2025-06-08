import 'dart:math' as math;
import '../../../models/pokemon.dart';
import '../../../models/pokemon_move.dart';

class BattleService {
  // Mapa de eficácia de tipos
  static final Map<String, Map<String, double>> _typeEffectiveness = {
    'normal': {'rock': 0.5, 'ghost': 0, 'steel': 0.5},
    'fire': {'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 2, 'bug': 2, 'rock': 0.5, 'dragon': 0.5, 'steel': 2},
    'water': {'fire': 2, 'water': 0.5, 'grass': 0.5, 'ground': 2, 'rock': 2, 'dragon': 0.5},
    'electric': {'water': 2, 'electric': 0.5, 'grass': 0.5, 'ground': 0, 'flying': 2, 'dragon': 0.5},
    'grass': {'fire': 0.5, 'water': 2, 'grass': 0.5, 'poison': 0.5, 'ground': 2, 'flying': 0.5, 'bug': 0.5, 'rock': 2, 'dragon': 0.5, 'steel': 0.5},
    'ice': {'fire': 0.5, 'water': 0.5, 'grass': 2, 'ice': 0.5, 'ground': 2, 'flying': 2, 'dragon': 2, 'steel': 0.5},
    'fighting': {'normal': 2, 'ice': 2, 'poison': 0.5, 'flying': 0.5, 'psychic': 0.5, 'bug': 0.5, 'rock': 2, 'ghost': 0, 'dark': 2, 'steel': 2, 'fairy': 0.5},
    'poison': {'grass': 2, 'poison': 0.5, 'ground': 0.5, 'rock': 0.5, 'ghost': 0.5, 'steel': 0, 'fairy': 2},
    'ground': {'fire': 2, 'electric': 2, 'grass': 0.5, 'poison': 2, 'flying': 0, 'bug': 0.5, 'rock': 2, 'steel': 2},
    'flying': {'electric': 0.5, 'grass': 2, 'fighting': 2, 'bug': 2, 'rock': 0.5, 'steel': 0.5},
    'psychic': {'fighting': 2, 'poison': 2, 'psychic': 0.5, 'dark': 0, 'steel': 0.5},
    'bug': {'fire': 0.5, 'grass': 2, 'fighting': 0.5, 'poison': 0.5, 'flying': 0.5, 'psychic': 2, 'ghost': 0.5, 'dark': 2, 'steel': 0.5, 'fairy': 0.5},
    'rock': {'fire': 2, 'ice': 2, 'fighting': 0.5, 'ground': 0.5, 'flying': 2, 'bug': 2, 'steel': 0.5},
    'ghost': {'normal': 0, 'psychic': 2, 'ghost': 2, 'dark': 0.5},
    'dragon': {'dragon': 2, 'steel': 0.5, 'fairy': 0},
    'dark': {'fighting': 0.5, 'psychic': 2, 'ghost': 2, 'dark': 0.5, 'fairy': 0.5},
    'steel': {'fire': 0.5, 'water': 0.5, 'electric': 0.5, 'ice': 2, 'rock': 2, 'steel': 0.5, 'fairy': 2},
    'fairy': {'fire': 0.5, 'fighting': 2, 'poison': 0.5, 'dragon': 2, 'dark': 2, 'steel': 0.5},
  };

  static double _getEffectiveness(String moveType, List<String> defenderTypes) {
    double effectiveness = 1.0;
    for (var type in defenderTypes) {
      effectiveness *= _typeEffectiveness[moveType]?[type] ?? 1.0;
    }
    return effectiveness;
  }

  static double calculateDamage(
    PokemonMove move,
    Pokemon attacker,
    Pokemon defender,
  ) {
    if (move.damage <= 0) return 0;

    // Fórmula de dano: https://bulbapedia.bulbagarden.net/wiki/Damage
    final double level = attacker.level.toDouble();
    final double power = move.damage.toDouble();
    final double attack = move.damageClass == 'physical' ? attacker.attack.toDouble() : attacker.specialAttack.toDouble();
    final double defense = move.damageClass == 'physical' ? defender.defense.toDouble() : defender.specialDefense.toDouble();
    
    // Modificadores
    const double targets = 1.0; // Batalha 1v1
    const double weather = 1.0; // Não implementado
    const double badge = 1.0;   // Não implementado
    final double critical = (math.Random().nextDouble() < 0.0625) ? 1.5 : 1.0;
    final double random = (math.Random().nextInt(16) + 85) / 100.0; // Variação de 85% a 100%
    final double stab = attacker.types.contains(move.type) ? 1.5 : 1.0; // Same-type attack bonus
    final double typeEffectiveness = _getEffectiveness(move.type, defender.types);
    const double burn = 1.0; // Não implementado
    const double other = 1.0; // Outros modificadores

    final double modifier = targets * weather * badge * critical * random * stab * typeEffectiveness * burn * other;

    final double damage = (((((2 * level) / 5) + 2) * power * (attack / defense)) / 50) + 2;
    
    final finalDamage = damage * modifier;

    if (typeEffectiveness > 1) {
      print("É super efetivo!");
    } else if (typeEffectiveness < 1 && typeEffectiveness > 0) {
      print("Não é muito efetivo...");
    } else if (typeEffectiveness == 0) {
      print("Não afeta o oponente...");
    }

    return finalDamage < 1 && finalDamage > 0 ? 1 : finalDamage;
  }

  static bool checkHitSuccess(double accuracy) {
    return math.Random().nextDouble() * 100 <= accuracy;
  }

  static PokemonMove selectAIMove(
    List<PokemonMove> availableMoves,
    Pokemon attacker,
    Pokemon defender,
  ) {
    if (availableMoves.isEmpty) {
      // Retorna um movimento padrão caso não hajam outros.
      return const PokemonMove(name: "Struggle", damage: 50, type: "normal", accuracy: 100, damageClass: "physical");
    }

    PokemonMove? bestMove;
    double maxDamage = -1;

    for (var move in availableMoves) {
      // Simula o dano para cada movimento
      final simulatedDamage = calculateDamage(move, attacker, defender);
      if (simulatedDamage > maxDamage) {
        maxDamage = simulatedDamage;
        bestMove = move;
      }
    }

    return bestMove ?? availableMoves[math.Random().nextInt(availableMoves.length)];
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