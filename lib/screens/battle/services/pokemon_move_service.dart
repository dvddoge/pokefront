import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../models/pokemon_move.dart';

class PokemonMoveService {
  static Future<List<PokemonMove>> fetchPokemonMoves(
    int pokemonId, {
    int level = 50,
  }) async {
    try {
      if (pokemonId <= 0) {
        print('ID de Pokémon inválido ($pokemonId). Usando movimentos padrão.');
        return getDefaultMoves();
      }

      final response = await http
          .get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print(
            'Erro ${response.statusCode} ao buscar movimentos para o Pokémon $pokemonId');
        return getDefaultMoves();
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final movesData = (data['moves'] as List?) ?? [];

      if (movesData.isEmpty) {
        print('Nenhum movimento listado para o Pokémon $pokemonId');
        return getDefaultMoves();
      }

      final candidates = <_MoveCandidate>[];
      for (final moveEntry in movesData) {
        try {
          final moveInfo = moveEntry['move'] as Map<String, dynamic>;
          final moveName = moveInfo['name'] as String? ?? 'unknown';
          final moveUrl = moveInfo['url'] as String? ?? '';
          if (moveUrl.isEmpty) continue;

          final details = (moveEntry['version_group_details'] as List?)
                  ?.where((detail) =>
                      detail['move_learn_method']?['name'] == 'level-up')
                  .toList() ??
              [];
          if (details.isEmpty) continue;

          final levelDetail = details.reduce(
            (current, next) =>
                (next['level_learned_at'] ?? 0) >
                        (current['level_learned_at'] ?? 0)
                    ? next
                    : current,
          );

          final learnedLevel = levelDetail['level_learned_at'] ?? 0;
          candidates.add(
            _MoveCandidate(
              name: moveName,
              url: moveUrl,
              learnedLevel: learnedLevel,
            ),
          );
        } catch (e) {
          print('Erro ao processar entrada de movimento: $e');
        }
      }

      if (candidates.isEmpty) {
        print('Nenhuma opção válida de movimento por nível. Usando padrão.');
        return getDefaultMoves();
      }

      candidates.sort((a, b) => b.learnedLevel.compareTo(a.learnedLevel));
      final filtered = candidates
          .where((candidate) => candidate.learnedLevel <= level)
          .toList();

      final selected = (filtered.isNotEmpty ? filtered : candidates)
          .take(4)
          .toList(growable: false);

      final moves = <PokemonMove>[];
      for (final candidate in selected) {
        final move = await _fetchMoveDetails(candidate);
        if (move != null) {
          moves.add(move);
        }
      }

      if (moves.isEmpty) {
        print('Falha ao carregar detalhes dos movimentos. Usando padrão.');
        return getDefaultMoves();
      }

      return moves;
    } catch (e) {
      print('Erro geral ao carregar movimentos: $e');
      return getDefaultMoves();
    }
  }

  static Future<PokemonMove?> _fetchMoveDetails(
      _MoveCandidate candidate) async {
    try {
      final response = await http
          .get(Uri.parse(candidate.url))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode != 200) {
        print(
            'Erro ${response.statusCode} ao carregar detalhes do movimento ${candidate.name}');
        return createMoveFromName(candidate.name);
      }

      final moveData = json.decode(response.body) as Map<String, dynamic>;
      final meta = (moveData['meta'] as Map<String, dynamic>?) ?? {};
      final statChanges = <String, int>{};
      final statChangesList = (moveData['stat_changes'] as List?) ?? [];
      for (final statChange in statChangesList) {
        final stat = statChange['stat']?['name'] as String?;
        final changeValue = statChange['change'] as int?;
        if (stat != null && changeValue != null) {
          statChanges[stat] = changeValue;
        }
      }

      return PokemonMove(
        name: (moveData['name'] as String? ?? candidate.name)
            .replaceAll('-', ' '),
        power: (moveData['power'] as num?)?.toDouble(),
        type: moveData['type']?['name'] as String? ?? 'normal',
        accuracy: (moveData['accuracy'] as num?)?.toDouble() ?? 100.0,
        damageClass:
            moveData['damage_class']?['name'] as String? ?? 'physical',
        pp: moveData['pp'] as int? ?? 20,
        priority: moveData['priority'] as int? ?? 0,
        ailment: meta['ailment']?['name'] as String?,
        ailmentChance:
            ((meta['ailment_chance'] ?? 0) as num).toDouble() / 100.0,
        statChanges: statChanges,
        healPercent: (meta['healing'] as num? ?? 0) > 0
            ? ((meta['healing'] as num).toDouble() / 100.0)
            : null,
      );
    } catch (e) {
      print('Erro ao obter detalhes do movimento ${candidate.name}: $e');
      return createMoveFromName(candidate.name);
    }
  }

  static PokemonMove createMoveFromName(String moveName) {
    final formattedName = moveName.replaceAll('-', ' ');
    String type = 'normal';
    if (moveName.contains('fire') ||
        moveName.contains('burn') ||
        moveName.contains('flame')) {
      type = 'fire';
    } else if (moveName.contains('water') || moveName.contains('aqua')) {
      type = 'water';
    } else if (moveName.contains('grass') || moveName.contains('leaf')) {
      type = 'grass';
    } else if (moveName.contains('electric') ||
        moveName.contains('thunder') ||
        moveName.contains('volt')) {
      type = 'electric';
    }

    double? power = 50;
    if (moveName.contains('slam') ||
        moveName.contains('strike') ||
        moveName.contains('blast')) {
      power = 70;
    } else if (moveName.contains('punch') || moveName.contains('kick')) {
      power = 60;
    } else if (moveName.contains('tackle') || moveName.contains('pound')) {
      power = 40;
    }

    return PokemonMove(
      name: formattedName,
      power: power,
      type: type,
      accuracy: 90,
      damageClass: 'physical',
      pp: 20,
    );
  }

  static List<PokemonMove> getDefaultMoves() {
    return const [
      PokemonMove(
        name: 'Ataque Rápido',
        power: 40,
        type: 'normal',
        accuracy: 100,
        damageClass: 'physical',
        pp: 30,
      ),
      PokemonMove(
        name: 'Raio de Água',
        power: 60,
        type: 'water',
        accuracy: 100,
        damageClass: 'special',
        pp: 20,
      ),
      PokemonMove(
        name: 'Folha Navalha',
        power: 55,
        type: 'grass',
        accuracy: 95,
        damageClass: 'physical',
        pp: 25,
      ),
      PokemonMove(
        name: 'Onda de Choque',
        power: 60,
        type: 'electric',
        accuracy: 100,
        damageClass: 'special',
        pp: 20,
      ),
    ];
  }
}

class _MoveCandidate {
  const _MoveCandidate({
    required this.name,
    required this.url,
    required this.learnedLevel,
  });

  final String name;
  final String url;
  final int learnedLevel;
}
