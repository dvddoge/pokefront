enum AchievementCategory {
  daily,
  streak,
  milestone,
  skill,
}

enum AchievementReset {
  none,
  daily,
  weekly,
}

enum AchievementTier {
  bronze,
  silver,
  gold,
  platinum,
}

class AchievementDefinition {
  final String id;
  final String name;
  final String description;
  final AchievementCategory category;
  final AchievementReset reset;
  final int target; // target count/time/score depending on context
  final int points; // XP awarded when unlocked
  final AchievementTier? tier; // optional tier label

  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.reset = AchievementReset.none,
    required this.target,
    this.points = 0,
    this.tier,
  });
}

class AchievementProgress {
  final String id;
  final int current; // current progress towards target
  final bool unlocked; // whether achievement unlocked (for daily, refers to today)
  final DateTime? unlockedAt;
  final String? lastCompletionDay; // yyyy-MM-dd for dailies

  const AchievementProgress({
    required this.id,
    this.current = 0,
    this.unlocked = false,
    this.unlockedAt = null,
    this.lastCompletionDay,
  });

  AchievementProgress copyWith({
    int? current,
    bool? unlocked,
    DateTime? unlockedAt,
    String? lastCompletionDay,
  }) {
    return AchievementProgress(
      id: id,
      current: current ?? this.current,
      unlocked: unlocked ?? this.unlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      lastCompletionDay: lastCompletionDay ?? this.lastCompletionDay,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'current': current,
        'unlocked': unlocked,
        'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
        'lastCompletionDay': lastCompletionDay,
      };

  factory AchievementProgress.fromJson(Map<String, dynamic> json) => AchievementProgress(
        id: json['id'],
        current: json['current'] ?? 0,
        unlocked: json['unlocked'] ?? false,
        unlockedAt: json['unlockedAt'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['unlockedAt'])
            : null,
        lastCompletionDay: json['lastCompletionDay'],
      );
}

class TrainerMetaProgress {
  final int totalXp;

  const TrainerMetaProgress({this.totalXp = 0});

  int get level => (totalXp ~/ 1000) + 1; // 1000 XP por nível
  int get xpIntoLevel => totalXp % 1000;
  double get levelProgress => xpIntoLevel / 1000.0;

  TrainerMetaProgress copyWith({int? totalXp}) =>
      TrainerMetaProgress(totalXp: totalXp ?? this.totalXp);

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
      };

  factory TrainerMetaProgress.fromJson(Map<String, dynamic> json) =>
      TrainerMetaProgress(totalXp: json['totalXp'] ?? 0);
}
