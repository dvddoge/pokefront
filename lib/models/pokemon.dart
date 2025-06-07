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

  Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
    this.level = 50,
    this.hp = 100,
    this.maxHp = 100,
    this.attack = 50,
    this.defense = 50,
    this.specialAttack = 50,
    this.specialDefense = 50,
    this.speed = 50,
  });

  String get primaryType => types.isNotEmpty ? types.first : 'normal';

  factory Pokemon.fromJson(Map<String, dynamic> json) {
    String url = json['url'];
    final regExp = RegExp(r'/pokemon/(\d+)/');
    final match = regExp.firstMatch(url);
    int id = 0;
    if (match != null) {
      id = int.parse(match.group(1)!);
    }
    
    return Pokemon(
      id: id,
      name: json['name'],
      imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
      types: ['normal'], // Será atualizado quando os detalhes forem carregados
    );
  }

  factory Pokemon.fromDetailJson(Map<String, dynamic> json) {
    int id = json['id'];
    String image = json['sprites']?['other']?['official-artwork']?['front_default'] ??
        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png';
    
    // Pegar todos os tipos do Pokemon da API
    List<String> types = [];
    if (json['types'] != null) {
      types = List<String>.unmodifiable((json['types'] as List)
          .map((t) => t['type']['name'] as String)
          .toList());
    }
    if (types.isEmpty) {
      types = List<String>.unmodifiable(['normal']);
    }

    // Pega os stats da API
    final stats = json['stats'] as List;
    final getStat = (String name) {
      return (stats.firstWhere((s) => s['stat']['name'] == name, orElse: () => {'base_stat': 50})['base_stat'] as int);
    };

    final int hp = getStat('hp');

    return Pokemon(
      id: id,
      name: json['name'],
      imageUrl: image,
      types: types,
      level: 50, // Nível padrão
      hp: hp.toDouble(),
      maxHp: hp.toDouble(),
      attack: getStat('attack'),
      defense: getStat('defense'),
      specialAttack: getStat('special-attack'),
      specialDefense: getStat('special-defense'),
      speed: getStat('speed'),
    );
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
  }) {
    return Pokemon(
      id: id ?? this.id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      types: types ?? this.types,
      level: level ?? this.level,
      hp: hp ?? this.hp,
      maxHp: maxHp ?? this.maxHp,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      specialAttack: specialAttack ?? this.specialAttack,
      specialDefense: specialDefense ?? this.specialDefense,
      speed: speed ?? this.speed,
    );
  }
}
