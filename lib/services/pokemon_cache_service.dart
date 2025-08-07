import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pokemon.dart';
import 'pokemon_list_service.dart';

class PokemonCacheService {
  static const String _pokemonCacheKey = 'pokemon_cache';
  static const String _searchIndexKey = 'search_index';
  static const String _metadataKey = 'cache_metadata';
  static const String _statsKey = 'pokemon_stats';
  static const String _baseListKey = 'pokemon_base_list';
  static const String _baseListUpdatedKey = 'pokemon_base_list_updated_at';
  static const int _maxCacheSize = 500; // Máximo de 500 Pokémon em cache
  static const int _cacheExpirationDays = 7; // Cache expira em 7 dias
  
  static SharedPreferences? _prefs;
  static Map<int, Pokemon> _memoryCache = {};
  static Map<String, List<int>> _searchIndex = {}; // Índice de busca: palavra -> [ids]
  static Map<int, Map<String, int>> _statsCache = {};
  static Map<int, DateTime> _lastAccessTime = {};
  static PokemonListService? _pokemonListService;
  
  // Inicialização do cache
  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadFromDisk();
    await _buildSearchIndex();
    print('PokemonCacheService inicializado com ${_memoryCache.length} Pokémon em cache');
  }
  
  // Carrega dados do disco para memória
  static Future<void> _loadFromDisk() async {
    try {
      // Carregar metadados para verificar expiração
      final metadataJson = _prefs!.getString(_metadataKey);
      if (metadataJson != null) {
        final metadata = json.decode(metadataJson);
        final cacheDate = DateTime.parse(metadata['created_at']);
        
        // Verifica se o cache expirou
        if (DateTime.now().difference(cacheDate).inDays > _cacheExpirationDays) {
          print('Cache expirado, limpando...');
          await clearCache();
          return;
        }
      }
      
      // Carregar Pokémon
      final pokemonJson = _prefs!.getString(_pokemonCacheKey);
      if (pokemonJson != null) {
        final pokemonData = json.decode(pokemonJson) as Map<String, dynamic>;
        _memoryCache = pokemonData.map((key, value) => 
          MapEntry(int.parse(key), Pokemon.fromJsonCache(value))
        );
      }
      
      // Carregar stats
      final statsJson = _prefs!.getString(_statsKey);
      if (statsJson != null) {
        final statsData = json.decode(statsJson) as Map<String, dynamic>;
        _statsCache = statsData.map((key, value) => 
          MapEntry(int.parse(key), Map<String, int>.from(value))
        );
      }
      
      // Carregar índice de busca
      final indexJson = _prefs!.getString(_searchIndexKey);
      if (indexJson != null) {
        final indexData = json.decode(indexJson) as Map<String, dynamic>;
        _searchIndex = indexData.map((key, value) => 
          MapEntry(key, List<int>.from(value))
        );
      }
      
    } catch (e) {
      print('Erro ao carregar cache do disco: $e');
      await clearCache();
    }
  }
  
  // Salva dados da memória para o disco
  static Future<void> _saveToDisk() async {
    try {
      // Aplicar estratégia LRU se necessário
      await _applyLRU();
      
      // Salvar Pokémon
      final pokemonData = _memoryCache.map((key, value) => 
        MapEntry(key.toString(), value.toJson())
      );
      await _prefs!.setString(_pokemonCacheKey, json.encode(pokemonData));
      
      // Salvar stats
      final statsData = _statsCache.map((key, value) => 
        MapEntry(key.toString(), value)
      );
      await _prefs!.setString(_statsKey, json.encode(statsData));
      
      // Salvar índice de busca
      await _prefs!.setString(_searchIndexKey, json.encode(_searchIndex));
      
      // Salvar metadados
      final metadata = {
        'created_at': DateTime.now().toIso8601String(),
        'pokemon_count': _memoryCache.length,
        'stats_count': _statsCache.length,
      };
      await _prefs!.setString(_metadataKey, json.encode(metadata));
      
    } catch (e) {
      print('Erro ao salvar cache no disco: $e');
    }
  }

  // Base list (nomes/URLs) persistence helpers
  static Future<List> getBaseListIfFresh(Duration ttl) async {
    try {
      final updatedAtStr = _prefs!.getString(_baseListUpdatedKey);
      final dataStr = _prefs!.getString(_baseListKey);
      if (updatedAtStr == null || dataStr == null) return [];
      final updatedAt = DateTime.tryParse(updatedAtStr);
      if (updatedAt == null) return [];
      if (DateTime.now().difference(updatedAt) > ttl) return [];
      final decoded = json.decode(dataStr);
      if (decoded is List) {
        return decoded;
      }
    } catch (e) {
      print('Erro ao ler base list do disco: $e');
    }
    return [];
  }

  static Future<void> saveBaseList(List baseList) async {
    try {
      await _prefs!.setString(_baseListKey, json.encode(baseList));
      await _prefs!.setString(_baseListUpdatedKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Erro ao salvar base list no disco: $e');
    }
  }
  
  // Aplicar estratégia LRU (Least Recently Used)
  static Future<void> _applyLRU() async {
    if (_memoryCache.length <= _maxCacheSize) return;
    
    // Ordenar por último acesso
    final sortedByAccess = _lastAccessTime.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // Remover os mais antigos
    final toRemove = sortedByAccess.take(_memoryCache.length - _maxCacheSize);
    for (final entry in toRemove) {
      _memoryCache.remove(entry.key);
      _statsCache.remove(entry.key);
      _lastAccessTime.remove(entry.key);
    }
    
    print('Cache LRU aplicado: removidos ${toRemove.length} itens');
  }
  
  // Construir índice de busca para busca rápida
  static Future<void> _buildSearchIndex() async {
    _searchIndex.clear();
    
    for (final pokemon in _memoryCache.values) {
      _indexPokemon(pokemon);
    }
  }
  
  // Indexar um Pokémon específico
  static void _indexPokemon(Pokemon pokemon) {
    final words = _extractSearchWords(pokemon);
    
    for (final word in words) {
      _searchIndex[word] = _searchIndex[word] ?? [];
      if (!_searchIndex[word]!.contains(pokemon.id)) {
        _searchIndex[word]!.add(pokemon.id);
      }
    }
  }
  
  // Extrair palavras para busca de um Pokémon
  static Set<String> _extractSearchWords(Pokemon pokemon) {
    final words = <String>{};
    
    // Nome completo e parcial
    words.add(pokemon.name.toLowerCase());
    
    // Palavras do nome (para nomes compostos)
    words.addAll(pokemon.name.toLowerCase().split(RegExp(r'[-_\s]')));
    
    // Tipos
    words.addAll(pokemon.types.map((t) => t.toLowerCase()));
    
    // Prefixos do nome (para busca parcial)
    for (int i = 1; i <= pokemon.name.length; i++) {
      words.add(pokemon.name.toLowerCase().substring(0, i));
    }
    
    return words;
  }
  
  // Getter para Pokémon com atualização de último acesso
  static Pokemon? getPokemon(int id) {
    final pokemon = _memoryCache[id];
    if (pokemon != null) {
      _lastAccessTime[id] = DateTime.now();
      print('Cache: Pokémon ${pokemon.name} (ID: $id) encontrado no cache');
    } else {
      print('Cache: Pokémon ID $id NÃO encontrado no cache');
    }
    return pokemon;
  }
  
  // Setter para Pokémon com indexação automática
  static Future<void> setPokemon(Pokemon pokemon) async {
    _memoryCache[pokemon.id] = pokemon;
    _lastAccessTime[pokemon.id] = DateTime.now();
    _indexPokemon(pokemon);
    
    print('Cache: Pokémon ${pokemon.name} (ID: ${pokemon.id}) adicionado. Total em cache: ${_memoryCache.length}');
    
    // Salvar periodicamente (a cada 10 novos Pokémon)
    if (_memoryCache.length % 10 == 0) {
      print('Cache: Salvando no disco (${_memoryCache.length} Pokémon)');
      await _saveToDisk();
    }
  }
  
  // Getter para stats
  static Map<String, int>? getStats(int pokemonId) {
    final stats = _statsCache[pokemonId];
    if (stats != null) {
      _lastAccessTime[pokemonId] = DateTime.now();
    }
    return stats;
  }
  
  // Setter para stats
  static Future<void> setStats(int pokemonId, Map<String, int> stats) async {
    _statsCache[pokemonId] = stats;
    _lastAccessTime[pokemonId] = DateTime.now();
    
    // Salvar periodicamente
    if (_statsCache.length % 10 == 0) {
      await _saveToDisk();
    }
  }
  
  // Busca rápida usando índice
  static List<int> searchPokemonIds(String query) {
    if (query.isEmpty) return [];
    
    final queryLower = query.toLowerCase();
    final results = <int>{};
    
    // Busca exata
    if (_searchIndex.containsKey(queryLower)) {
      results.addAll(_searchIndex[queryLower]!);
    }
    
    // Busca por prefixo
    for (final indexKey in _searchIndex.keys) {
      if (indexKey.startsWith(queryLower)) {
        results.addAll(_searchIndex[indexKey]!);
      }
    }
    
    // Busca contém (fuzzy)
    for (final indexKey in _searchIndex.keys) {
      if (indexKey.contains(queryLower)) {
        results.addAll(_searchIndex[indexKey]!);
      }
    }
    
    return results.toList()..sort();
  }
  
  // Busca de Pokémon com objetos completos
  static List<Pokemon> searchPokemons(String query) {
    final ids = searchPokemonIds(query);
    final pokemons = <Pokemon>[];
    
    for (final id in ids) {
      final pokemon = getPokemon(id);
      if (pokemon != null) {
        pokemons.add(pokemon);
      }
    }
    
    return pokemons;
  }
  
  // Método para obter todos os Pokémon do cache
  static List<Pokemon> getAllCachedPokemons() {
    return _memoryCache.values.toList();
  }

  // Método para verificar se um Pokémon está no cache
  static bool hasPokemon(int pokemonId) {
    return _memoryCache.containsKey(pokemonId);
  }

  // Método para verificar se há stats no cache
  static bool hasStats(int pokemonId) {
    return _statsCache.containsKey(pokemonId);
  }

  // Método para obter estatísticas do cache
  static Map<String, int> getCacheStats() {
    return {
      'pokemon_count': _memoryCache.length,
      'stats_count': _statsCache.length,
      'search_terms': _searchIndex.length,
    };
  }
  
  // Obter múltiplos Pokémon de uma vez
  static Map<int, Pokemon> getMultiplePokemons(List<int> ids) {
    final result = <int, Pokemon>{};
    for (final id in ids) {
      final pokemon = getPokemon(id);
      if (pokemon != null) {
        result[id] = pokemon;
      }
    }
    return result;
  }
  
  // Estatísticas do cache
  static Map<String, dynamic> getCacheStatistics() {
    return {
      'pokemon_count': _memoryCache.length,
      'stats_count': _statsCache.length,
      'search_index_size': _searchIndex.length,
      'cache_hit_rate': _calculateHitRate(),
      'memory_usage_mb': _estimateMemoryUsage(),
      'last_save_time': _getLastSaveTime(),
      'cache_age_hours': _getCacheAgeHours(),
      'most_accessed_pokemon': _getMostAccessedPokemon(),
    };
  }
  
  static double _calculateHitRate() {
    if (_memoryCache.isEmpty) return 0.0;
    // Taxa de acerto baseada na proporção de Pokémon em cache
    return (_memoryCache.length / 1000.0).clamp(0.0, 1.0);
  }
  
  static double _estimateMemoryUsage() {
    // Estimativa aproximada em MB
    final pokemonSize = _memoryCache.length * 0.5; // ~0.5KB por Pokémon
    final indexSize = _searchIndex.length * 0.1; // ~0.1KB por entrada de índice
    final statsSize = _statsCache.length * 0.2; // ~0.2KB por stat
    return (pokemonSize + indexSize + statsSize) / 1000;
  }
  
  static String _getLastSaveTime() {
    // Retorna a hora da última gravação (simulada)
    return DateTime.now().toString().substring(11, 19);
  }
  
  static int _getCacheAgeHours() {
    // Simula idade do cache em horas
    if (_memoryCache.isEmpty) return 0;
    return DateTime.now().hour; // Simplificado
  }
  
  static String _getMostAccessedPokemon() {
    if (_lastAccessTime.isEmpty) return 'Nenhum';
    
    // Encontra o Pokémon mais acessado
    final mostAccessed = _lastAccessTime.entries
        .reduce((a, b) => a.value.isAfter(b.value) ? a : b);
    
    final pokemon = _memoryCache[mostAccessed.key];
    return pokemon?.name ?? 'ID: ${mostAccessed.key}';
  }
  
  // Definir instância do PokemonListService para limpar cache legado
  static void setPokemonListService(PokemonListService service) {
    _pokemonListService = service;
  }

  // Limpeza completa do cache
  static Future<void> clearCache() async {
    _memoryCache.clear();
    _searchIndex.clear();
    _statsCache.clear();
    _lastAccessTime.clear();
    
    await _prefs?.remove(_pokemonCacheKey);
    await _prefs?.remove(_searchIndexKey);
    await _prefs?.remove(_metadataKey);
    await _prefs?.remove(_statsKey);
    
    // Limpar também o cache legado
    _pokemonListService?.clearAllCaches();
    
    print('Cache inteligente e legado completamente limpos');
  }
  
  // Forçar salvamento no disco
  static Future<void> forceSave() async {
    await _saveToDisk();
  }
  
  // Pré-aquecer cache com Pokémon populares
  static Future<void> preWarmCache(List<Pokemon> pokemons) async {
    for (final pokemon in pokemons) {
      await setPokemon(pokemon);
    }
    await _saveToDisk();
    print('Cache pré-aquecido com ${pokemons.length} Pokémon');
  }
}