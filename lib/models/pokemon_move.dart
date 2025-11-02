class PokemonMove {
  final String name;
  final double? power;
  final String type;
  final double accuracy;
  final String damageClass;
  final int pp;
  final int priority;
  final String? ailment;
  final double ailmentChance;
  final Map<String, int> statChanges;
  final double? healPercent;
  final double? drain;
  final double? recoil;
  final int? minHits;
  final int? maxHits;
  final int? minTurns;
  final int? maxTurns;
  final double statChance;
  final double? flinchChance;
  final bool targetsSelf;

  const PokemonMove({
    required this.name,
    this.power,
    required this.type,
    required this.accuracy,
    required this.damageClass,
    this.pp = 20,
    this.priority = 0,
    this.ailment,
    this.ailmentChance = 0,
    this.statChanges = const {},
    this.healPercent,
    this.drain,
    this.recoil,
    this.minHits,
    this.maxHits,
    this.minTurns,
    this.maxTurns,
    this.statChance = 1.0,
    this.flinchChance,
    this.targetsSelf = false,
  });

  bool get isStatusMove => damageClass == 'status' || (power == null);

  PokemonMove copyWith({
    String? name,
    double? power,
    String? type,
    double? accuracy,
    String? damageClass,
    int? pp,
    int? priority,
    String? ailment,
    double? ailmentChance,
    Map<String, int>? statChanges,
    double? healPercent,
    double? drain,
    double? recoil,
    int? minHits,
    int? maxHits,
    int? minTurns,
    int? maxTurns,
    double? statChance,
    double? flinchChance,
    bool? targetsSelf,
  }) {
    return PokemonMove(
      name: name ?? this.name,
      power: power ?? this.power,
      type: type ?? this.type,
      accuracy: accuracy ?? this.accuracy,
      damageClass: damageClass ?? this.damageClass,
      pp: pp ?? this.pp,
      priority: priority ?? this.priority,
      ailment: ailment ?? this.ailment,
      ailmentChance: ailmentChance ?? this.ailmentChance,
      statChanges: statChanges ?? this.statChanges,
      healPercent: healPercent ?? this.healPercent,
      drain: drain ?? this.drain,
      recoil: recoil ?? this.recoil,
      minHits: minHits ?? this.minHits,
      maxHits: maxHits ?? this.maxHits,
      minTurns: minTurns ?? this.minTurns,
      maxTurns: maxTurns ?? this.maxTurns,
      statChance: statChance ?? this.statChance,
      flinchChance: flinchChance ?? this.flinchChance,
      targetsSelf: targetsSelf ?? this.targetsSelf,
    );
  }
}
