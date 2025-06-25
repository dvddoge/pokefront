import 'package:flutter/material.dart';
import '../models/opponent.dart';
import '../models/tournament_reward.dart';
import '../models/tournament_progress.dart';

class TournamentService {
  static List<Opponent> getTournamentOpponents() {
    return [
      // Rodada 1: Quartas de Final
      Opponent(
        name: 'Brawly',
        title: 'Lutador de Ondas',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/3/39/Ruby_Sapphire_Brawly.png/200px-Ruby_Sapphire_Brawly.png',
        pokemonId: 257, // Blaziken
        pokemonLevel: 55,
      ),
      // Rodada 2: Semifinal
      Opponent(
        name: 'Elesa',
        title: 'Modelo Eletrizante',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/5/5f/Black_2_White_2_Elesa.png/200px-Black_2_White_2_Elesa.png',
        pokemonId: 604, // Eelektross
        pokemonLevel: 65,
      ),
      // Rodada 3: Final
      Opponent(
        name: 'Cynthia',
        title: 'Campeã de Sinnoh',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/3/3b/Diamond_Pearl_Cynthia.png/200px-Diamond_Pearl_Cynthia.png',
        pokemonId: 445, // Garchomp
        pokemonLevel: 78,
      ),
    ];
  }

  // Calcula pontuação baseada na dificuldade do oponente
  static int calculateBattleScore({
    required int opponentLevel,
    required int playerLevel,
    required Duration battleTime,
    required bool playerWon,
  }) {
    if (!playerWon) return 0;

    int baseScore = 1000;
    
    // Bônus por diferença de nível (mais pontos se oponente for mais forte)
    int levelDifference = opponentLevel - playerLevel;
    int levelBonus = levelDifference > 0 ? levelDifference * 50 : 0;
    
    // Bônus por velocidade (menos tempo = mais pontos)
    int timeBonus = battleTime.inSeconds < 60 
        ? (60 - battleTime.inSeconds) * 10 
        : 0;
    
    return baseScore + levelBonus + timeBonus;
  }

  // Determina a medalha baseada na performance
  static MedalType? calculateMedal({
    required int totalScore,
    required Duration totalTime,
    required bool tournamentCompleted,
  }) {
    if (!tournamentCompleted) return null;

    // Critérios para medalhas
    if (totalScore >= 4000 && totalTime.inMinutes <= 15) {
      return MedalType.platinum;
    } else if (totalScore >= 3000 && totalTime.inMinutes <= 20) {
      return MedalType.gold;
    } else if (totalScore >= 2000 && totalTime.inMinutes <= 30) {
      return MedalType.silver;
    } else {
      return MedalType.bronze;
    }
  }

  // Lista de todas as recompensas disponíveis
  static List<TournamentReward> getAllRewards() {
    return [
      // Medalhas
      const TournamentReward(
        id: 'medal_bronze',
        name: 'Medalha de Bronze',
        description: 'Complete seu primeiro torneio',
        type: RewardType.medal,
        medalType: MedalType.bronze,
        pointsValue: 100,
      ),
      const TournamentReward(
        id: 'medal_silver',
        name: 'Medalha de Prata',
        description: 'Complete o torneio com boa performance',
        type: RewardType.medal,
        medalType: MedalType.silver,
        pointsValue: 250,
      ),
      const TournamentReward(
        id: 'medal_gold',
        name: 'Medalha de Ouro',
        description: 'Complete o torneio com excelente performance',
        type: RewardType.medal,
        medalType: MedalType.gold,
        pointsValue: 500,
      ),
      const TournamentReward(
        id: 'medal_platinum',
        name: 'Medalha de Platina',
        description: 'Performance perfeita no torneio',
        type: RewardType.medal,
        medalType: MedalType.platinum,
        pointsValue: 1000,
      ),
      
      // Recompensas especiais por conquistas
      const TournamentReward(
        id: 'first_victory',
        name: 'Primeira Vitória',
        description: 'Vença sua primeira batalha no torneio',
        type: RewardType.points,
        pointsValue: 50,
      ),
      const TournamentReward(
        id: 'speed_demon',
        name: 'Demônio da Velocidade',
        description: 'Complete o torneio em menos de 10 minutos',
        type: RewardType.points,
        pointsValue: 300,
      ),
      const TournamentReward(
        id: 'perfect_run',
        name: 'Execução Perfeita',
        description: 'Vença todas as batalhas com pontuação máxima',
        type: RewardType.points,
        pointsValue: 500,
      ),
      const TournamentReward(
        id: 'champion_streak',
        name: 'Sequência de Campeão',
        description: 'Vença 5 torneios consecutivos',
        type: RewardType.points,
        pointsValue: 750,
      ),
    ];
  }

  // Calcula recompensas ganhas baseado na performance
  static List<TournamentReward> calculateEarnedRewards({
    required TournamentProgress progress,
    required TournamentStats stats,
  }) {
    List<TournamentReward> earnedRewards = [];
    final allRewards = getAllRewards();

    // Medalha principal
    if (progress.earnedMedal != null) {
      final medalReward = allRewards.firstWhere(
        (r) => r.medalType == progress.earnedMedal,
        orElse: () => allRewards.first,
      );
      earnedRewards.add(medalReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Primeira vitória
    if (stats.battlesWon >= 1) {
      final firstVictory = allRewards.firstWhere((r) => r.id == 'first_victory');
      earnedRewards.add(firstVictory.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Velocidade (menos de 10 minutos)
    if (progress.isCompleted && progress.totalTime.inMinutes < 10) {
      final speedReward = allRewards.firstWhere((r) => r.id == 'speed_demon');
      earnedRewards.add(speedReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Execução perfeita (pontuação máxima em todas as batalhas)
    if (progress.isCompleted && progress.battleScores.every((score) => score >= 1500)) {
      final perfectReward = allRewards.firstWhere((r) => r.id == 'perfect_run');
      earnedRewards.add(perfectReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    return earnedRewards;
  }

  // Converte medalha para cor
  static Color getMedalColor(MedalType medalType) {
    switch (medalType) {
      case MedalType.bronze:
        return const Color(0xFFCD7F32);
      case MedalType.silver:
        return const Color(0xFFC0C0C0);
      case MedalType.gold:
        return const Color(0xFFFFD700);
      case MedalType.platinum:
        return const Color(0xFFE5E4E2);
    }
  }

  // Converte medalha para ícone
  static String getMedalIcon(MedalType medalType) {
    switch (medalType) {
      case MedalType.bronze:
        return '🥉';
      case MedalType.silver:
        return '🥈';
      case MedalType.gold:
        return '🥇';
      case MedalType.platinum:
        return '💎';
    }
  }
} 