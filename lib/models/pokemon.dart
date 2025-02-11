class Pokemon {
  final int id;
  final String name;
  final String imageUrl;
  final List<String> types;

  Pokemon({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.types,
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

    return Pokemon(
      id: id,
      name: json['name'],
      imageUrl: image,
      types: types,
    );
  }
}
