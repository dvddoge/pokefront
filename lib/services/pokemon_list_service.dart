import 'dart:convert';
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
  }) async {
    int offset = (page - 1) * pageSize;
    
    // Verificar se há filtros ativos
    bool hasActiveFilters = (selectedTypes?.values.contains(true) ?? false) ||
                           (selectedGeneration != null && selectedGeneration > 0) ||
                           (powerRange != null && powerRange != const RangeValues(0, 1000));
    
    // Verificar se há filtro de poder ativo
    bool hasPowerFilter = powerRange != null && powerRange != const RangeValues(0, 1000);
    
    try {
      // Inicializar cache inteligente
      await PokemonCacheService.initialize();
      
      // Primeira tentativa: buscar resultados filtrados do cache inteligente
      if (hasActiveFilters) {
        final cachedResults = await _tryGetFilteredFromCache(
          selectedTypes: selectedTypes,
          selectedGeneration: selectedGeneration,
          powerRange: powerRange,
          page: page,
        );
        
        if (cachedResults.isNotEmpty) {
          print('Usando resultados filtrados do cache para página $page');
          return {
            'pokemons': cachedResults,
            'total': await _getFilteredTotal(selectedTypes, selectedGeneration, powerRange),
          };
        }
      }

      // Buscar lista base de nomes/URLs com persistência simples em memória/disco
      final List results = await _getBaseListResults();
      final int totalApiPokemons = results.length;
      
       if (results.isEmpty) {
        print('Nenhum resultado encontrado na API');
        return {'pokemons': _getDefaultPokemons(), 'total': 10};
      }

      List<Map<String, dynamic>> resultsToFetchDetails;
      
      if (hasActiveFilters) {
        // OTIMIZAÇÃO: Aplicar filtros básicos ANTES de buscar detalhes
        resultsToFetchDetails = await _preFilterResults(
          results, 
          selectedTypes, 
          selectedGeneration, 
          powerRange
        );
        
        // Aplicar paginação nos resultados pré-filtrados
        final startIndex = offset;
        final endIndex = startIndex + pageSize;
        resultsToFetchDetails = resultsToFetchDetails.length > startIndex 
            ? resultsToFetchDetails.sublist(startIndex, endIndex > resultsToFetchDetails.length ? resultsToFetchDetails.length : endIndex)
            : [];
            
        print('Filtros aplicados. Buscando detalhes de ${resultsToFetchDetails.length} Pokémon para página $page');
      } else {
        // Sem filtros, busca detalhes apenas para a página atual
        final int startIndex = offset;
        final int endIndex = startIndex + pageSize;
        resultsToFetchDetails = results.length > startIndex 
            ? List<Map<String, dynamic>>.from(results.sublist(startIndex, endIndex > results.length ? results.length : endIndex)) 
            : [];
      }
      
      if (resultsToFetchDetails.isEmpty) {
        return {'pokemons': [], 'total': hasActiveFilters ? 0 : totalApiPokemons};
      }
      
      // Buscar detalhes dos Pokémon selecionados
      final fetchedPokemons = await _fetchPokemonDetails(resultsToFetchDetails);
      
      if (fetchedPokemons.isEmpty) {
        return {'pokemons': [], 'total': hasActiveFilters ? 0 : totalApiPokemons};
      }

      // Aplicar filtros finais (principalmente filtro de poder se necessário)
      List<Pokemon> finalPokemonList = fetchedPokemons;
      
      if (hasPowerFilter) {
        // Buscar stats apenas para os Pokémon que chegaram até aqui
        await _ensureStatsForFilter(fetchedPokemons, powerRange);
        
        finalPokemonList = fetchedPokemons.where((pokemon) {
          return PokemonFilterService.shouldIncludePokemon(
            pokemon: pokemon,
            selectedTypes: {},  // Filtros de tipo já aplicados
            selectedGeneration: 0,  // Filtro de geração já aplicado
            powerRange: powerRange,
            statsCache: _statsCache,
          );
        }).toList();
      }

      // Ordenar
      finalPokemonList.sort((a, b) => a.id.compareTo(b.id));

      // Salvar no cache inteligente
      for (final pokemon in finalPokemonList) {
        await PokemonCacheService.setPokemon(pokemon);
      }

      final totalCount = hasActiveFilters 
          ? await _getFilteredTotal(selectedTypes, selectedGeneration, powerRange)
          : totalApiPokemons;

      return {
        'pokemons': finalPokemonList,
        'total': totalCount,
      };
    } catch (e) {
      print('Erro geral ao carregar lista de Pokémon: $e');
      return {'pokemons': _getDefaultPokemons(), 'total': 10};
    }
  }

  static List? _cachedBaseResults;
  static DateTime? _cachedBaseResultsAt;
  static const _baseResultsTtl = Duration(hours: 12);

  Future<List> _getBaseListResults() async {
    if (_cachedBaseResults != null &&
        _cachedBaseResultsAt != null &&
        DateTime.now().difference(_cachedBaseResultsAt!) < _baseResultsTtl) {
      return _cachedBaseResults!;
    }

    // Tenta do disco via PokemonCacheService
    final diskList = await PokemonCacheService.getBaseListIfFresh(_baseResultsTtl);
    if (diskList.isNotEmpty) {
      _cachedBaseResults = diskList;
      _cachedBaseResultsAt = DateTime.now();
      return diskList;
    }

    try {
      final response = await http
          .get(Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000&offset=0'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        _cachedBaseResults = results;
        _cachedBaseResultsAt = DateTime.now();
        await PokemonCacheService.saveBaseList(results);
        return results;
      }
    } catch (_) {}
    return [];
  }

  // Método auxiliar para pré-filtrar resultados sem buscar detalhes
  Future<List<Map<String, dynamic>>> _preFilterResults(
    List results,
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  ) async {
    List<Map<String, dynamic>> filteredResults = [];
    
    for (final result in results) {
      final pokemonUrl = result['url'] as String;
      final pokemonId = int.parse(pokemonUrl.split('/')[6]);
      
      // Aplicar filtro de geração (não precisa de requisição)
      if (selectedGeneration != null && selectedGeneration > 0) {
        final generation = _getPokemonGeneration(pokemonId);
        if (generation != selectedGeneration) {
          continue;
        }
      }
      
      // Verificar se já temos dados em cache para aplicar outros filtros
      final cachedPokemon = PokemonCacheService.getPokemon(pokemonId);
      if (cachedPokemon != null) {
        // Aplicar filtros usando dados do cache
        if (selectedTypes != null && selectedTypes.isNotEmpty) {
          final selectedTypesList = selectedTypes.entries
              .where((entry) => entry.value)
              .map((entry) => entry.key)
              .toList();
          
          final hasAnySelectedType = selectedTypesList.any((selectedType) =>
            cachedPokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
          );
          
          if (!hasAnySelectedType) continue;
        }
        
        // Filtro de poder (se temos stats em cache)
        if (powerRange != null && powerRange != const RangeValues(0, 1000)) {
          final stats = PokemonCacheService.getStats(pokemonId);
          if (stats != null) {
            final keys = const ['hp','attack','defense','special-attack','special-defense','speed'];
            int totalPower = 0;
            for (final k in keys) {
              if (stats.containsKey(k)) totalPower += stats[k]!;
            }
            if (totalPower == 0) {
              totalPower = stats.entries
                  .where((e) => e.key != 'total_power')
                  .fold<int>(0, (sum, e) => sum + e.value);
            }
            if (totalPower < powerRange.start || totalPower > powerRange.end) {
              continue;
            }
          }
        }
      }
      
      filteredResults.add(result);
    }
    
    return filteredResults;
  }

  // Método auxiliar para tentar obter resultados filtrados do cache
  Future<List<Pokemon>> _tryGetFilteredFromCache({
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
    int page = 1,
  }) async {
    try {
      // Implementar lógica para buscar do cache inteligente
      final allCachedPokemons = PokemonCacheService.getAllCachedPokemons();
      if (allCachedPokemons.isEmpty) return [];
      
      // Aplicar filtros usando stats do cache inteligente quando disponíveis
      final Map<int, Map<String, int>> statsForCached = {};
      for (final p in allCachedPokemons) {
        final s = PokemonCacheService.getStats(p.id);
        if (s != null) statsForCached[p.id] = s;
      }
      final filteredPokemons = allCachedPokemons.where((pokemon) {
        return PokemonFilterService.shouldIncludePokemon(
          pokemon: pokemon,
          selectedTypes: selectedTypes ?? {},
          selectedGeneration: selectedGeneration ?? 0,
          powerRange: powerRange ?? const RangeValues(0, 1000),
          statsCache: statsForCached,
        );
      }).toList();
      
      // Aplicar paginação
      final int offset = (page - 1) * pageSize;
      final int startIndex = offset;
      final int endIndex = startIndex + pageSize;
      
      if (filteredPokemons.length <= startIndex) return [];
      
      return filteredPokemons.sublist(
        startIndex, 
        endIndex > filteredPokemons.length ? filteredPokemons.length : endIndex
      );
    } catch (e) {
      print('Erro ao buscar do cache: $e');
      return [];
    }
  }

  // Método auxiliar para obter o total de resultados filtrados
  Future<int> _getFilteredTotal(
    Map<String, bool>? selectedTypes,
    int? selectedGeneration,
    RangeValues? powerRange,
  ) async {
    try {
      final allCachedPokemons = PokemonCacheService.getAllCachedPokemons();
      if (allCachedPokemons.isEmpty) return 0;
      final Map<int, Map<String, int>> statsForCached = {};
      for (final p in allCachedPokemons) {
        final s = PokemonCacheService.getStats(p.id);
        if (s != null) statsForCached[p.id] = s;
      }

      final filteredPokemons = allCachedPokemons.where((pokemon) {
        return PokemonFilterService.shouldIncludePokemon(
          pokemon: pokemon,
          selectedTypes: selectedTypes ?? {},
          selectedGeneration: selectedGeneration ?? 0,
          powerRange: powerRange ?? const RangeValues(0, 1000),
          statsCache: statsForCached,
        );
      }).toList();
      
      return filteredPokemons.length;
    } catch (e) {
      print('Erro ao calcular total filtrado: $e');
      return 0;
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

    List<Future<void>> statFutures = [];
    for (var pokemon in pokemonsToFilter) {
      // Verificar cache inteligente primeiro, depois legado
      if (!PokemonCacheService.hasStats(pokemon.id) && !_statsCache.containsKey(pokemon.id)) {
        statFutures.add(fetchPokemonStats(pokemon.id)); // fetchPokemonStats deve adicionar ao _statsCache
      }
    }

    if (statFutures.isNotEmpty) {
      print('Buscando stats para ${statFutures.length} Pokémon para aplicar filtro de poder...');
      await Future.wait(statFutures).catchError((e) {
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
      final Map<int, Map<String, int>> statsForCached = {};
      for (final p in cachedResults) {
        final s = PokemonCacheService.getStats(p.id);
        if (s != null) statsForCached[p.id] = s;
      }
      final filteredResults = cachedResults.where((pokemon) {
        return PokemonFilterService.shouldIncludePokemon(
          pokemon: pokemon,
          selectedTypes: selectedTypes ?? {},
          selectedGeneration: selectedGeneration ?? 0,
          powerRange: powerRange ?? const RangeValues(0, 1000),
          statsCache: statsForCached,
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