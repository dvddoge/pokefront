import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/pokemon.dart';
import 'pokemon_filter_service.dart'; // Importar o serviço de filtro

class PokemonListService {
  static const int pageSize = 20;
  final Map<int, Map<String, int>> _statsCache = {};
  final Map<int, Pokemon> _pokemonCache = {};
  final Map<String, List<Pokemon>> _searchCache = {};

  Future<Map<String, dynamic>> fetchPokemonList({
    int page = 1,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  }) async {
    // Limpar o cache de Pokémon antes de buscar uma nova página para economizar memória
    // Considerar uma estratégia de cache mais sofisticada (LRU) se a performance for impactada
    // if (page > 1) { // Manter a limpeza de cache, se desejado
    //    _pokemonCache.removeWhere((key, value) => !_isPokemonOnPage(key, page, pageSize));
    //    print("Cache de Pokémon limpo para otimizar memória.");
    // }

    List<Pokemon> allFetchedPokemons = [];
    int offset = (page - 1) * pageSize;
    
    // Verificar se há filtros ativos
    bool hasActiveFilters = (selectedTypes?.values.contains(true) ?? false) ||
                           (selectedGeneration != null && selectedGeneration > 0) ||
                           (powerRange != null && powerRange != const RangeValues(0, 1000));
    
    try {
      // Sempre busca a lista base de nomes/URLs (até 1000)
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000&offset=0'),
      ).timeout(Duration(seconds: 15));

      if (response.statusCode != 200) {
        print('Erro na resposta da API: ${response.statusCode}');
        return {'pokemons': _getDefaultPokemons(), 'total': 10};
      }

      final data = json.decode(response.body);
      final List results = data['results'];
      final int totalApiPokemons = results.length;
      
      if (results.isEmpty) {
        print('Nenhum resultado encontrado na API');
        return {'pokemons': _getDefaultPokemons(), 'total': 10};
      }

      print('Encontrados ${results.length} Pokémon na API');

      List<Map<String, dynamic>> resultsToFetchDetails;
      if (hasActiveFilters) {
        // Se houver filtros, precisamos potencialmente buscar detalhes de TODOS para filtrar
        resultsToFetchDetails = List<Map<String, dynamic>>.from(results);
        print('Filtros ativos. Preparando para buscar detalhes de até ${resultsToFetchDetails.length} Pokémon.');
      } else {
        // Sem filtros, busca detalhes apenas para a página atual
        final int startIndex = offset;
        final int endIndex = startIndex + pageSize;
        resultsToFetchDetails = results.length > startIndex 
            ? List<Map<String, dynamic>>.from(results.sublist(startIndex, endIndex > results.length ? results.length : endIndex)) 
            : [];
        print('Sem filtros. Preparando para buscar detalhes de ${resultsToFetchDetails.length} Pokémon para a página $page.');
      }
      
      if (resultsToFetchDetails.isEmpty && !hasActiveFilters) {
        print('Nenhum resultado para a página $page (sem filtros)');
        // Se não há filtros e a página está além do limite, retorna vazio com o total da API
        return {'pokemons': [], 'total': totalApiPokemons};
      } else if (resultsToFetchDetails.isEmpty && hasActiveFilters) {
          print('Nenhum Pokémon encontrado na lista base da API para buscar detalhes com filtros.');
          return {'pokemons': [], 'total': 0};
      }
      
      // Fazer todas as requisições de detalhes necessárias em paralelo
      final futures = resultsToFetchDetails.map((pokemon) async {
        try {
          final pokemonUrl = pokemon['url'] as String;
          final pokemonId = int.parse(pokemonUrl.split('/')[6]);

          // Prioriza o cache
          if (_pokemonCache.containsKey(pokemonId)) {
             // print('Usando Pokémon em cache: ${pokemon['name']} (ID: $pokemonId)');
            return _pokemonCache[pokemonId]!;
          }

          // print('Carregando detalhes do Pokémon: ${pokemon['name']} (ID: $pokemonId)');
          final detailResponse = await http.get(Uri.parse(pokemonUrl))
              .timeout(Duration(seconds: 10)); // Timeout menor para detalhes individuais
              
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final pokemonObj = Pokemon.fromDetailJson(detailData);
            _pokemonCache[pokemonId] = pokemonObj;
            // print('Pokémon carregado com sucesso: ${pokemonObj.name}');
            return pokemonObj;
          } else {
            // print('Erro ao carregar detalhes do Pokémon: ${detailResponse.statusCode}');
            return null; // Retorna null em caso de erro para filtrar depois
          }
        } catch (e) {
          // print('Erro ao carregar Pokémon ${pokemon['name']}: $e');
           return null; // Retorna null em caso de erro
        }
      }).toList();

      List<Pokemon> fetchedPokemons = [];
      try {
        final detailResults = await Future.wait(futures, eagerError: false);
        fetchedPokemons = detailResults
            .where((result) => result is Pokemon) // Garante que é um Pokemon e não null
            .map((result) => result as Pokemon)
            .toList();
         print('Detalhes carregados para ${fetchedPokemons.length} Pokémon.');
      } catch (e) {
        print('Erro ao processar resultados dos detalhes: $e');
      }

      if (fetchedPokemons.isEmpty) {
        print('Nenhum Pokémon com detalhes carregados com sucesso.');
        return {'pokemons': [], 'total': hasActiveFilters ? 0 : totalApiPokemons };
      }

      // Agora, aplica os filtros se necessário
      List<Pokemon> finalPokemonList;
      int totalFilteredCount;

      if (hasActiveFilters) {
        print('Aplicando filtros...');
        // Precisa buscar os stats para filtrar por powerRange (se necessário)
        await _ensureStatsForFilter(fetchedPokemons, powerRange);

        finalPokemonList = fetchedPokemons.where((pokemon) {
          // Usa o serviço de filtro
          return PokemonFilterService.shouldIncludePokemon(
            pokemon: pokemon,
            selectedTypes: selectedTypes ?? {},
            selectedGeneration: selectedGeneration ?? 0,
            powerRange: powerRange ?? const RangeValues(0, 1000),
            statsCache: _statsCache, // Passa o cache de stats
          );
        }).toList();
        totalFilteredCount = finalPokemonList.length;
        print('Após filtros, ${finalPokemonList.length} Pokémon encontrados.');
      } else {
        finalPokemonList = fetchedPokemons;
        totalFilteredCount = totalApiPokemons; // Total sem filtros é o total da API
      }

      // Ordenar a lista (filtrada ou não)
      finalPokemonList.sort((a, b) => a.id.compareTo(b.id));

      // Paginar o resultado FINAL (filtrado ou não)
      List<Pokemon> pagePokemons;
      if (hasActiveFilters) {
        // Se filtros estão ativos, paginamos a lista filtrada completa
        final int startIndex = offset;
        final int endIndex = startIndex + pageSize;
        pagePokemons = finalPokemonList.length > startIndex 
            ? finalPokemonList.sublist(startIndex, endIndex > finalPokemonList.length ? finalPokemonList.length : endIndex) 
            : [];
      } else {
        // Se não há filtros, a lista final JÁ é a página correta (pois buscamos apenas ela)
        pagePokemons = finalPokemonList;
      }

      print('Retornando ${pagePokemons.length} Pokémon para a página $page. Total (filtrado/geral): $totalFilteredCount');

      return {
        'pokemons': pagePokemons,
        'total': totalFilteredCount, // Retorna o total CORRETO (filtrado ou geral)
      };
    } catch (e) {
      print('Erro geral ao carregar lista de Pokémon: $e');
      return {'pokemons': _getDefaultPokemons(), 'total': 10};
    }
  }

  // Função auxiliar para garantir que os stats necessários para o filtro de poder estejam no cache
  Future<void> _ensureStatsForFilter(List<Pokemon> pokemonsToFilter, RangeValues? powerRange) async {
    if (powerRange == null || powerRange == const RangeValues(0, 1000)) {
      return; // Não precisa buscar stats se o filtro de poder não está ativo
    }

    List<Future<void>> statFutures = [];
    for (var pokemon in pokemonsToFilter) {
      if (!_statsCache.containsKey(pokemon.id)) {
        statFutures.add(fetchPokemonStats(pokemon.id)); // fetchPokemonStats deve adicionar ao _statsCache
      }
    }

    if (statFutures.isNotEmpty) {
      print('Buscando stats para ${statFutures.length} Pokémon para aplicar filtro de poder...');
      await Future.wait(statFutures).catchError((e) {
        print("Erro ao buscar alguns stats para filtro: $e. Filtro de poder pode estar incompleto.");
      });
      print('Stats para filtro carregados.');
    }
  }

  // Adicione ou modifique fetchPokemonStats para usar o cache
  Future<Map<String, int>?> fetchPokemonStats(int pokemonId) async {
    if (_statsCache.containsKey(pokemonId)) {
      return _statsCache[pokemonId];
    }
    try {
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = <String, int>{};
        for (var statInfo in data['stats']) {
          stats[statInfo['stat']['name']] = statInfo['base_stat'] as int;
        }
        _statsCache[pokemonId] = stats; // Armazena no cache
        return stats;
      } else {
        print('Erro ao buscar stats para ID $pokemonId: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Erro na requisição de stats para ID $pokemonId: $e');
      return null;
    }
  }

  // Helper para verificar se um ID pertence à página atual (aproximado)
  // bool _isPokemonOnPage(int pokemonId, int page, int pageSize) {
// ... (manter a função se a limpeza de cache for usada)
  // }

  // Método para criar um Pokémon padrão quando ocorre um erro
  Pokemon _createDefaultPokemon(int id, String name) {
    return Pokemon(
      id: id > 0 ? id : 1,
      name: name.isNotEmpty ? name : 'Pokémon',
      imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/${id > 0 ? id : 1}.png',
      types: ['normal'],
    );
  }

  // Método para obter uma lista de Pokémon padrão quando ocorre um erro
  List<Pokemon> _getDefaultPokemons() {
    return List.generate(10, (index) {
      final id = index + 1;
      return Pokemon(
        id: id,
        name: 'Pokémon $id',
        imageUrl: 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
        types: ['normal'],
      );
    });
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

    // Verificar cache para consultas repetidas
    final cacheKey = '${query}_${selectedTypes}_${selectedGeneration}_${powerRange?.start}_${powerRange?.end}';
    if (_searchCache.containsKey(cacheKey)) {
      print('Usando resultados em cache para: $query');
      return _searchCache[cacheKey]!;
    }

    try {
      // Aumentar o limite para 1000 Pokémon
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      ).timeout(Duration(seconds: 15));
      
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

      // Remover a limitação de 20 resultados
      final limitedResults = filteredResults;
      
      // Fazer todas as requisições de detalhes em paralelo
      final futures = limitedResults.map((pokemon) async {
        try {
          final pokemonUrl = pokemon['url'] as String;
          final pokemonId = int.parse(pokemonUrl.split('/')[6]);

          // Verificar cache antes de buscar
          if (_pokemonCache.containsKey(pokemonId)) {
            return _pokemonCache[pokemonId]!;
          }

          final detailResponse = await http.get(Uri.parse(pokemonUrl))
              .timeout(Duration(seconds: 10));
              
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final pokemonObj = Pokemon.fromDetailJson(detailData);
            _pokemonCache[pokemonId] = pokemonObj; // Manter o cache na busca
            return pokemonObj;
          } else {
            return _createDefaultPokemon(pokemonId, pokemon['name']);
          }
        } catch (e) {
          print('Erro ao carregar Pokémon ${pokemon['name']}: $e');
          try {
            final pokemonId = int.parse(pokemon['url'].toString().split('/')[6]);
            return _createDefaultPokemon(pokemonId, pokemon['name']);
          } catch (parseError) {
            print('Erro ao processar ID do Pokémon: $parseError');
            return _createDefaultPokemon(0, pokemon['name'] ?? 'Desconhecido');
          }
        }
      }).toList();

      List<Pokemon> pokemons = [];
      try {
        // Correção do TypeError: Verificar tipo antes de converter
        final results = await Future.wait(futures, eagerError: false);
        pokemons = results
            .where((result) => result is Pokemon) // Garante que é um Pokemon
            .map((result) => result as Pokemon)   // Converte com segurança
            .toList();
      } catch (e) {
        print('Erro ao processar resultados da busca: $e');
        // Continuar com os Pokémon que foram carregados com sucesso
      }

      if (pokemons.isEmpty) {
        return _getDefaultPokemons();
      }

      // Aplicar filtros adicionais pós-busca (tipo, geração, etc.)
      final postFilteredPokemons = pokemons.where((pokemon) {
        if (selectedTypes?.isNotEmpty ?? false) {
          final selectedTypesList = selectedTypes!.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();
          
          if (selectedTypesList.isNotEmpty) {
            return selectedTypesList.any((selectedType) =>
              pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
            );
          }
        }

        if (selectedGeneration != null && selectedGeneration > 0) {
          int pokemonGen = _getPokemonGeneration(pokemon.id);
          return pokemonGen == selectedGeneration;
        }

        return true;
      }).toList();

      // Ordenar por ID
      postFilteredPokemons.sort((a, b) => a.id.compareTo(b.id));
      
      // Armazenar em cache
      _searchCache[cacheKey] = postFilteredPokemons;
      
      return postFilteredPokemons;
    } catch (e) {
      print('Erro na busca de Pokémon: $e');
      return _getDefaultPokemons();
    }
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