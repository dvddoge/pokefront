import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/opponent.dart';
import '../models/tournament_reward.dart';
import '../models/tournament_progress.dart';

class TournamentService {
  static const String _achievementsKey = 'tournament_achievements';
  static const String _statsKey = 'tournament_stats';

  static List<Opponent> getTournamentOpponents() {
    return [
      // Rodada 1: Quartas de Final
      Opponent(
        name: 'Brawly',
        title: 'Lutador de Ondas',
        avatarUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/257.png',
        pokemonId: 257, // Blaziken
        pokemonLevel: 55,
      ),
      // Rodada 2: Semifinal
      Opponent(
        name: 'Elesa',
        title: 'Modelo Eletrizante',
        avatarUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/604.png',
        pokemonId: 604, // Eelektross
        pokemonLevel: 65,
      ),
      // Rodada 3: Final
      Opponent(
        name: 'Cynthia',
        title: 'Campeã de Sinnoh',
        avatarUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/445.png',
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

    // Critérios ajustados para serem mais realistas
    if (totalScore >= 3500 && totalTime.inMinutes <= 10) {
      return MedalType.platinum;
    } else if (totalScore >= 2500 && totalTime.inMinutes <= 15) {
      return MedalType.gold;
    } else if (totalScore >= 2000 && totalTime.inMinutes <= 25) {
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
        description: 'Complete o torneio em menos de 15 minutos',
        type: RewardType.points,
        pointsValue: 300,
      ),
      const TournamentReward(
        id: 'perfect_run',
        name: 'Execução Perfeita',
        description: 'Vença todas as batalhas com pontuação alta',
        type: RewardType.points,
        pointsValue: 500,
      ),
      const TournamentReward(
        id: 'first_tournament',
        name: 'Primeiro Campeão',
        description: 'Complete seu primeiro torneio',
        type: RewardType.points,
        pointsValue: 200,
      ),
      const TournamentReward(
        id: 'quick_battles',
        name: 'Lutador Rápido',
        description: 'Vença 3 batalhas em menos de 2 minutos cada',
        type: RewardType.points,
        pointsValue: 150,
      ),
    ];
  }

  // Salva conquistas desbloqueadas
  static Future<void> saveUnlockedAchievements(List<TournamentReward> achievements) async {
    final prefs = await SharedPreferences.getInstance();
    final achievementsJson = achievements.map((a) => a.toJson()).toList();
    await prefs.setString(_achievementsKey, json.encode(achievementsJson));
  }

  // Carrega conquistas desbloqueadas
  static Future<List<TournamentReward>> loadUnlockedAchievements() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final achievementsString = prefs.getString(_achievementsKey);
      
      if (achievementsString != null) {
        final List<dynamic> achievementsJson = json.decode(achievementsString);
        return achievementsJson.map((json) => TournamentReward.fromJson(json)).toList();
      }
    } catch (e) {
      print('Erro ao carregar conquistas: $e');
    }
    
    return [];
  }

  // Salva estatísticas do jogador
  static Future<void> savePlayerStats(TournamentStats stats) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, json.encode(stats.toJson()));
  }

  // Carrega estatísticas do jogador
  static Future<TournamentStats> loadPlayerStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsString = prefs.getString(_statsKey);
      
      if (statsString != null) {
        final statsJson = json.decode(statsString);
        return TournamentStats.fromJson(statsJson);
      }
    } catch (e) {
      print('Erro ao carregar estatísticas: $e');
    }
    
    return const TournamentStats();
  }

  // Calcula recompensas ganhas baseado na performance
  static Future<List<TournamentReward>> calculateEarnedRewards({
    required TournamentProgress progress,
    required TournamentStats stats,
  }) async {
    List<TournamentReward> earnedRewards = [];
    final allRewards = getAllRewards();
    final existingAchievements = await loadUnlockedAchievements();
    
    // Verifica se já foi desbloqueada
    bool isAlreadyUnlocked(String id) {
      return existingAchievements.any((achievement) => achievement.id == id);
    }

    // Medalha principal (sempre adiciona se completou)
    if (progress.earnedMedal != null) {
      final medalReward = allRewards.firstWhere(
        (r) => r.medalType == progress.earnedMedal,
        orElse: () => allRewards.first,
      );
      
      if (!isAlreadyUnlocked(medalReward.id)) {
        earnedRewards.add(medalReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
      }
    }

    // Primeira vitória (se ganhou pelo menos 1 batalha)
    if (stats.battlesWon >= 1 && !isAlreadyUnlocked('first_victory')) {
      final firstVictory = allRewards.firstWhere((r) => r.id == 'first_victory');
      earnedRewards.add(firstVictory.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Primeiro torneio completo
    if (progress.isCompleted && !isAlreadyUnlocked('first_tournament')) {
      final firstTournament = allRewards.firstWhere((r) => r.id == 'first_tournament');
      earnedRewards.add(firstTournament.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Velocidade (menos de 15 minutos)
    if (progress.isCompleted && progress.totalTime.inMinutes < 15 && !isAlreadyUnlocked('speed_demon')) {
      final speedReward = allRewards.firstWhere((r) => r.id == 'speed_demon');
      earnedRewards.add(speedReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Execução perfeita (pontuação alta em todas as batalhas)
    if (progress.isCompleted && 
        progress.battleScores.isNotEmpty && 
        progress.battleScores.every((score) => score >= 1200) && 
        !isAlreadyUnlocked('perfect_run')) {
      final perfectReward = allRewards.firstWhere((r) => r.id == 'perfect_run');
      earnedRewards.add(perfectReward.copyWith(isUnlocked: true, unlockedAt: DateTime.now()));
    }

    // Salva as novas conquistas
    if (earnedRewards.isNotEmpty) {
      final allUnlocked = [...existingAchievements, ...earnedRewards];
      await saveUnlockedAchievements(allUnlocked);
    }

    return earnedRewards;
  }

  // Atualiza estatísticas do jogador
  static Future<void> updatePlayerStats({
    required bool tournamentCompleted,
    required bool battleWon,
    required Duration tournamentTime,
    required int tournamentScore,
  }) async {
    final currentStats = await loadPlayerStats();
    
    final updatedStats = currentStats.copyWith(
      battlesWon: battleWon ? currentStats.battlesWon + 1 : currentStats.battlesWon,
      battlesLost: !battleWon ? currentStats.battlesLost + 1 : currentStats.battlesLost,
      totalTournaments: tournamentCompleted ? currentStats.totalTournaments + 1 : currentStats.totalTournaments,
      tournamentsWon: tournamentCompleted && battleWon ? currentStats.tournamentsWon + 1 : currentStats.tournamentsWon,
      bestTime: tournamentCompleted && (currentStats.bestTime == Duration.zero || tournamentTime < currentStats.bestTime) 
          ? tournamentTime 
          : currentStats.bestTime,
      highestScore: tournamentScore > currentStats.highestScore ? tournamentScore : currentStats.highestScore,
      totalPoints: currentStats.totalPoints + (battleWon ? 100 : 0),
    );
    
    await savePlayerStats(updatedStats);
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