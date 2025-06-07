import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../models/pokemon_move.dart';

class PokemonMoveService {
  static Future<List<PokemonMove>> fetchPokemonMoves(int pokemonId) async {
    try {
      print('Iniciando carregamento de movimentos para o Pokémon ID: $pokemonId');
      
      // Verifica se o ID é válido
      if (pokemonId <= 0) {
        print('ID de Pokémon inválido: $pokemonId. Usando movimentos padrão.');
        return getDefaultMoves();
      }
      
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
      ).timeout(Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final movesData = data['moves'] as List;
        
        if (movesData.isEmpty) {
          print('Nenhum movimento encontrado para o Pokémon ID: $pokemonId');
          return getDefaultMoves();
        }
        
        print('Encontrados ${movesData.length} movimentos. Carregando detalhes dos primeiros 4.');
        
        // Limita a 4 movimentos e adiciona timeout para evitar esperas longas
        final moves = movesData.take(4).map((m) async {
          try {
            final moveUrl = m['move']['url'] as String;
            final moveName = m['move']['name'] as String;
            print('Carregando detalhes do movimento: $moveName (URL: $moveUrl)');
            
            // Tenta obter os detalhes do movimento
            final moveResponse = await http.get(Uri.parse(moveUrl))
                .timeout(Duration(seconds: 5), onTimeout: () {
              print('Timeout ao carregar detalhes do movimento: $moveName');
              throw Exception('Timeout');
            });
            
            if (moveResponse.statusCode == 200) {
              final moveData = json.decode(moveResponse.body);
              final power = moveData['power'] ?? 50;
              final accuracy = moveData['accuracy'] ?? 90;
              final type = moveData['type']?['name'] ?? 'normal';
              final damageClass = moveData['damage_class']?['name'] ?? 'physical';
              
              print('Movimento carregado: ${moveData['name']} (Poder: $power, Precisão: $accuracy, Tipo: $type, Classe: $damageClass)');
              
              return PokemonMove(
                name: moveData['name'].toString().replaceAll('-', ' '),
                damage: power.toDouble(),
                type: type,
                accuracy: accuracy.toDouble(),
                damageClass: damageClass,
              );
            } else {
              print('Erro ao carregar detalhes do movimento. Status: ${moveResponse.statusCode}');
              // Cria um movimento com base apenas no nome
              return createMoveFromName(moveName);
            }
          } catch (e) {
            print('Erro ao processar movimento: $e');
            // Se falhar, tenta criar um movimento com base no nome
            final moveName = m['move']['name'] as String? ?? 'unknown';
            return createMoveFromName(moveName);
          }
        }).toList();

        try {
          final movesList = (await Future.wait(moves))
              .where((move) => move != null)
              .cast<PokemonMove>()
              .toList();

          if (movesList.isEmpty) {
            print('Nenhum movimento válido carregado. Usando movimentos padrão.');
            return getDefaultMoves();
          }
          
          print('Carregados com sucesso ${movesList.length} movimentos para o Pokémon ID: $pokemonId');
          return movesList;
        } catch (e) {
          print('Erro ao processar lista de movimentos: $e');
          return getDefaultMoves();
        }
      } else {
        print('Erro na resposta da API. Status: ${response.statusCode}');
        return getDefaultMoves();
      }
    } catch (e) {
      print('Erro ao carregar movimentos: $e');
      return getDefaultMoves();
    }
  }
  
  // Cria um movimento com base apenas no nome
  static PokemonMove createMoveFromName(String moveName) {
    print('Criando movimento a partir do nome: $moveName');
    final formattedName = moveName.replaceAll('-', ' ');
    
    // Determina o tipo com base no nome
    String type = 'normal';
    if (moveName.contains('fire') || moveName.contains('burn') || moveName.contains('flame')) {
      type = 'fire';
    } else if (moveName.contains('water') || moveName.contains('aqua')) {
      type = 'water';
    } else if (moveName.contains('grass') || moveName.contains('leaf')) {
      type = 'grass';
    } else if (moveName.contains('electric') || moveName.contains('thunder')) {
      type = 'electric';
    }
    
    // Determina o dano com base no nome
    double damage = 50;
    if (moveName.contains('slam') || moveName.contains('strike') || moveName.contains('blast')) {
      damage = 70;
    } else if (moveName.contains('punch') || moveName.contains('kick')) {
      damage = 60;
    } else if (moveName.contains('tackle') || moveName.contains('pound')) {
      damage = 40;
    }
    
    return PokemonMove(
      name: formattedName,
      damage: damage,
      type: type,
      accuracy: 90,
      damageClass: 'physical', // Assume physical for generated moves
    );
  }

  static List<PokemonMove> getDefaultMoves() {
    print('Retornando movimentos padrão');
    return [
      PokemonMove(
        name: 'Ataque Rápido',
        damage: 40,
        type: 'normal',
        accuracy: 100,
        damageClass: 'physical',
      ),
      PokemonMove(
        name: 'Investida',
        damage: 50,
        type: 'normal',
        accuracy: 100,
        damageClass: 'physical',
      ),
      PokemonMove(
        name: 'Raio de Água',
        damage: 60,
        type: 'water',
        accuracy: 100,
        damageClass: 'special',
      ),
      PokemonMove(
        name: 'Folha Navalha',
        damage: 55,
        type: 'grass',
        accuracy: 95,
        damageClass: 'physical',
      ),
    ];
  }
} 