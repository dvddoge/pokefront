import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/pokemon.dart';

class PokemonListService {
  static const int pageSize = 20;
  final Map<int, Map<String, int>> _statsCache = {};
  final Map<int, Pokemon> _pokemonCache = {};

  Future<Map<String, dynamic>> fetchPokemonList({
    int page = 1,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  }) async {
    List<Pokemon> filteredPokemons = [];
    int offset = (page - 1) * pageSize;
    
    // Verificar se há filtros ativos
    bool hasActiveFilters = (selectedTypes?.values.contains(true) ?? false) ||
                           (selectedGeneration != null && selectedGeneration > 0) ||
                           (powerRange != null && powerRange != const RangeValues(0, 1000));
    
    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao carregar os Pokémon');
      }

      final data = json.decode(response.body);
      final List results = data['results'];
      
      if (results.isEmpty) return {'pokemons': [], 'total': 0};

      // Fazer todas as requisições de detalhes em paralelo
      final futures = results.map((pokemon) async {
        try {
          final pokemonUrl = pokemon['url'] as String;
          final pokemonId = int.parse(pokemonUrl.split('/')[6]);

          if (_pokemonCache.containsKey(pokemonId)) {
            return _pokemonCache[pokemonId]!;
          }

          final detailResponse = await http.get(Uri.parse(pokemonUrl));
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final pokemonObj = Pokemon.fromDetailJson(detailData);
            _pokemonCache[pokemonId] = pokemonObj;
            return pokemonObj;
          }
        } catch (e) {
          print('Erro ao carregar Pokémon: $e');
        }
        return null;
      }).toList();

      final pokemons = (await Future.wait(futures))
          .where((pokemon) => pokemon != null)
          .cast<Pokemon>()
          .toList();

      // Se não houver filtros ativos, retornar todos os Pokémon
      if (!hasActiveFilters) {
        final pagePokemons = pokemons.skip(offset).take(pageSize).toList();
        return {
          'pokemons': pagePokemons,
          'total': pokemons.length,
        };
      }

      // Se precisar dos stats, carregar em paralelo
      if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
        final statsFutures = pokemons.map((pokemon) => 
          fetchPokemonStats(pokemon.id)
        ).toList();
        
        await Future.wait(statsFutures);
      }

      // Aplicar filtros apenas se houver filtros ativos
      filteredPokemons = pokemons.where((pokemon) {
        if (selectedTypes?.isNotEmpty ?? false) {
          final selectedTypesList = selectedTypes!.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();
          
          if (selectedTypesList.isNotEmpty) {
            bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
              pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
            );
            
            if (!hasAnySelectedType) return false;
          }
        }

        if (selectedGeneration != null && selectedGeneration > 0) {
          int pokemonGen = _getPokemonGeneration(pokemon.id);
          if (pokemonGen != selectedGeneration) return false;
        }

        if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
          final stats = _statsCache[pokemon.id];
          if (stats != null) {
            int totalPower = stats.values.reduce((a, b) => a + b);
            if (totalPower < powerRange.start || totalPower > powerRange.end) {
              return false;
            }
          }
        }

        return true;
      }).toList();

      // Ordenar por ID
      filteredPokemons.sort((a, b) => a.id.compareTo(b.id));

      // Calcular o total de Pokémon filtrados
      final totalFilteredPokemons = filteredPokemons.length;

      // Pegar apenas os Pokémon da página atual
      final startIndex = (page - 1) * pageSize;
      final pagePokemons = filteredPokemons.skip(startIndex).take(pageSize).toList();

      return {
        'pokemons': pagePokemons,
        'total': totalFilteredPokemons,
      };
    } catch (e) {
      print('Erro ao carregar lista de Pokémon: $e');
      throw Exception('Falha ao carregar os Pokémon');
    }
  }

  Future<List<Pokemon>> searchPokemonByName(String query, {
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  }) async {
    if (query.isEmpty && (selectedTypes == null || selectedTypes.isEmpty) && 
        selectedGeneration == null && powerRange == null) {
      return [];
    }

    try {
      // Primeira requisição para obter a lista básica
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );
      
      if (response.statusCode != 200) {
        throw Exception('Falha ao buscar Pokémon');
      }

      final data = json.decode(response.body);
      final List results = data['results'];
      
      // Filtrar primeiro por nome para reduzir o número de requisições
      final filteredResults = results.where((pokemon) {
        if (query.isNotEmpty && !pokemon['name'].toString().toLowerCase().contains(query.toLowerCase())) {
          return false;
        }
        return true;
      }).toList();

      // Fazer todas as requisições de detalhes em paralelo
      final futures = filteredResults.map((pokemon) async {
        try {
          final pokemonUrl = pokemon['url'] as String;
          final pokemonId = int.parse(pokemonUrl.split('/')[6]);

          // Verificar cache primeiro
          if (_pokemonCache.containsKey(pokemonId)) {
            return _pokemonCache[pokemonId]!;
          }

          final detailResponse = await http.get(Uri.parse(pokemonUrl));
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final pokemonObj = Pokemon.fromDetailJson(detailData);
            _pokemonCache[pokemonId] = pokemonObj;
            return pokemonObj;
          }
        } catch (e) {
          print('Erro ao carregar detalhes do Pokémon: $e');
        }
        return null;
      }).toList();

      // Aguardar todas as requisições terminarem
      final pokemons = (await Future.wait(futures))
          .where((pokemon) => pokemon != null)
          .cast<Pokemon>()
          .toList();

      // Se precisar dos stats, carregar em paralelo
      if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
        final statsFutures = pokemons.map((pokemon) => 
          fetchPokemonStats(pokemon.id)
        ).toList();
        
        await Future.wait(statsFutures);
      }

      // Aplicar filtros restantes
      final filteredPokemons = pokemons.where((pokemon) {
        // Filtro de tipos
        if (selectedTypes?.isNotEmpty ?? false) {
          final selectedTypesList = selectedTypes!.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();
          
          bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
            pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
          );
          
          if (!hasAnySelectedType) return false;
        }

        // Filtro de geração
        if (selectedGeneration != null && selectedGeneration > 0) {
          int pokemonGen = _getPokemonGeneration(pokemon.id);
          if (pokemonGen != selectedGeneration) return false;
        }

        // Filtro de poder
        if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
          final stats = _statsCache[pokemon.id];
          if (stats != null) {
            int totalPower = stats.values.reduce((a, b) => a + b);
            if (totalPower < powerRange.start || totalPower > powerRange.end) {
              return false;
            }
          }
        }

        return true;
      }).toList();

      // Ordenar por ID
      filteredPokemons.sort((a, b) => a.id.compareTo(b.id));
      return filteredPokemons;
    } catch (e) {
      print('Erro ao buscar Pokémon: $e');
      return [];
    }
  }

  Future<Map<String, int>?> fetchPokemonStats(int pokemonId) async {
    if (_statsCache.containsKey(pokemonId)) {
      return _statsCache[pokemonId];
    }

    int retryCount = 0;
    const maxRetries = 3;
    const initialDelay = Duration(milliseconds: 500);

    while (retryCount < maxRetries) {
      try {
        final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final stats = Map<String, int>.fromEntries(
            (data['stats'] as List).map(
              (s) => MapEntry(
                (s['stat']['name'] as String),
                (s['base_stat'] as int),
              ),
            ),
          );
          
          _statsCache[pokemonId] = stats;
          return stats;
        } else if (response.statusCode == 429) { // Rate limit
          await Future.delayed(Duration(milliseconds: 1000 * (retryCount + 1)));
          retryCount++;
          continue;
        }
        return null;
      } catch (e) {
        if (retryCount < maxRetries - 1) {
          await Future.delayed(initialDelay * (retryCount + 1));
          retryCount++;
          continue;
        }
        print('Erro ao buscar stats após $maxRetries tentativas: $e');
        return null;
      }
    }
    return null;
  }

  Future<List<Pokemon>> filterPokemons({
    required List<Pokemon> pokemons,
    required Map<String, bool> selectedTypes,
    required int selectedGeneration,
    required RangeValues powerRange,
  }) async {
    if (selectedTypes.isEmpty && selectedGeneration == 0 && 
        powerRange.start == 0 && powerRange.end == 1000) {
      return pokemons;
    }

    List<Pokemon> filteredPokemons = [];
    for (var pokemon in pokemons) {
      if (selectedTypes.isNotEmpty) {
        final selectedTypesList = selectedTypes.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
        
        bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
          pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
        );
        
        if (!hasAnySelectedType) continue;
      }

      if (selectedGeneration > 0) {
        int pokemonGen = _getPokemonGeneration(pokemon.id);
        if (pokemonGen != selectedGeneration) continue;
      }

      if (_statsCache.containsKey(pokemon.id)) {
        int totalPower = _statsCache[pokemon.id]!.values.reduce((a, b) => a + b);
        if (totalPower < powerRange.start || totalPower > powerRange.end) {
          continue;
        }
      }

      filteredPokemons.add(pokemon);
    }

    return filteredPokemons;
  }

  int _getPokemonGeneration(int pokemonId) {
    if (pokemonId <= 151) return 1;
    if (pokemonId <= 251) return 2;
    if (pokemonId <= 386) return 3;
    if (pokemonId <= 493) return 4;
    if (pokemonId <= 649) return 5;
    if (pokemonId <= 721) return 6;
    if (pokemonId <= 809) return 7;
    return 8;
  }
} 