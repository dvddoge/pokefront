import 'tournament_reward.dart';

class TournamentStats {
  final int battlesWon;
  final int battlesLost;
  final int totalTournaments;
  final int tournamentsWon;
  final Duration bestTime;
  final int highestScore;
  final int totalPoints;

  const TournamentStats({
    this.battlesWon = 0,
    this.battlesLost = 0,
    this.totalTournaments = 0,
    this.tournamentsWon = 0,
    this.bestTime = Duration.zero,
    this.highestScore = 0,
    this.totalPoints = 0,
  });

  TournamentStats copyWith({
    int? battlesWon,
    int? battlesLost,
    int? totalTournaments,
    int? tournamentsWon,
    Duration? bestTime,
    int? highestScore,
    int? totalPoints,
  }) {
    return TournamentStats(
      battlesWon: battlesWon ?? this.battlesWon,
      battlesLost: battlesLost ?? this.battlesLost,
      totalTournaments: totalTournaments ?? this.totalTournaments,
      tournamentsWon: tournamentsWon ?? this.tournamentsWon,
      bestTime: bestTime ?? this.bestTime,
      highestScore: highestScore ?? this.highestScore,
      totalPoints: totalPoints ?? this.totalPoints,
    );
  }

  double get winRate => battlesWon + battlesLost > 0 
      ? battlesWon / (battlesWon + battlesLost) 
      : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'battlesWon': battlesWon,
      'battlesLost': battlesLost,
      'totalTournaments': totalTournaments,
      'tournamentsWon': tournamentsWon,
      'bestTime': bestTime.inMilliseconds,
      'highestScore': highestScore,
      'totalPoints': totalPoints,
    };
  }

  factory TournamentStats.fromJson(Map<String, dynamic> json) {
    return TournamentStats(
      battlesWon: json['battlesWon'] ?? 0,
      battlesLost: json['battlesLost'] ?? 0,
      totalTournaments: json['totalTournaments'] ?? 0,
      tournamentsWon: json['tournamentsWon'] ?? 0,
      bestTime: Duration(milliseconds: json['bestTime'] ?? 0),
      highestScore: json['highestScore'] ?? 0,
      totalPoints: json['totalPoints'] ?? 0,
    );
  }
}

class TournamentProgress {
  final String tournamentId;
  final DateTime startTime;
  final DateTime? endTime;
  final int currentOpponentIndex;
  final int currentScore;
  final List<int> battleScores;
  final bool isCompleted;
  final MedalType? earnedMedal;
  final List<TournamentReward> earnedRewards;

  const TournamentProgress({
    required this.tournamentId,
    required this.startTime,
    this.endTime,
    this.currentOpponentIndex = 0,
    this.currentScore = 0,
    this.battleScores = const [],
    this.isCompleted = false,
    this.earnedMedal,
    this.earnedRewards = const [],
  });

  Duration get totalTime {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  TournamentProgress copyWith({
    String? tournamentId,
    DateTime? startTime,
    DateTime? endTime,
    int? currentOpponentIndex,
    int? currentScore,
    List<int>? battleScores,
    bool? isCompleted,
    MedalType? earnedMedal,
    List<TournamentReward>? earnedRewards,
  }) {
    return TournamentProgress(
      tournamentId: tournamentId ?? this.tournamentId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      currentOpponentIndex: currentOpponentIndex ?? this.currentOpponentIndex,
      currentScore: currentScore ?? this.currentScore,
      battleScores: battleScores ?? this.battleScores,
      isCompleted: isCompleted ?? this.isCompleted,
      earnedMedal: earnedMedal ?? this.earnedMedal,
      earnedRewards: earnedRewards ?? this.earnedRewards,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tournamentId': tournamentId,
      'startTime': startTime.millisecondsSinceEpoch,
      'endTime': endTime?.millisecondsSinceEpoch,
      'currentOpponentIndex': currentOpponentIndex,
      'currentScore': currentScore,
      'battleScores': battleScores,
      'isCompleted': isCompleted,
      'earnedMedal': earnedMedal?.name,
      'earnedRewards': earnedRewards.map((r) => r.toJson()).toList(),
    };
  }

  factory TournamentProgress.fromJson(Map<String, dynamic> json) {
    return TournamentProgress(
      tournamentId: json['tournamentId'],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
      endTime: json['endTime'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['endTime'])
          : null,
      currentOpponentIndex: json['currentOpponentIndex'] ?? 0,
      currentScore: json['currentScore'] ?? 0,
      battleScores: List<int>.from(json['battleScores'] ?? []),
      isCompleted: json['isCompleted'] ?? false,
      earnedMedal: json['earnedMedal'] != null 
          ? MedalType.values.firstWhere((e) => e.name == json['earnedMedal'])
          : null,
      earnedRewards: (json['earnedRewards'] as List? ?? [])
          .map((r) => TournamentReward.fromJson(r))
          .toList(),
    );
  }
} 