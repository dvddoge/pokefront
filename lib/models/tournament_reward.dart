enum MedalType {
  bronze,
  silver,
  gold,
  platinum,
}

enum RewardType {
  medal,
  pokemon,
  item,
  points,
}

class TournamentReward {
  final String id;
  final String name;
  final String description;
  final RewardType type;
  final MedalType? medalType;
  final String? imageUrl;
  final int pointsValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const TournamentReward({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.medalType,
    this.imageUrl,
    this.pointsValue = 0,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  TournamentReward copyWith({
    String? id,
    String? name,
    String? description,
    RewardType? type,
    MedalType? medalType,
    String? imageUrl,
    int? pointsValue,
    bool? isUnlocked,
    DateTime? unlockedAt,
  }) {
    return TournamentReward(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      medalType: medalType ?? this.medalType,
      imageUrl: imageUrl ?? this.imageUrl,
      pointsValue: pointsValue ?? this.pointsValue,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'medalType': medalType?.name,
      'imageUrl': imageUrl,
      'pointsValue': pointsValue,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt?.millisecondsSinceEpoch,
    };
  }

  factory TournamentReward.fromJson(Map<String, dynamic> json) {
    return TournamentReward(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      type: RewardType.values.firstWhere((e) => e.name == json['type']),
      medalType: json['medalType'] != null 
          ? MedalType.values.firstWhere((e) => e.name == json['medalType'])
          : null,
      imageUrl: json['imageUrl'],
      pointsValue: json['pointsValue'] ?? 0,
      isUnlocked: json['isUnlocked'] ?? false,
      unlockedAt: json['unlockedAt'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['unlockedAt'])
          : null,
    );
  }
} 