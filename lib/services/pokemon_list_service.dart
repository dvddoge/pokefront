import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../models/pokemon.dart';
import 'pokemon_filter_service.dart';
import 'pokemon_cache_service.dart';

class PokemonListService {
  static const int pageSize = 20;
  final Map<int, Map<String, int>> _statsCache = {};
  final Map<int, Pokemon> _pokemonCache = {};
  final Map<String, List<Pokemon>> _searchCache = {};
  static final Map<String, Set<int>> _typePokemonCache = {};

  // Método para limpar todos os caches
  void clearAllCaches() {
    _statsCache.clear();
    _pokemonCache.clear();
    _searchCache.clear();
    print('Cache legado limpo: ${_pokemonCache.length} Pokémon, ${_statsCache.length} stats, ${_searchCache.length} buscas');
  }

  // Getter para estatísticas do cache legado
  Map<String, int> getLegacyCacheStats() {
    return {
      'pokemon_count': _pokemonCache.length,
      'stats_count': _statsCache.length,
      'search_count': _searchCache.length,
    };
  }

  Future<Map<String, dynamic>> fetchPokemonList({
    int page = 1,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
    RangeValues? heightRange,
    RangeValues? weightRange,
  }) async {
    final int offset = (page - 1) * pageSize;

    final bool hasActiveFilters =
        (selectedTypes?.values.contains(true) ?? false) ||
            (selectedGeneration != null && selectedGeneration > 0) ||
            (powerRange != null && powerRange != const RangeValues(0, 1000)) ||
            (heightRange != null && heightRange != const RangeValues(0, 20)) ||
            (weightRange != null && weightRange != const RangeValues(0, 1000));

    try {
      // Inicializar cache inteligente
      await PokemonCacheService.initialize();

      // Buscar lista base de nomes/URLs
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000&offset=0'),
      ).timeout(const Duration(seconds: 15));

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

      if (hasActiveFilters) {
        final filteredResults = await _preFilterResults(
          results,
          selectedTypes,
          selectedGeneration,
          powerRange,
          heightRange,
          weightRange,
        );

        final filterOutcome = await _applyFiltersAndPaginate(
          filteredResults: filteredResults,
          page: page,
          selectedTypes: selectedTypes ?? {},
          selectedGeneration: selectedGeneration ?? 0,
          powerRange: powerRange ?? const RangeValues(0, 1000),
          heightRange: heightRange,
          weightRange: weightRange,
        );

        return filterOutcome;
      }
      
      // Sem filtros, busca detalhes apenas para a página atual
      final int endIndex = offset + pageSize;
      final resultsToFetchDetails = results.length > offset
          ? List<Map<String, dynamic>>.from(
              results.sublist(offset, endIndex > results.length ? results.length : endIndex),
            )
          : <Map<String, dynamic>>[];

      if (resultsToFetchDetails.isEmpty) {
        return {'pokemons': <Pokemon>[], 'total': totalApiPokemons};
      }
      
      // Buscar detalhes dos Pokémon selecionados
      final fetchedPokemons = await _fetchPokemonDetails(resultsToFetchDetails);
      
      if (fetchedPokemons.isEmpty) {
        return {'pokemons': <Pokemon>[], 'total': totalApiPokemons};
      }

      // Ordenar
      fetchedPokemons.sort((a, b) => a.id.compareTo(b.id));

      return {
        'pokemons': fetchedPokemons,
        'total': totalApiPokemons,
      };
    } catch (e) {
      print('Erro geral ao carregar lista de Pokémon: $e');
      return {'pokemons': _getDefaultPokemons(), 'total': 10};
    }
  }

  Future<Map<String, dynamic>> _applyFiltersAndPaginate({
    required List<Map<String, dynamic>> filteredResults,
    required int page,
    required Map<String, bool> selectedTypes,
    required int selectedGeneration,
    required RangeValues powerRange,
    RangeValues? heightRange,
    RangeValues? weightRange,
  }) async {
    if (filteredResults.isEmpty) {
      return {'pokemons': <Pokemon>[], 'total': 0};
    }

    final int offset = (page - 1) * pageSize;
    final bool hasPowerFilter = powerRange != const RangeValues(0, 1000);
    final bool hasTypeFilter = selectedTypes.values.contains(true);
    final bool hasHeightFilter =
        heightRange != null && heightRange != const RangeValues(0, 20);
    final bool hasWeightFilter =
        weightRange != null && weightRange != const RangeValues(0, 1000);
    final bool onlyGenerationFilter = selectedGeneration > 0 &&
        !hasTypeFilter &&
        !hasPowerFilter &&
        !hasHeightFilter &&
        !hasWeightFilter;

    if (onlyGenerationFilter) {
      final int totalMatches = filteredResults.length;
      if (offset >= totalMatches) {
        return {'pokemons': <Pokemon>[], 'total': totalMatches};
      }

      final int endIndex = min(offset + pageSize, totalMatches);
      final slice = filteredResults.sublist(offset, endIndex);
      final pokemons = await _fetchPokemonDetails(slice);
      pokemons.sort((a, b) => a.id.compareTo(b.id));

      return {
        'pokemons': pokemons,
        'total': totalMatches,
      };
    }

    int matchedCount = 0;
    final List<Pokemon> pagePokemons = [];
    const int chunkSize = 40;

    for (int start = 0; start < filteredResults.length; start += chunkSize) {
      final chunk = filteredResults.sublist(
        start,
        min(start + chunkSize, filteredResults.length),
      );

      final chunkPokemons = await _fetchPokemonDetails(chunk);
      if (chunkPokemons.isEmpty) continue;

      if (hasPowerFilter) {
        await _ensureStatsForFilter(chunkPokemons, powerRange);
      }

      for (final pokemon in chunkPokemons) {
        final includePokemon = PokemonFilterService.shouldIncludePokemon(
          pokemon: pokemon,
          selectedTypes: selectedTypes,
          selectedGeneration: selectedGeneration,
          powerRange: powerRange,
          statsCache: _statsCache,
          heightRange: heightRange,
          weightRange: weightRange,
        );

        if (!includePokemon) {
          continue;
        }

        matchedCount++;
        if (matchedCount > offset && pagePokemons.length < pageSize) {
          pagePokemons.add(pokemon);
        }
      }
    }

    pagePokemons.sort((a, b) => a.id.compareTo(b.id));

    return {
      'pokemons': pagePokemons,
      'total': matchedCount,
    };
  }

  // Método auxiliar para pré-filtrar resultados sem buscar detalhes
  Future<List<Map<String, dynamic>>> _preFilterResults(
    List results,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
    RangeValues? heightRange,
    RangeValues? weightRange,
  ) async {
    final filteredResults = <Map<String, dynamic>>[];

    final List<String> selectedTypeNames = selectedTypes != null
        ? selectedTypes.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key.toLowerCase())
            .toList()
        : <String>[];

    Set<int>? allowedTypeIds;
    if (selectedTypeNames.isNotEmpty) {
      allowedTypeIds = <int>{};
      for (final typeName in selectedTypeNames) {
        final idsForType = await _fetchTypePokemonIds(typeName);
        allowedTypeIds.addAll(idsForType);
      }
    }

    for (final result in results) {
      if (result is! Map<String, dynamic>) continue;

      final pokemonUrl = result['url'] as String?;
      if (pokemonUrl == null) continue;

      final segments = pokemonUrl.split('/');
      if (segments.length < 7) continue;

      final pokemonId = int.tryParse(segments[6]);
      if (pokemonId == null) continue;

      if (selectedGeneration != null && selectedGeneration > 0) {
        final generation = _getPokemonGeneration(pokemonId);
        if (generation != selectedGeneration) {
          continue;
        }
      }

      if (allowedTypeIds != null &&
          allowedTypeIds.isNotEmpty &&
          !allowedTypeIds.contains(pokemonId)) {
        continue;
      }

      // Verificar se já temos dados em cache para aplicar filtros adicionais
      final cachedPokemon = PokemonCacheService.getPokemon(pokemonId);
      if (cachedPokemon != null) {
        if (selectedTypeNames.isNotEmpty) {
          final pokemonTypes =
              cachedPokemon.types.map((t) => t.toLowerCase()).toList();
          final hasAnySelectedType =
              selectedTypeNames.any((selectedType) => pokemonTypes.contains(selectedType));

          if (!hasAnySelectedType) {
            continue;
          }
        }

        if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
          final stats = PokemonCacheService.getStats(pokemonId);
          if (stats != null && stats.isNotEmpty) {
            final totalPower = stats.values.reduce((a, b) => a + b);
            if (totalPower < powerRange.start || totalPower > powerRange.end) {
              continue;
            }
          }
        }

        if (heightRange != null && heightRange != const RangeValues(0, 20)) {
          final h = cachedPokemon.heightMeters;
          if (h == null || h < heightRange.start || h > heightRange.end) {
            continue;
          }
        }

        if (weightRange != null && weightRange != const RangeValues(0, 1000)) {
          final w = cachedPokemon.weightKg;
          if (w == null || w < weightRange.start || w > weightRange.end) {
            continue;
          }
        }
      }

      filteredResults.add(Map<String, dynamic>.from(result));
    }

    return filteredResults;
  }

  Future<Set<int>> _fetchTypePokemonIds(String typeName) async {
    final key = typeName.toLowerCase();
    if (_typePokemonCache.containsKey(key)) {
      return _typePokemonCache[key]!;
    }

    try {
      final response = await http
          .get(Uri.parse('https://pokeapi.co/api/v2/type/$key'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print(
            'Falha ao carregar Pokémon para o tipo $typeName: ${response.statusCode}');
        _typePokemonCache[key] = <int>{};
        return _typePokemonCache[key]!;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final List pokemonList = data['pokemon'] ?? [];
      final ids = <int>{};

      for (final entry in pokemonList) {
        if (entry is! Map<String, dynamic>) continue;
        final pokemonData = entry['pokemon'];
        if (pokemonData is! Map<String, dynamic>) continue;
        final url = pokemonData['url'] as String?;
        if (url == null) continue;

        final segments = url.split('/');
        if (segments.length < 7) continue;

        final pokemonId = int.tryParse(segments[6]);
        if (pokemonId != null) {
          ids.add(pokemonId);
        }
      }

      _typePokemonCache[key] = ids;
      return ids;
    } catch (e) {
      print('Erro ao buscar Pokémon para o tipo $typeName: $e');
      _typePokemonCache[key] = <int>{};
      return _typePokemonCache[key]!;
    }
  }

  // Método auxiliar para buscar detalhes dos Pokémon
  Future<List<Pokemon>> _fetchPokemonDetails(List<Map<String, dynamic>> pokemonList) async {
    final futures = pokemonList.map((pokemon) async {
      try {
        final pokemonUrl = pokemon['url'] as String;
        final pokemonId = int.parse(pokemonUrl.split('/')[6]);

        // Verificar cache inteligente primeiro
        final cachedPokemon = PokemonCacheService.getPokemon(pokemonId);
        if (cachedPokemon != null) {
          return cachedPokemon;
        }

        // Verificar cache legado
        if (_pokemonCache.containsKey(pokemonId)) {
          return _pokemonCache[pokemonId]!;
        }

        final detailResponse = await http.get(Uri.parse(pokemonUrl))
            .timeout(const Duration(seconds: 10));
            
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          final pokemonObj = Pokemon.fromDetailJson(detailData);
          
          // Salvar no cache legado
          _pokemonCache[pokemonId] = pokemonObj;
          
          // Salvar no cache inteligente
          await PokemonCacheService.setPokemon(pokemonObj);
          
          return pokemonObj;
        } else {
          return null;
        }
      } catch (e) {
        return null;
      }
    }).toList();

    try {
      final detailResults = await Future.wait(futures, eagerError: false);
      return detailResults
          .whereType<Pokemon>()
          .toList();
    } catch (e) {
      print('Erro ao processar resultados dos detalhes: $e');
      return [];
    }
  }

  // Função auxiliar para garantir que os stats necessários para o filtro de poder estejam no cache
  Future<void> _ensureStatsForFilter(List<Pokemon> pokemonsToFilter, RangeValues? powerRange) async {
    if (powerRange == null || powerRange == const RangeValues(0, 1000)) {
      return; // Não precisa buscar stats se o filtro de poder não está ativo
    }

    final List<Future<void>> statFutures = [];
    for (var pokemon in pokemonsToFilter) {
      final cachedStats = PokemonCacheService.getStats(pokemon.id);
      if (cachedStats != null && cachedStats.isNotEmpty) {
        _statsCache[pokemon.id] = cachedStats;
        continue;
      }

      if (_statsCache.containsKey(pokemon.id) && _statsCache[pokemon.id]!.isNotEmpty) {
        continue;
      }

      // Verificar cache inteligente primeiro, depois legado
      statFutures.add(fetchPokemonStats(pokemon.id).then((stats) {
        if (stats != null && stats.isNotEmpty) {
          _statsCache[pokemon.id] = stats;
        }
      }));
    }

    if (statFutures.isNotEmpty) {
      print('Buscando stats para ${statFutures.length} Pokémon para aplicar filtro de poder...');
      await Future.wait(statFutures, eagerError: false).catchError((e) {
        print("Erro ao buscar alguns stats para filtro: $e. Filtro de poder pode estar incompleto.");
        return <void>[]; // Retorna lista vazia em caso de erro
      });
      print('Stats para filtro carregados.');
    }
  }

  // Adicione ou modifique fetchPokemonStats para usar o cache e tratar erros
  Future<Map<String, int>?> fetchPokemonStats(int pokemonId) async {
    // Verificar cache inteligente primeiro
    final cachedStats = PokemonCacheService.getStats(pokemonId);
    if (cachedStats != null) {
      return cachedStats;
    }
    
    if (_statsCache.containsKey(pokemonId)) {
      // Retorna o valor do cache se já existir (pode ser null se falhou antes)
      return _statsCache[pokemonId];
    }
    try {
      print('Buscando stats para ID $pokemonId...');
      final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$pokemonId')).timeout(const Duration(seconds: 7)); // Timeout um pouco menor
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final stats = <String, int>{};
        int totalPower = 0;
        for (var statInfo in data['stats']) {
          final value = statInfo['base_stat'] as int;
          stats[statInfo['stat']['name']] = value;
          totalPower += value; // Calcular poder total aqui
        }
        // Adiciona o poder total ao cache para referência rápida, se necessário
        stats['total_power'] = totalPower;
        print('Stats para ID $pokemonId carregados. Poder total: $totalPower');
        
        // Salvar no cache legado
        _statsCache[pokemonId] = stats;
        
        // Salvar no cache inteligente
        await PokemonCacheService.setStats(pokemonId, stats);
        
        return stats;
      } else {
        print('Erro ao buscar stats para ID $pokemonId: ${response.statusCode}');
        _statsCache[pokemonId] = {}; // Armazena um mapa vazio para indicar falha
        return null;
      }
    } catch (e) {
      print('Erro na requisição de stats para ID $pokemonId: $e');
      _statsCache[pokemonId] = {}; // Armazena um mapa vazio para indicar falha
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
  RangeValues? heightRange,
  RangeValues? weightRange,
  }) async {
    if (query.isEmpty && (selectedTypes == null || selectedTypes.isEmpty) && 
        selectedGeneration == null && powerRange == null) {
      return [];
    }

    // Inicializar cache se não foi inicializado
    await PokemonCacheService.initialize();

    // Primeiro tenta busca no cache inteligente
    final cachedResults = PokemonCacheService.searchPokemons(query);
    if (cachedResults.isNotEmpty) {
      print('Encontrados ${cachedResults.length} resultados no cache para: $query');
      
      // Aplicar filtros nos resultados do cache
      final filteredResults = cachedResults.where((pokemon) {
        return PokemonFilterService.shouldIncludePokemon(
          pokemon: pokemon,
          selectedTypes: selectedTypes ?? {},
          selectedGeneration: selectedGeneration ?? 0,
          powerRange: powerRange ?? const RangeValues(0, 1000),
          statsCache: {}, // O cache de stats é interno do PokemonCacheService
          heightRange: heightRange,
          weightRange: weightRange,
        );
      }).toList();
      
      if (filteredResults.isNotEmpty) {
        return filteredResults;
      }
    }

    // Verificar cache legado para consultas repetidas
    final cacheKey = '${query}_${selectedTypes}_${selectedGeneration}_${powerRange?.start}_${powerRange?.end}';
    if (_searchCache.containsKey(cacheKey)) {
      print('Usando resultados em cache legado para: $query');
      return _searchCache[cacheKey]!;
    }

    try {
      // Aumentar o limite para 1000 Pokémon
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      ).timeout(const Duration(seconds: 15));
      
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

          // Verificar cache inteligente primeiro
          final cachedPokemon = PokemonCacheService.getPokemon(pokemonId);
          if (cachedPokemon != null) {
            return cachedPokemon;
          }

          // Verificar cache legado
          if (_pokemonCache.containsKey(pokemonId)) {
            return _pokemonCache[pokemonId]!;
          }

          final detailResponse = await http.get(Uri.parse(pokemonUrl))
              .timeout(const Duration(seconds: 10));
              
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            final pokemonObj = Pokemon.fromDetailJson(detailData);
            
            // Salvar no cache legado
            _pokemonCache[pokemonId] = pokemonObj;
            
            // Salvar no cache inteligente
            await PokemonCacheService.setPokemon(pokemonObj);
            
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
            .whereType<Pokemon>() // Garante que é um Pokemon
            .map((result) => result)   // Converte com segurança
            .toList();
      } catch (e) {
        print('Erro ao processar resultados da busca: $e');
        // Continuar com os Pokémon que foram carregados com sucesso
      }

      if (pokemons.isEmpty) {
        // Retornar lista vazia em vez de padrão pode ser melhor para busca
        return []; // Alterado de _getDefaultPokemons()
      }

      // Aplicar filtros adicionais pós-busca (tipo, geração, PODER)
      // Garantir que os stats necessários para o filtro de poder estejam carregados
      await _ensureStatsForFilter(pokemons, powerRange);

      final postFilteredPokemons = pokemons.where((pokemon) {
         // REUTILIZAR A LÓGICA CENTRALIZADA DE FILTRO
         return PokemonFilterService.shouldIncludePokemon(
           pokemon: pokemon,
           selectedTypes: selectedTypes ?? {},
           selectedGeneration: selectedGeneration ?? 0,
           powerRange: powerRange ?? const RangeValues(0, 1000),
           statsCache: _statsCache,
           heightRange: heightRange,
           weightRange: weightRange,
         );
      }).toList();

      // Ordenar por ID
      postFilteredPokemons.sort((a, b) => a.id.compareTo(b.id));
      
      // Armazenar em cache
      _searchCache[cacheKey] = postFilteredPokemons;
      
      print('Busca por "$query" com filtros retornou ${postFilteredPokemons.length} Pokémon.');
      return postFilteredPokemons;
    } catch (e) {
      print('Erro na busca de Pokémon: $e');
      // Retornar lista vazia em caso de erro na busca
      return []; // Alterado de _getDefaultPokemons()
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
