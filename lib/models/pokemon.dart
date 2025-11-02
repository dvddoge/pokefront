import 'dart:math' as math;

import 'status_condition.dart';

class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;
  final int level;
  final double hp;
  final double maxHp;
  final int attack;
  final int defense;
  final int specialAttack;
  final int specialDefense;
  final int speed;
  final double? heightMeters;
  final double? weightKg;
  final int baseHp;
  final int baseAttack;
  final int baseDefense;
  final int baseSpecialAttack;
  final int baseSpecialDefense;
  final int baseSpeed;
  final StatusCondition status;

  factory Pokemon({
    required int id,
    required String name,
    required String imageUrl,
    required List<String> types,
    int level = 50,
    double? hp,
    double? maxHp,
    int? attack,
    int? defense,
    int? specialAttack,
    int? specialDefense,
    int? speed,
    double? heightMeters,
    double? weightKg,
    int? baseHp,
    int? baseAttack,
    int? baseDefense,
    int? baseSpecialAttack,
    int? baseSpecialDefense,
    int? baseSpeed,
    StatusCondition status = StatusCondition.none,
  }) {
    final effectiveBaseHp = baseHp ?? maxHp?.toInt() ?? hp?.toInt() ?? 100;
    final effectiveBaseAttack = baseAttack ?? attack ?? 50;
    final effectiveBaseDefense = baseDefense ?? defense ?? 50;
    final effectiveBaseSpecialAttack = baseSpecialAttack ?? specialAttack ?? 50;
    final effectiveBaseSpecialDefense =
        baseSpecialDefense ?? specialDefense ?? 50;
    final effectiveBaseSpeed = baseSpeed ?? speed ?? 50;

    final computedMaxHp =
        (maxHp ?? _calculateHp(effectiveBaseHp, level)).toDouble();
    final computedHp =
        (hp ?? computedMaxHp).clamp(0, computedMaxHp).toDouble();
    final computedAttack =
        attack ?? _calculateOtherStat(effectiveBaseAttack, level);
    final computedDefense =
        defense ?? _calculateOtherStat(effectiveBaseDefense, level);
    final computedSpecialAttack =
        specialAttack ?? _calculateOtherStat(effectiveBaseSpecialAttack, level);
    final computedSpecialDefense = specialDefense ??
        _calculateOtherStat(effectiveBaseSpecialDefense, level);
    final computedSpeed =
        speed ?? _calculateOtherStat(effectiveBaseSpeed, level);

    return Pokemon._(
      id: id,
      name: name,
      imageUrl: imageUrl,
      types: List<String>.unmodifiable(types),
      level: level,
      hp: computedHp,
      maxHp: computedMaxHp,
      attack: computedAttack,
      defense: computedDefense,
      specialAttack: computedSpecialAttack,
      specialDefense: computedSpecialDefense,
      speed: computedSpeed,
      heightMeters: heightMeters,
      weightKg: weightKg,
      baseHp: effectiveBaseHp,
      baseAttack: effectiveBaseAttack,
      baseDefense: effectiveBaseDefense,
      baseSpecialAttack: effectiveBaseSpecialAttack,
      baseSpecialDefense: effectiveBaseSpecialDefense,
      baseSpeed: effectiveBaseSpeed,
      status: status,
    );
  }

  const Pokemon._({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    required this.level,
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    required this.specialAttack,
    required this.specialDefense,
    required this.speed,
    required this.heightMeters,
    required this.weightKg,
    required this.baseHp,
    required this.baseAttack,
    required this.baseDefense,
    required this.baseSpecialAttack,
    required this.baseSpecialDefense,
    required this.baseSpeed,
    required this.status,
  });

  String get primaryType => types.isNotEmpty ? types.first : 'normal';

  static int _calculateHp(int base, int level, {int iv = 31, int ev = 0}) {
    return (((2 * base + iv + (ev ~/ 4)) * level) ~/ 100) + level + 10;
  }

  static int _calculateOtherStat(
    int base,
    int level, {
    int iv = 31,
    int ev = 0,
    double nature = 1.0,
  }) {
    final value =
        (((2 * base + iv + (ev ~/ 4)) * level) ~/ 100) + 5;
    return (value * nature).floor();
  }

  Pokemon copyWith({
    int? id,
    String? name,
    String? imageUrl,
    List<String>? types,
    int? level,
    double? hp,
    double? maxHp,
    int? attack,
    int? defense,
    int? specialAttack,
    int? specialDefense,
    int? speed,
    double? heightMeters,
    double? weightKg,
    int? baseHp,
    int? baseAttack,
    int? baseDefense,
    int? baseSpecialAttack,
    int? baseSpecialDefense,
    int? baseSpeed,
    StatusCondition? status,
  }) {
    final updatedLevel = level ?? this.level;
    final updatedBaseHp = baseHp ?? this.baseHp;
    final updatedBaseAttack = baseAttack ?? this.baseAttack;
    final updatedBaseDefense = baseDefense ?? this.baseDefense;
    final updatedBaseSpecialAttack =
        baseSpecialAttack ?? this.baseSpecialAttack;
    final updatedBaseSpecialDefense =
        baseSpecialDefense ?? this.baseSpecialDefense;
    final updatedBaseSpeed = baseSpeed ?? this.baseSpeed;

    final shouldRecalculateStats = level != null ||
        baseHp != null ||
        baseAttack != null ||
        baseDefense != null ||
        baseSpecialAttack != null ||
        baseSpecialDefense != null ||
        baseSpeed != null;

    final recalculatedMaxHp = shouldRecalculateStats
        ? _calculateHp(updatedBaseHp, updatedLevel).toDouble()
        : (maxHp ?? this.maxHp);

    final recalculatedHp = (hp ??
            (shouldRecalculateStats
                ? math.min(this.hp, recalculatedMaxHp)
                : this.hp))
        .toDouble();

    final recalculatedAttack = shouldRecalculateStats
        ? _calculateOtherStat(updatedBaseAttack, updatedLevel)
        : (attack ?? this.attack);
    final recalculatedDefense = shouldRecalculateStats
        ? _calculateOtherStat(updatedBaseDefense, updatedLevel)
        : (defense ?? this.defense);
    final recalculatedSpecialAttack = shouldRecalculateStats
        ? _calculateOtherStat(updatedBaseSpecialAttack, updatedLevel)
        : (specialAttack ?? this.specialAttack);
    final recalculatedSpecialDefense = shouldRecalculateStats
        ? _calculateOtherStat(updatedBaseSpecialDefense, updatedLevel)
        : (specialDefense ?? this.specialDefense);
    final recalculatedSpeed = shouldRecalculateStats
        ? _calculateOtherStat(updatedBaseSpeed, updatedLevel)
        : (speed ?? this.speed);

    return Pokemon._(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      types: List<String>.unmodifiable(types ?? this.types),
      level: updatedLevel,
      hp: recalculatedHp.clamp(0, recalculatedMaxHp).toDouble(),
      maxHp: recalculatedMaxHp,
      attack: recalculatedAttack,
      defense: recalculatedDefense,
      specialAttack: recalculatedSpecialAttack,
      specialDefense: recalculatedSpecialDefense,
      speed: recalculatedSpeed,
      heightMeters: heightMeters ?? this.heightMeters,
      weightKg: weightKg ?? this.weightKg,
      baseHp: updatedBaseHp,
      baseAttack: updatedBaseAttack,
      baseDefense: updatedBaseDefense,
      baseSpecialAttack: updatedBaseSpecialAttack,
      baseSpecialDefense: updatedBaseSpecialDefense,
      baseSpeed: updatedBaseSpeed,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'imageUrl': imageUrl,
      'types': types,
      'level': level,
      'hp': hp,
      'maxHp': maxHp,
      'attack': attack,
      'defense': defense,
      'specialAttack': specialAttack,
      'specialDefense': specialDefense,
      'speed': speed,
      'heightMeters': heightMeters,
      'weightKg': weightKg,
      'baseHp': baseHp,
      'baseAttack': baseAttack,
      'baseDefense': baseDefense,
      'baseSpecialAttack': baseSpecialAttack,
      'baseSpecialDefense': baseSpecialDefense,
      'baseSpeed': baseSpeed,
      'status': status.name,
    };
  }

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    final String url = json['url'];
    final regExp = RegExp(r'/pokemon/(\d+)/');
    final match = regExp.firstMatch(url);
    int id = 0;
    if (match != null) {
      id = int.parse(match.group(1)!);
    }

    return Pokemon(
      id: id,
      name: json['name'],
      imageUrl:
          'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
      types: const ['normal'],
    );
  }

  factory Pokemon.fromDetailJson(Map<String, dynamic> json) {
    final int id = json['id'];
    final String image =
        json['sprites']?['other']?['official-artwork']?['front_default'] ??
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';

    List<String> types = [];
    if (json['types'] != null) {
      types = List<String>.unmodifiable((json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList());
    }
    if (types.isEmpty) {
      types = List<String>.unmodifiable(['normal']);
    }

    final stats = json['stats'] as List;
    int getStat(String name) {
      return (stats.firstWhere(
            (s) => s['stat']['name'] == name,
            orElse: () => {'base_stat': 50},
          )['base_stat'] as int);
    }

    double? height;
    if (json['height'] != null) {
      try {
        height = (json['height'] as num).toDouble() / 10.0;
      } catch (_) {}
    }
    double? weight;
    if (json['weight'] != null) {
      try {
        weight = (json['weight'] as num).toDouble() / 10.0;
      } catch (_) {}
    }

    final baseHp = getStat('hp');
    final baseAttack = getStat('attack');
    final baseDefense = getStat('defense');
    final baseSpecialAttack = getStat('special-attack');
    final baseSpecialDefense = getStat('special-defense');
    final baseSpeed = getStat('speed');

    return Pokemon(
      id: id,
      name: json['name'],
      imageUrl: image,
      types: types,
      level: 50,
      baseHp: baseHp,
      baseAttack: baseAttack,
      baseDefense: baseDefense,
      baseSpecialAttack: baseSpecialAttack,
      baseSpecialDefense: baseSpecialDefense,
      baseSpeed: baseSpeed,
      heightMeters: height,
      weightKg: weight,
    );
  }

  factory Pokemon.fromJsonCache(Map<String, dynamic> json) {
    return Pokemon(
      id: json['id'],
      name: json['name'],
      imageUrl: json['imageUrl'],
      types: List<String>.from(json['types'] ?? const ['normal']),
      level: json['level'] ?? 50,
      hp: (json['hp'] as num?)?.toDouble(),
      maxHp: (json['maxHp'] as num?)?.toDouble(),
      attack: json['attack'],
      defense: json['defense'],
      specialAttack: json['specialAttack'],
      specialDefense: json['specialDefense'],
      speed: json['speed'],
      heightMeters:
          (json['heightMeters'] is num) ? (json['heightMeters'] as num).toDouble() : null,
      weightKg:
          (json['weightKg'] is num) ? (json['weightKg'] as num).toDouble() : null,
      baseHp: json['baseHp'],
      baseAttack: json['baseAttack'],
      baseDefense: json['baseDefense'],
      baseSpecialAttack: json['baseSpecialAttack'],
      baseSpecialDefense: json['baseSpecialDefense'],
      baseSpeed: json['baseSpeed'],
      status: StatusConditionX.fromName(json['status'] as String?),
    );
  }
}
