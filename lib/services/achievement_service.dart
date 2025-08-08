import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/achievement.dart';
import '../models/tournament_progress.dart';

class AchievementService {
  static const String _progressKey = 'achievements_progress_v1';
  static const String _trainerKey = 'trainer_meta_progress_v1';

  // Definitions: creative, motivating variety
  static List<AchievementDefinition> get definitions => const [
        // Daily goals
        AchievementDefinition(
          id: 'daily_win_1',
          name: 'Aquecimento Diário',
          description: 'Vença 1 batalha hoje',
          category: AchievementCategory.daily,
          reset: AchievementReset.daily,
          target: 1,
          points: 50,
          tier: AchievementTier.bronze,
        ),
        AchievementDefinition(
          id: 'daily_win_3',
          name: 'Ritmo de Batalha',
          description: 'Vença 3 batalhas hoje',
          category: AchievementCategory.daily,
          reset: AchievementReset.daily,
          target: 3,
          points: 120,
          tier: AchievementTier.silver,
        ),

        // Streaks
        AchievementDefinition(
          id: 'streak_3',
          name: 'Embalado',
          description: 'Vença 3 batalhas seguidas',
          category: AchievementCategory.streak,
          target: 3,
          points: 150,
          tier: AchievementTier.bronze,
        ),
        AchievementDefinition(
          id: 'streak_5',
          name: 'Fogo no Pé',
          description: 'Vença 5 batalhas seguidas',
          category: AchievementCategory.streak,
          target: 5,
          points: 300,
          tier: AchievementTier.silver,
        ),

        // Milestones
        AchievementDefinition(
          id: 'milestone_10_wins',
          name: 'Competidor',
          description: 'Some 10 vitórias totais',
          category: AchievementCategory.milestone,
          target: 10,
          points: 200,
          tier: AchievementTier.bronze,
        ),
        AchievementDefinition(
          id: 'milestone_50_wins',
          name: 'Veterano',
          description: 'Some 50 vitórias totais',
          category: AchievementCategory.milestone,
          target: 50,
          points: 800,
          tier: AchievementTier.gold,
        ),
        AchievementDefinition(
          id: 'milestone_5_tournaments',
          name: 'Maratonista',
          description: 'Conclua 5 torneios',
          category: AchievementCategory.milestone,
          target: 5,
          points: 700,
          tier: AchievementTier.silver,
        ),

        // Skill challenges
        AchievementDefinition(
          id: 'skill_fast_victory',
          name: 'Abatedor Relâmpago',
          description: 'Vença uma batalha em menos de 60s',
          category: AchievementCategory.skill,
          target: 1,
          points: 250,
          tier: AchievementTier.silver,
        ),
        AchievementDefinition(
          id: 'skill_no_damage',
          name: 'Intocável',
          description: 'Vença sem sofrer dano (em uma batalha)',
          category: AchievementCategory.skill,
          target: 1,
          points: 400,
          tier: AchievementTier.gold,
        ),
      ];

  // Load/save
  static Future<Map<String, AchievementProgress>> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_progressKey);
    if (raw == null) return {};
    final map = json.decode(raw) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, AchievementProgress.fromJson(v)));
  }

  static Future<void> _saveProgress(Map<String, AchievementProgress> progress) async {
    final prefs = await SharedPreferences.getInstance();
    final map = progress.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_progressKey, json.encode(map));
  }

  static Future<TrainerMetaProgress> loadTrainer() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_trainerKey);
    if (raw == null) return const TrainerMetaProgress();
    return TrainerMetaProgress.fromJson(json.decode(raw));
  }

  static Future<void> _saveTrainer(TrainerMetaProgress trainer) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_trainerKey, json.encode(trainer.toJson()));
  }

  // Helpers
  static String _todayKey(DateTime now) =>
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  // Helper removed (unused)

  // Public API
  static Future<List<AchievementDefinition>> getDaily() async =>
      definitions.where((d) => d.category == AchievementCategory.daily).toList();

  static Future<Map<String, AchievementProgress>> getAllProgress() => _loadProgress();

  // Call on battle end to update progress (victory/defeat).
  // Provide minimal context flags to track skill checks.
  static Future<List<AchievementDefinition>> onBattleFinished({
    required bool playerWon,
    required Duration battleTime,
    int damageTaken = 1,
  }) async {
    final now = DateTime.now();
    final today = _todayKey(now);
    final defs = definitions;
    final progress = await _loadProgress();
    final newlyUnlocked = <AchievementDefinition>[];

    void inc(String id, {int by = 1, bool unlockIfReached = true}) {
      final def = defs.firstWhere((d) => d.id == id);
      final p = progress[id] ?? AchievementProgress(id: id);

      // Reset dailies if day changed
      final needsReset = def.reset == AchievementReset.daily && p.lastCompletionDay != today;
      final currentVal = needsReset ? 0 : p.current;

      final updated = p.copyWith(
        current: currentVal + by,
        lastCompletionDay: def.reset == AchievementReset.daily ? today : p.lastCompletionDay,
      );
      progress[id] = updated;

      if (unlockIfReached && updated.current >= def.target && !(updated.unlocked)) {
        // mark unlocked for dailies (today), others permanent
        final unlock = updated.copyWith(unlocked: true, unlockedAt: now);
        progress[id] = unlock;
        newlyUnlocked.add(def);
      }
    }

    // Daily wins and streak logic
    if (playerWon) {
      inc('daily_win_1');
      inc('daily_win_3');
    }

    // Streaks tracked via consecutive wins in TournamentStats externally; here, we use a rolling counter
    final streakId = 'streak_counter_internal';
    final streak = progress[streakId]?.current ?? 0;
    final newStreak = playerWon ? streak + 1 : 0;
    progress[streakId] = AchievementProgress(id: streakId, current: newStreak);
    if (newStreak >= 3) inc('streak_3', unlockIfReached: true, by: 0);
    if (newStreak >= 5) inc('streak_5', unlockIfReached: true, by: 0);

    // Milestones are derived from cumulative stats stored elsewhere; we expose explicit increment helpers below

    // Skill checks
    if (playerWon && battleTime.inSeconds < 60) {
      inc('skill_fast_victory');
    }
    if (playerWon && damageTaken == 0) {
      inc('skill_no_damage');
    }

    // Award XP for newly unlocked
    if (newlyUnlocked.isNotEmpty) {
      var trainer = await loadTrainer();
      final xp = newlyUnlocked.fold<int>(0, (sum, d) => sum + d.points);
      trainer = trainer.copyWith(totalXp: trainer.totalXp + xp);
      await _saveTrainer(trainer);
    }

    await _saveProgress(progress);
    return newlyUnlocked;
  }

  // Update cumulative milestones when stats change
  static Future<List<AchievementDefinition>> onStatsUpdated(TournamentStats stats) async {
    final progress = await _loadProgress();
    final defs = definitions;
    final unlocked = <AchievementDefinition>[];

    AchievementDefinition? check(String id, bool condition) {
      final def = defs.firstWhere((d) => d.id == id);
      final p = progress[id] ?? AchievementProgress(id: id);
      if (!p.unlocked && condition) {
        progress[id] = p.copyWith(unlocked: true, unlockedAt: DateTime.now(), current: def.target);
        unlocked.add(def);
      }
      return def;
    }

    check('milestone_10_wins', stats.battlesWon >= 10);
    check('milestone_50_wins', stats.battlesWon >= 50);
    check('milestone_5_tournaments', stats.totalTournaments >= 5);

    if (unlocked.isNotEmpty) {
      // XP
      var trainer = await loadTrainer();
      final xp = unlocked.fold<int>(0, (sum, d) => sum + d.points);
      trainer = trainer.copyWith(totalXp: trainer.totalXp + xp);
      await _saveTrainer(trainer);
      await _saveProgress(progress);
    }

    return unlocked;
  }
}
