import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/pokemon_move.dart';

class PokemonMoveService {
  static Future<List<PokemonMove>> fetchPokemonMoves(int pokemonId) async {
    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final moves = (data['moves'] as List).take(4).map((m) async {
          final moveUrl = m['move']['url'] as String;
          final moveResponse = await http.get(Uri.parse(moveUrl));
          if (moveResponse.statusCode == 200) {
            final moveData = json.decode(moveResponse.body);
            return PokemonMove(
              name: moveData['name'].toString().replaceAll('-', ' '),
              damage: (moveData['power'] ?? 50).toDouble(),
              type: moveData['type']['name'],
              accuracy: (moveData['accuracy'] ?? 90).toDouble(),
            );
          }
          return null;
        }).toList();

        final movesList = (await Future.wait(moves))
            .where((move) => move != null)
            .cast<PokemonMove>()
            .toList();

        return movesList.isEmpty ? getDefaultMoves() : movesList;
      }
    } catch (e) {
      print('Erro ao carregar movimentos: $e');
    }
    
    return getDefaultMoves();
  }

  static List<PokemonMove> getDefaultMoves() {
    return [
      PokemonMove(
        name: 'Ataque Rápido',
        damage: 20,
        type: 'normal',
        accuracy: 95,
      ),
      PokemonMove(
        name: 'Investida',
        damage: 25,
        type: 'normal',
        accuracy: 90,
      ),
      PokemonMove(
        name: 'Ataque Especial',
        damage: 35,
        type: 'special',
        accuracy: 80,
      ),
      PokemonMove(
        name: 'Golpe Final',
        damage: 45,
        type: 'special',
        accuracy: 70,
      ),
    ];
  }
} 