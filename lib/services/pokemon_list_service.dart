import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/pokemon.dart';

class PokemonListService {
  static const int pageSize = 20;
  final Map<int, Map<String, int>> _statsCache = {};
  final Map<int, Pokemon> _pokemonCache = {};

  Future<List<Pokemon>> fetchPokemonList({
    int page = 1,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  }) async {
    List<Pokemon> filteredPokemons = [];
    int currentOffset = (page - 1) * pageSize;
    int limit = pageSize;
    
    // Se houver filtros ativos, aumentamos o limite para ter mais chances de encontrar Pokémon suficientes
    if (selectedTypes?.isNotEmpty ?? false || selectedGeneration != null || powerRange != null) {
      limit = pageSize * 3;  // Busca 3x mais Pokémon para ter mais chances de encontrar suficientes após filtrar
    }

    while (filteredPokemons.length < pageSize) {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=$limit&offset=$currentOffset'),
      );

      if (response.statusCode != 200) {
        throw Exception('Falha ao carregar os Pokémon');
      }

      final data = json.decode(response.body);
      final List results = data['results'];
      
      if (results.isEmpty) break;  // Não há mais Pokémon para carregar

      for (var pokemon in results) {
        final detailResponse = await http.get(Uri.parse(pokemon['url']));
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          final int pokemonId = detailData['id'];
          
          // Usar o Pokémon do cache se existir
          Pokemon pokemonObj;
          if (_pokemonCache.containsKey(pokemonId)) {
            pokemonObj = _pokemonCache[pokemonId]!;
          } else {
            pokemonObj = Pokemon.fromDetailJson(detailData);
            _pokemonCache[pokemonId] = pokemonObj;
          }

          // Aplicar filtros
          bool shouldInclude = true;

          if (selectedTypes?.isNotEmpty ?? false) {
            final selectedTypesList = selectedTypes!.entries
                .where((entry) => entry.value)
                .map((entry) => entry.key)
                .toList();
            
            bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
              pokemonObj.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
            );
            
            if (!hasAnySelectedType) shouldInclude = false;
          }

          if (shouldInclude && selectedGeneration != null && selectedGeneration > 0) {
            int pokemonGen = _getPokemonGeneration(pokemonObj.id);
            if (pokemonGen != selectedGeneration) shouldInclude = false;
          }

          if (shouldInclude && powerRange != null) {
            final stats = await fetchPokemonStats(pokemonId);
            if (stats != null) {
              int totalPower = stats.values.reduce((a, b) => a + b);
              if (totalPower < powerRange.start || totalPower > powerRange.end) {
                shouldInclude = false;
              }
            }
          }
          
          if (shouldInclude) {
            filteredPokemons.add(pokemonObj);
            if (filteredPokemons.length >= pageSize) break;
          }
        }
      }

      if (results.length < limit) break;  // Não há mais Pokémon para carregar
      currentOffset += limit;
    }

    return List<Pokemon>.from(filteredPokemons);
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
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        
        final filteredResults = results.where((pokemon) {
          if (query.isNotEmpty && !pokemon['name'].toString().toLowerCase().contains(query.toLowerCase())) {
            return false;
          }
          return true;
        }).toList();

        List<Pokemon> pokemons = [];
        for (var pokemon in filteredResults) {
          final detailResponse = await http.get(
            Uri.parse(pokemon['url']),
          );
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final int pokemonId = detailData['id'];
            
            // Usar o Pokémon do cache se existir
            Pokemon pokemonObj;
            if (_pokemonCache.containsKey(pokemonId)) {
              pokemonObj = _pokemonCache[pokemonId]!;
            } else {
              pokemonObj = Pokemon.fromDetailJson(detailData);
              _pokemonCache[pokemonId] = pokemonObj;
            }
            
            // Aplicar filtros
            if (selectedTypes?.isNotEmpty ?? false) {
              final selectedTypesList = selectedTypes!.entries
                  .where((entry) => entry.value)
                  .map((entry) => entry.key)
                  .toList();
              
              bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
                pokemonObj.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
              );
              
              if (!hasAnySelectedType) continue;
            }

            if (selectedGeneration != null && selectedGeneration > 0) {
              int pokemonGen = _getPokemonGeneration(pokemonObj.id);
              if (pokemonGen != selectedGeneration) continue;
            }

            if (powerRange != null) {
              final stats = await fetchPokemonStats(pokemonObj.id);
              if (stats != null) {
                int totalPower = stats.values.reduce((a, b) => a + b);
                if (totalPower < powerRange.start || totalPower > powerRange.end) {
                  continue;
                }
              }
            }

            pokemons.add(pokemonObj);
          }
        }
        
        // Ordenar por ID
        pokemons.sort((a, b) => a.id.compareTo(b.id));
        return List<Pokemon>.from(pokemons);
      }
      throw Exception('Falha ao buscar Pokémon');
    } catch (e) {
      print('Erro ao buscar Pokémon: $e');
      return [];
    }
  }

  Future<Map<String, int>?> fetchPokemonStats(int pokemonId) async {
    if (_statsCache.containsKey(pokemonId)) {
      return _statsCache[pokemonId];
    }

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
      }
    } catch (e) {
      print('Erro ao buscar stats: $e');
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