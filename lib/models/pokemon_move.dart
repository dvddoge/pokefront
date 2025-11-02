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
    );
  }
}
