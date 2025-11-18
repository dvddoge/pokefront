import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/pokemon.dart';
import 'pokemon_list_service.dart';

class PokemonCacheService {
  static const String _pokemonBoxName = 'pokemon_cache_v1';
  static const String _statsBoxName = 'pokemon_stats_v1';
  static const String _metadataBoxName = 'cache_metadata_v1';

  static const int _maxCacheSize = 500; // Máximo de 500 Pokémon em cache
  static const int _cacheExpirationDays = 7; // Cache expira em 7 dias

  static late Box _pokemonBox;
  static late Box _statsBox;
  static late Box _metadataBox;

  static final Map<String, List<int>> _searchIndex =
      {}; // Índice de busca em memória
  static PokemonListService? _pokemonListService;

  // Inicialização do cache
  static Future<void> initialize() async {
    await Hive.initFlutter();

    _pokemonBox = await Hive.openBox(_pokemonBoxName);
    _statsBox = await Hive.openBox(_statsBoxName);
    _metadataBox = await Hive.openBox(_metadataBoxName);

    await _checkExpiration();
    await _buildSearchIndex();

    debugPrint(
        'PokemonCacheService (Hive) inicializado com ${_pokemonBox.length} Pokémon');
  }

  // Verifica expiração do cache
  static Future<void> _checkExpiration() async {
    final lastCleanup = _metadataBox.get('last_cleanup');
    if (lastCleanup != null) {
      final cleanupDate = DateTime.parse(lastCleanup);
      if (DateTime.now().difference(cleanupDate).inDays >
          _cacheExpirationDays) {
        debugPrint('Cache expirado, limpando...');
        await clearCache();
        return;
      }
    } else {
      await _metadataBox.put('last_cleanup', DateTime.now().toIso8601String());
    }
  }

  // Aplicar estratégia LRU (Least Recently Used)
  static Future<void> _applyLRU() async {
    if (_pokemonBox.length <= _maxCacheSize) return;

    // Como o Hive não tem timestamp nativo por entrada, simplificamos removendo os primeiros (FIFO)
    // ou poderíamos implementar um sistema de metadados mais complexo.
    // Para esta versão, vamos remover os primeiros 50 itens se passar do limite.

    final keysToRemove =
        _pokemonBox.keys.take(_pokemonBox.length - _maxCacheSize).toList();
    await _pokemonBox.deleteAll(keysToRemove);
    await _statsBox.deleteAll(keysToRemove);

    debugPrint('Cache LRU aplicado: removidos ${keysToRemove.length} itens');
  }

  // Construir índice de busca para busca rápida
  static Future<void> _buildSearchIndex() async {
    _searchIndex.clear();

    // Iterar sobre todos os valores do box é rápido no Hive
    for (var key in _pokemonBox.keys) {
      final jsonMap = Map<String, dynamic>.from(_pokemonBox.get(key));
      final pokemon = Pokemon.fromJsonCache(jsonMap);
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

  // Getter para Pokémon
  static Pokemon? getPokemon(int id) {
    final data = _pokemonBox.get(id);
    if (data != null) {
      // Converter Map<dynamic, dynamic> para Map<String, dynamic>
      final jsonMap = Map<String, dynamic>.from(data);
      return Pokemon.fromJsonCache(jsonMap);
    }
    return null;
  }

  // Setter para Pokémon com indexação automática
  static Future<void> setPokemon(Pokemon pokemon) async {
    await _pokemonBox.put(pokemon.id, pokemon.toJson());
    _indexPokemon(pokemon);

    // Verificar tamanho do cache periodicamente
    if (_pokemonBox.length % 50 == 0) {
      await _applyLRU();
    }
  }

  // Getter para stats
  static Map<String, int>? getStats(int pokemonId) {
    final data = _statsBox.get(pokemonId);
    if (data != null) {
      return Map<String, int>.from(data);
    }
    return null;
  }

  // Setter para stats
  static Future<void> setStats(int pokemonId, Map<String, int> stats) async {
    await _statsBox.put(pokemonId, stats);
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
    final pokemons = <Pokemon>[];
    for (var key in _pokemonBox.keys) {
      final data = _pokemonBox.get(key);
      if (data != null) {
        final jsonMap = Map<String, dynamic>.from(data);
        pokemons.add(Pokemon.fromJsonCache(jsonMap));
      }
    }
    return pokemons;
  }

  // Método para verificar se um Pokémon está no cache
  static bool hasPokemon(int pokemonId) {
    return _pokemonBox.containsKey(pokemonId);
  }

  // Método para verificar se há stats no cache
  static bool hasStats(int pokemonId) {
    return _statsBox.containsKey(pokemonId);
  }

  // Método para obter estatísticas do cache
  static Map<String, dynamic> getCacheStatistics() {
    return {
      'pokemon_count': _pokemonBox.isOpen ? _pokemonBox.length : 0,
      'stats_count': _statsBox.isOpen ? _statsBox.length : 0,
      'search_index_size': _searchIndex.length,
      'cache_hit_rate': _calculateHitRate(),
      'memory_usage_mb': _estimateMemoryUsage(),
      'storage_engine': 'Hive (NoSQL)',
    };
  }

  static double _calculateHitRate() {
    if (!_pokemonBox.isOpen || _pokemonBox.isEmpty) return 0.0;
    return (_pokemonBox.length / 1000.0).clamp(0.0, 1.0);
  }

  static double _estimateMemoryUsage() {
    // Hive é muito eficiente, o uso de memória é principalmente o índice
    // Estimativa grosseira
    return (_pokemonBox.length * 0.1) / 1000; // Muito menos memória que JSON
  }

  // Definir instância do PokemonListService para limpar cache legado
  static void setPokemonListService(PokemonListService service) {
    _pokemonListService = service;
  }

  // Limpeza completa do cache
  static Future<void> clearCache() async {
    await _pokemonBox.clear();
    await _statsBox.clear();
    await _metadataBox.clear();
    _searchIndex.clear();

    await _metadataBox.put('last_cleanup', DateTime.now().toIso8601String());

    // Limpar também o cache legado se ainda existir
    _pokemonListService?.clearAllCaches();

    debugPrint('Cache Hive completamente limpo');
  }

  // Forçar salvamento no disco (Hive faz isso auto, mas mantemos interface)
  static Future<void> forceSave() async {
    await _pokemonBox.flush();
    await _statsBox.flush();
    await _metadataBox.flush();
  }

  // Pré-aquecer cache com Pokémon populares
  static Future<void> preWarmCache(List<Pokemon> pokemons) async {
    for (final pokemon in pokemons) {
      await setPokemon(pokemon);
    }
    debugPrint('Cache pré-aquecido com ${pokemons.length} Pokémon');
  }
}
