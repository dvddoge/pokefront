import 'dart:math' as math;
import '../../../models/pokemon.dart';
import '../../../models/pokemon_move.dart';

class BattleService {
  static double calculateDamage(PokemonMove move) {
    return move.damage;
  }

  static bool checkHitSuccess(double accuracy) {
    return math.Random().nextDouble() * 100 <= accuracy;
  }

  static PokemonMove selectAIMove(
    List<PokemonMove> availableMoves,
    double attackerHP,
    double defenderHP,
    double attackerMaxHP,
  ) {
    if (defenderHP <= 20) {
      // Se o HP do oponente estiver baixo, prioriza ataques mais fortes
      return availableMoves.reduce((a, b) => a.damage > b.damage ? a : b);
    } else if (attackerHP <= 35) {
      // Se o jogador estiver com pouco HP, tenta finalizar com um ataque forte
      var forteMoves = availableMoves.where((move) => move.damage >= 35).toList();
      return forteMoves.isEmpty 
          ? availableMoves[math.Random().nextInt(availableMoves.length)]
          : forteMoves[math.Random().nextInt(forteMoves.length)];
    } else if (attackerHP >= attackerMaxHP * 0.7) {
      // Se estiver com bastante HP, usa ataques mais precisos
      var preciseMoves = availableMoves.where((move) => move.accuracy >= 90).toList();
      return preciseMoves.isEmpty
          ? availableMoves[math.Random().nextInt(availableMoves.length)]
          : preciseMoves[math.Random().nextInt(preciseMoves.length)];
    } else {
      // Caso contrário, escolhe um movimento aleatório
      return availableMoves[math.Random().nextInt(availableMoves.length)];
    }
  }

  static String generateBattleLog({
    required String attackerName,
    required String moveName,
    required bool isHit,
    double? damage,
    double? remainingHP,
    double? maxHP,
  }) {
    if (!isHit) {
      return 'O ataque de $attackerName errou!';
    }

    if (damage != null && remainingHP != null && maxHP != null) {
      return '$attackerName causou ${damage.toInt()} de dano! (${remainingHP.toInt()}/${maxHP.toInt()} HP)';
    }

    return '$attackerName usa $moveName!';
  }
} 