import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pokemon.dart';
import '../widgets/banner_pattern_painter.dart';
import 'package:pokefront/screens/pokemon_comparison_screen.dart' as comparison;
import 'package:pokefront/screens/pokemon_detail_screen.dart' as detail;
import '../services/image_preload_service.dart';

class PokemonScreen extends StatefulWidget {
  @override
  _PokemonScreenState createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen> with TickerProviderStateMixin {
  int currentPage = 1;
  final int pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;
  String searchError = '';
  late AnimationController _animationController;
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<Pokemon> searchResults = [];
  List<String> suggestions = [];
  static Pokemon? pokemonToCompare;
  static Map<String, int>? statsToCompare;
  late AnimationController _shakeController;
  bool isComparisonMode = false;
  final Map<int, Map<String, int>> _statsCache = {};
  bool _isLoadingStats = false;
  final ImagePreloadService _imagePreloadService = ImagePreloadService();
  late AnimationController _bannerAnimationController;
  final ValueNotifier<Pokemon?> _selectedPokemonNotifier = ValueNotifier<Pokemon?>(null);
  final ValueNotifier<bool> _comparisonModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingStatsNotifier = ValueNotifier<bool>(false);
  late AnimationController _cardAnimationController;
  late AnimationController _loadingAnimationController;
  Map<String, bool> selectedTypes = {};
  RangeValues powerRange = RangeValues(0, 1000);
  int selectedGeneration = 0;
  bool showAdvancedSearch = false;
  List<Pokemon> filteredPokemon = [];
  bool isFiltering = false;

  // Sistema de Cache
  final Map<int, List<Pokemon>> _pokemonPageCache = {};
  final Map<String, List<Pokemon>> _filteredPokemonCache = {};
  int _lastCacheUpdate = 0;
  static const int _cacheDuration = 300000; // 5 minutos

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _bannerAnimationController = AnimationController(
      duration: Duration(milliseconds: 4000),
      vsync: this,
    );

    _bannerAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bannerAnimationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _bannerAnimationController.forward();
      }
    });

    _bannerAnimationController.forward();

    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      } else if (status == AnimationStatus.dismissed && pokemonToCompare != null) {
        _shakeController.forward();
      }
    });

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _shakeController.dispose();
    _debounce?.cancel();
    _imagePreloadService.clearCache();
    _bannerAnimationController.dispose();
    _selectedPokemonNotifier.dispose();
    _comparisonModeNotifier.dispose();
    _isLoadingStatsNotifier.dispose();
    _cardAnimationController.dispose();
    _loadingAnimationController.dispose();
    _clearCache();
    super.dispose();
  }

  Future<List<Pokemon>> _fetchPokemonList({int page = 1}) async {
    bool hasActiveFilters = selectedTypes.isNotEmpty || 
                          selectedGeneration > 0 || 
                          powerRange != RangeValues(0, 1000);

    // Gerar chave única para o cache baseada nos filtros ativos
    String cacheKey = hasActiveFilters 
        ? '${selectedTypes.toString()}_${selectedGeneration}_${powerRange.toString()}'
        : 'page_$page';

    // Verificar cache
    if (_shouldUseCache()) {
      if (hasActiveFilters && _filteredPokemonCache.containsKey(cacheKey)) {
        final cachedPokemons = _filteredPokemonCache[cacheKey]!;
        int startIndex = (page - 1) * 20;
        if (startIndex < cachedPokemons.length) {
          return cachedPokemons.skip(startIndex).take(20).toList();
        }
      } else if (!hasActiveFilters && _pokemonPageCache.containsKey(page)) {
        return _pokemonPageCache[page]!;
      }
    }

    List<Pokemon> pokemons = [];
    int limit = hasActiveFilters ? 100 : 40;
    int offset = hasActiveFilters ? 0 : (page - 1) * 20;
    int maxAttempts = hasActiveFilters ? 5 : 2;
    int attempts = 0;

    try {
      while (pokemons.length < 20 && attempts < maxAttempts) {
        final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?offset=$offset&limit=$limit'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'];
          
          await Future.wait(
            results.map((pokemon) async {
              try {
                final detailResponse = await http.get(Uri.parse(pokemon['url']));
                if (detailResponse.statusCode == 200) {
                  final detailData = json.decode(detailResponse.body);
                  final Pokemon newPokemon = Pokemon.fromDetailJson(detailData);
                  
                  if (_shouldIncludePokemon(newPokemon)) {
                    pokemons.add(newPokemon);
                  }
                }
              } catch (e) {
                print('Erro ao buscar detalhes do pokemon: $e');
              }
            })
          );

          if (results.isEmpty || (!hasActiveFilters && pokemons.length >= 20)) break;
          
          offset += limit;
          attempts++;
        } else {
          break;
        }
      }

      // Atualizar cache
      if (hasActiveFilters) {
        _filteredPokemonCache[cacheKey] = pokemons;
      } else {
        _pokemonPageCache[page] = pokemons.take(20).toList();
      }
      _lastCacheUpdate = DateTime.now().millisecondsSinceEpoch;

      if (hasActiveFilters) {
        int startIndex = (page - 1) * 20;
        if (startIndex >= pokemons.length) return [];
        return pokemons.skip(startIndex).take(20).toList();
      }

      return pokemons.take(20).toList();
    } catch (e) {
      print('Erro ao buscar lista de Pokémon: $e');
      return [];
    }
  }

  bool _shouldUseCache() {
    return DateTime.now().millisecondsSinceEpoch - _lastCacheUpdate < _cacheDuration;
  }

  void _clearCache() {
    _pokemonPageCache.clear();
    _filteredPokemonCache.clear();
    _lastCacheUpdate = 0;
  }

  bool _shouldIncludePokemon(Pokemon pokemon) {
    // Se não há filtros ativos, incluir todos os Pokémon
    if (selectedTypes.isEmpty && selectedGeneration == 0 && powerRange == RangeValues(0, 1000)) {
      return true;
    }

    // Verificar tipos selecionados
    if (selectedTypes.isNotEmpty) {
      final selectedTypesList = selectedTypes.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      bool hasAllSelectedTypes = selectedTypesList.every((selectedType) =>
        pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
      );
      
      if (!hasAllSelectedTypes) return false;
    }

    // Verificar geração
    if (selectedGeneration > 0) {
      int pokemonGen = _getPokemonGeneration(pokemon.id);
      if (pokemonGen != selectedGeneration) return false;
    }

    // Verificar poder total
    if (_statsCache.containsKey(pokemon.id)) {
      int totalPower = _statsCache[pokemon.id]!.values.reduce((a, b) => a + b);
      if (totalPower < powerRange.start || totalPower > powerRange.end) {
        return false;
      }
    }

    return true;
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

  Future<Pokemon?> searchPokemon(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults.clear();
        searchError = '';
      });
      return null;
    }

    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${query.toLowerCase().trim()}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Garantir que temos todos os dados necessários
        if (data['id'] != null && 
            data['name'] != null && 
            data['sprites'] != null) {
          return Pokemon.fromDetailJson(data);
        } else {
          setState(() {
            searchError = 'Dados do Pokémon incompletos';
          });
          return null;
        }
      } else {
        setState(() {
          searchError = 'Pokémon não encontrado';
        });
        return null;
      }
    } catch (e) {
      setState(() {
        searchError = 'Erro ao buscar Pokémon';
      });
      return null;
    }
  }

  Future<List<Pokemon>> searchPokemonByName(String query) async {
    if (query.isEmpty) {
      setState(() {
        searchResults = [];
        suggestions = [];
        searchError = '';
      });
      return [];
    }

    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        
        // Filtrar pokémons que correspondem à busca
        final filteredResults = results.where((pokemon) => 
          pokemon['name'].toString().toLowerCase().contains(query.toLowerCase())
        ).toList();

        // Atualizar sugestões
        setState(() {
          suggestions = filteredResults
              .take(5)
              .map((pokemon) => pokemon['name'].toString())
              .toList();
        });

        // Buscar detalhes para cada pokémon filtrado
        List<Pokemon> pokemons = [];
        for (var pokemon in filteredResults.take(10)) {
          final detailResponse = await http.get(
            Uri.parse(pokemon['url']),
          );
          if (detailResponse.statusCode == 200) {
            final detailData = json.decode(detailResponse.body);
            pokemons.add(Pokemon.fromDetailJson(detailData));
          }
        }
        return pokemons;
      }
      throw Exception('Falha ao buscar Pokémon');
    } catch (e) {
      setState(() {
        searchError = 'Erro ao buscar Pokémon';
      });
      return [];
    }
  }

  // Otimizando a função de busca para evitar recarregamentos desnecessários
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    setState(() {
      isSearching = true;
      searchError = '';
    });

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    if (isFiltering) return;

    final normalizedQuery = query.toLowerCase().trim();
    
    if (normalizedQuery.isEmpty) {
      setState(() {
        searchResults = [];
        suggestions = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      searchError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        
        final filteredResults = results.where((pokemon) => 
          pokemon['name'].toString().toLowerCase().contains(normalizedQuery)
        ).toList();

        setState(() {
          suggestions = filteredResults
              .take(5)
              .map((pokemon) => pokemon['name'].toString())
              .toList();
        });

        final pokemonFutures = filteredResults.take(20).map((pokemon) async {
          try {
            final detailResponse = await http.get(Uri.parse(pokemon['url']));
            if (detailResponse.statusCode == 200) {
              final detailData = json.decode(detailResponse.body);
              return Pokemon.fromDetailJson(detailData);
            }
          } catch (e) {
            print('Erro ao buscar detalhes do pokemon: ${e.toString()}');
          }
          return null;
        }).toList();

        final pokemons = (await Future.wait(pokemonFutures))
            .where((pokemon) => pokemon != null)
            .cast<Pokemon>()
            .toList();

        if (!mounted) return;

        setState(() {
          searchResults = _applyFilters(pokemons);
          isSearching = false;
          searchError = '';
        });
      } else {
        if (!mounted) return;
        setState(() {
          searchError = 'Falha ao buscar Pokémon';
          isSearching = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        searchError = 'Erro ao buscar Pokémon';
        isSearching = false;
      });
    }
  }

  // Adicionar o método de filtragem
  List<Pokemon> _applyFilters(List<Pokemon> pokemons) {
    if (selectedTypes.isEmpty && selectedGeneration == 0 && powerRange == RangeValues(0, 1000)) {
      return pokemons;
    }

    return pokemons.where((pokemon) {
      // Filtrar por tipos selecionados
      if (selectedTypes.isNotEmpty) {
        // Obter lista de tipos selecionados
        final selectedTypesList = selectedTypes.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
        
        // Verificar se o Pokémon possui TODOS os tipos selecionados
        bool hasAllSelectedTypes = selectedTypesList.every((selectedType) =>
          pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
        );
        
        if (!hasAllSelectedTypes) return false;
      }

      // Filtrar por geração
      if (selectedGeneration > 0) {
        int pokemonGen = _getPokemonGeneration(pokemon.id);
        if (pokemonGen != selectedGeneration) return false;
      }

      // Filtrar por poder total
      int totalPower = _calculateTotalPower(pokemon.id);
      if (totalPower < powerRange.start || totalPower > powerRange.end) {
        return false;
      }

      return true;
    }).toList();
  }

  // Adicionar método auxiliar para calcular o poder total
  int _calculateTotalPower(int pokemonId) {
    if (_statsCache.containsKey(pokemonId)) {
      return _statsCache[pokemonId]!.values.reduce((a, b) => a + b);
    }
    return 500; // Valor padrão caso os stats não estejam em cache
  }

  // Otimizando a mudança de página
  void changePage(int newPage) async {
    if (newPage == currentPage) return;

    setState(() {
      isFiltering = true;
    });

    try {
      // Se estamos indo para uma página além da primeira, verificamos se há Pokémon suficientes
      if (newPage > 1) {
        bool hasNext = await _hasNextPage(newPage - 1);
        if (!hasNext) {
          setState(() {
            currentPage = 1;
            isFiltering = false;
          });
          return;
        }
      }

      setState(() {
        currentPage = newPage;
        searchResults = [];
        suggestions = [];
        isFiltering = false;
      });
    } catch (e) {
      setState(() {
        isFiltering = false;
      });
      print('Erro ao mudar de página: $e');
    }
  }

  void _cancelComparison() {
    pokemonToCompare = null;
    statsToCompare = null;
    _comparisonModeNotifier.value = false;
    _selectedPokemonNotifier.value = null;
  }

  void _handleComparisonMode() {
    _comparisonModeNotifier.value = true;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.sports_kabaddi, color: Colors.white),
            SizedBox(width: 12),
            Text('Selecione o primeiro Pokémon para batalhar!'),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _handlePokemonTap(Pokemon pokemon) {
    if (_comparisonModeNotifier.value) {
      if (_isLoadingStatsNotifier.value) return;

      if (pokemonToCompare == null) {
        if (_statsCache.containsKey(pokemon.id)) {
          pokemonToCompare = pokemon;
          statsToCompare = _statsCache[pokemon.id];
          _selectedPokemonNotifier.value = pokemon;
          _imagePreloadService.preloadPokemonImage(pokemon);
          return;
        }

        _isLoadingStatsNotifier.value = true;
        _imagePreloadService.preloadPokemonImage(pokemon);
        
        fetchPokemonStats(pokemon.id).then((stats) {
          if (stats != null && mounted) {
            pokemonToCompare = pokemon;
            statsToCompare = stats;
            _selectedPokemonNotifier.value = pokemon;
          }
          if (mounted) {
            _isLoadingStatsNotifier.value = false;
          }
        });
      } else if (pokemonToCompare!.id == pokemon.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pokémon já selecionado. Selecione outro para comparar!'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      } else {
        if (_statsCache.containsKey(pokemon.id)) {
          _navigateToComparison(pokemon, _statsCache[pokemon.id]!);
          return;
        }

        _isLoadingStatsNotifier.value = true;
        _imagePreloadService.preloadBattle(pokemonToCompare!, pokemon).then((_) {
          fetchPokemonStats(pokemon.id).then((stats) {
            if (stats != null && mounted) {
              _navigateToComparison(pokemon, stats);
            }
            if (mounted) {
              _isLoadingStatsNotifier.value = false;
            }
          });
        });
      }
    } else {
      _imagePreloadService.preloadPokemonImage(pokemon).then((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => detail.PokemonDetailScreen(
              pokemonId: pokemon.id,
              pokemonName: pokemon.name,
            ),
          ),
        );
      });
    }
  }

  void _navigateToComparison(Pokemon pokemon2, Map<String, int> stats2) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => comparison.PokemonComparisonScreen(
          pokemon1: pokemonToCompare!,
          pokemon2: pokemon2,
          stats1: statsToCompare!,
          stats2: stats2,
        ),
      ),
    ).then((_) {
      pokemonToCompare = null;
      statsToCompare = null;
      _comparisonModeNotifier.value = false;
      _isLoadingStats = false;
      _selectedPokemonNotifier.value = null;
    });
  }

  Widget buildSearchArea() {
    return Container(
      margin: EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Focus(
            onFocusChange: (hasFocus) {
              if (!hasFocus && _searchController.text.isEmpty) {
                setState(() {
                  suggestions = [];
                });
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar Pokémon...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                      prefixIcon: AnimatedRotation(
                        duration: Duration(milliseconds: 300),
                        turns: isSearching ? 1 : 0,
                        child: Icon(
                          Icons.catching_pokemon,
                          color: isSearching ? Colors.red : Colors.grey,
                        ),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _performSearch(value);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    showAdvancedSearch ? Icons.filter_list_off : Icons.filter_list,
                    color: showAdvancedSearch ? Colors.red : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      showAdvancedSearch = !showAdvancedSearch;
                    });
                  },
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        suggestions = [];
                        searchResults = [];
                        isSearching = false;
                        searchError = '';
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildAdvancedSearch() {
    if (!showAdvancedSearch) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tipos
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tipos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    'fire', 'water', 'grass', 'electric', 'psychic',
                    'ice', 'dragon', 'dark', 'fairy', 'fighting',
                    'flying', 'poison', 'ground', 'rock', 'bug',
                    'ghost', 'steel', 'normal'
                  ].map((type) {
                    Color typeColor = getTypeColor(type);
                    bool isSelected = selectedTypes[type] ?? false;
                    
                    return FilterChip(
                      selected: isSelected,
                      selectedColor: typeColor,
                      checkmarkColor: Colors.white,
                      backgroundColor: Colors.grey[200],
                      label: Text(
                        type.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[800],
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onSelected: (bool selected) {
                        setState(() {
                          selectedTypes[type] = selected;
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),

          // Geração
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Geração',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(8, (index) {
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: selectedGeneration == index + 1,
                          label: Text(
                            'Gen ${index + 1}',
                            style: TextStyle(
                              color: selectedGeneration == index + 1 
                                ? Colors.white 
                                : Colors.grey[800],
                            ),
                          ),
                          selectedColor: Colors.red[700],
                          onSelected: (bool selected) {
                            setState(() {
                              selectedGeneration = selected ? index + 1 : 0;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),

          // Poder Total
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Poder Total',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 12),
                RangeSlider(
                  values: powerRange,
                  min: 0,
                  max: 1000,
                  divisions: 20,
                  activeColor: Colors.red[700],
                  inactiveColor: Colors.red[100],
                  labels: RangeLabels(
                    powerRange.start.round().toString(),
                    powerRange.end.round().toString(),
                  ),
                  onChanged: (RangeValues values) {
                    setState(() {
                      powerRange = values;
                    });
                  },
                ),
              ],
            ),
          ),

          // Botões de Ação
          Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedTypes.clear();
                      selectedGeneration = 0;
                      powerRange = RangeValues(0, 1000);
                    });
                  },
                  child: Text(
                    'Limpar Filtros',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      isFiltering = true;
                      if (_searchController.text.isNotEmpty) {
                        _performSearch(_searchController.text);
                      } else {
                        // Aplicar filtros à lista atual
                        searchResults = _applyFilters(searchResults);
                      }
                      showAdvancedSearch = false;
                      isFiltering = false;
                    });
                  },
                  icon: Icon(Icons.search),
                  label: Text('Aplicar Filtros'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPokemonCard(Pokemon pokemon) {
    return ValueListenableBuilder<Pokemon?>(
      valueListenable: _selectedPokemonNotifier,
      builder: (context, selectedPokemon, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: _isLoadingStatsNotifier,
          builder: (context, isLoadingStats, _) {
            bool isSelected = (selectedPokemon?.id == pokemon.id);
            Color typeColor = getTypeColor(pokemon.types.first);

            return LayoutBuilder(
              builder: (context, constraints) {
                double imageHeight = constraints.maxHeight * 0.65;

                return GestureDetector(
                  onTap: isLoadingStats ? null : () => _handlePokemonTap(pokemon),
                  child: AnimatedBuilder(
                    animation: _cardAnimationController,
                    builder: (context, child) {
                      final scale = isSelected 
                          ? 1.0 + (_cardAnimationController.value * 0.05)
                          : 1.0;
                      
                      return Transform.scale(
                        scale: scale,
                        child: child!,
                      );
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.all(isSelected ? 4 : 0),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.95) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: typeColor.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Container(
                                height: imageHeight,
                                alignment: Alignment.center,
                                padding: EdgeInsets.all(8),
                                child: Hero(
                                  tag: 'pokemon-${pokemon.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: pokemon.imageUrl,
                                    height: imageHeight,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => _buildLoadingPokeball(),
                                    errorWidget: (context, url, error) => Icon(Icons.error_outline),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pokemon.name.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: pokemon.types.map((type) {
                                          final color = getTypeColor(type);
                                          return Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              type.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                          if (isLoadingStats)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: _buildLoadingPokeball(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingPokeball() {
    return RotationTransition(
      turns: _loadingAnimationController,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.red.shade700,
            width: 3,
          ),
        ),
        child: CustomPaint(
          painter: PokeballPainter(),
        ),
      ),
    );
  }

  Future<Map<String, int>?> fetchPokemonStats(int pokemonId) async {
    // Verifica se os stats já estão em cache
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
        
        // Armazena os stats em cache
        _statsCache[pokemonId] = stats;
        return stats;
      }
    } catch (e) {
      print('Erro ao buscar stats: $e');
    }
    return null;
  }

  void _prefetchStats(List<Pokemon> pokemons) {
    if (!_comparisonModeNotifier.value) return;
    
    _isLoadingStatsNotifier.value = true;
    Future.wait(
      pokemons.map((pokemon) => fetchPokemonStats(pokemon.id))
    ).then((_) {
      if (mounted) {
        _isLoadingStatsNotifier.value = false;
      }
    });
  }

  Color getTypeColor(String type) {
    final colors = {
      'fire': Color(0xFFEE8130),
      'water': Color(0xFF6390F0),
      'grass': Color(0xFF7AC74C),
      'electric': Color(0xFFF7D02C),
      'psychic': Color(0xFFF95587),
      'ice': Color(0xFF96D9D6),
      'dragon': Color(0xFF6F35FC),
      'dark': Color(0xFF705746),
      'fairy': Color(0xFFD685AD),
      'fighting': Color(0xFFC22E28),
      'flying': Color(0xFFA98FF3),
      'poison': Color(0xFFA33EA1),
      'ground': Color(0xFFE2BF65),
      'rock': Color(0xFFB6A136),
      'bug': Color(0xFFA6B91A),
      'ghost': Color(0xFF735797),
      'steel': Color(0xFFB7B7CE),
      'normal': Color(0xFFA8A77A),
    };
    return colors[type.toLowerCase()] ?? Colors.grey;
  }

  Widget buildSearchResult() {
    if (isSearching) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
          ),
        ),
      );
    }

    if (searchError.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                searchError,
                style: TextStyle(color: Colors.red),
              ),
              SizedBox(height: 24),
              CustomPaint(
                painter: BannerPatternPainter(
                  color: Colors.red.withOpacity(0.1),
                  progress: DateTime.now().millisecondsSinceEpoch / 1000,
                  type: 'default',
                ),
                child: Container(
                  width: double.infinity,
                  height: 150,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget buildSuggestions() {
    if (suggestions.isEmpty || _searchController.text.isEmpty) {
      return SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sugestões:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((suggestion) {
                  return Material(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        _searchController.text = suggestion;
                        _performSearch(suggestion);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          suggestion.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSearchResults() {
    if (_searchController.text.isEmpty) return SizedBox.shrink();

    if (isSearching) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
              SizedBox(height: 16),
              Text(
                'Buscando Pokémon...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (searchError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(
                searchError,
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              CustomPaint(
                painter: BannerPatternPainter(
                  color: Colors.grey.withOpacity(0.2),
                  progress: DateTime.now().millisecondsSinceEpoch / 1000,
                  type: 'default',
                ),
                child: Container(
                  width: double.infinity,
                  height: 200,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AnimationLimiter(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.80,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: searchResults.length,
        itemBuilder: (context, index) {
          return AnimationConfiguration.staggeredGrid(
            position: index,
            duration: const Duration(milliseconds: 375),
            columnCount: 3,
            child: ScaleAnimation(
              child: FadeInAnimation(
                child: buildPokemonCard(searchResults[index]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget buildPaginationButtons() {
    if (_searchController.text.isNotEmpty) return SizedBox.shrink();

    return FutureBuilder<bool>(
      future: _hasNextPage(currentPage),
      builder: (context, snapshot) {
        final hasNext = snapshot.data ?? false;
        
        return Container(
          height: 80,
          margin: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (currentPage > 1)
                AnimatedScale(
                  scale: 1.0,
                  duration: Duration(milliseconds: 200),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_rounded),
                    color: Colors.red.withOpacity(0.6),
                    onPressed: () => changePage(currentPage - 1),
                    hoverColor: Colors.red.withOpacity(0.1),
                    splashRadius: 24,
                  ),
                ),
              SizedBox(width: 8),
              if (currentPage > 1)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => changePage(currentPage - 1),
                    child: Text((currentPage - 1).toString()),
                  ),
                ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: null,
                  child: Text(
                    currentPage.toString(),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (hasNext)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 2,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => changePage(currentPage + 1),
                    child: Text((currentPage + 1).toString()),
                  ),
                ),
              SizedBox(width: 8),
              if (hasNext)
                AnimatedScale(
                  scale: 1.0,
                  duration: Duration(milliseconds: 200),
                  child: IconButton(
                    icon: Icon(Icons.arrow_forward_ios_rounded),
                    color: Colors.red.withOpacity(0.6),
                    onPressed: () => changePage(currentPage + 1),
                    hoverColor: Colors.red.withOpacity(0.1),
                    splashRadius: 24,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade900.withOpacity(0.2),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Image.network(
                'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/poke-ball.png',
                height: 24,
                width: 24,
              ),
            ),
            SizedBox(width: 12),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Colors.white,
                  Colors.white.withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Text(
                'PokéDex',
                style: GoogleFonts.rubikMonoOne(
                  fontSize: 32,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1,
                  shadows: [
                    Shadow(
                      color: Colors.red.shade900.withOpacity(0.3),
                      offset: Offset(1, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFFE53935),
                Color(0xFFD32F2F),
                Color(0xFFC62828),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _comparisonModeNotifier,
        builder: (context, isComparisonMode, child) {
          return SingleChildScrollView(
            child: Column(
              children: [
                buildSearchArea(),
                buildAdvancedSearch(),
                if (_searchController.text.isNotEmpty) buildSuggestions(),
                if (searchResults.isNotEmpty) buildSearchResults(),
                if (_searchController.text.isEmpty)
                  _PokemonGrid(
                    key: ValueKey(currentPage),
                    currentPage: currentPage,
                    onPokemonsLoaded: (pokemons) {
                      if (isComparisonMode) {
                        _prefetchStats(pokemons);
                      }
                    },
                    selectedPokemonNotifier: _selectedPokemonNotifier,
                    isLoadingStatsNotifier: _isLoadingStatsNotifier,
                    onPokemonTap: _handlePokemonTap,
                    getTypeColor: getTypeColor,
                    cardAnimationController: _cardAnimationController,
                    loadingAnimationController: _loadingAnimationController,
                    selectedTypes: selectedTypes,
                    selectedGeneration: selectedGeneration,
                    powerRange: powerRange,
                    statsCache: _statsCache,
                    onChangePage: changePage,
                    shouldIncludePokemon: _shouldIncludePokemon,
                  ),
                buildPaginationButtons(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: ValueListenableBuilder<bool>(
        valueListenable: _comparisonModeNotifier,
        builder: (context, isComparisonMode, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isComparisonMode) 
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton(
                    heroTag: 'cancel_comparison',
                    mini: true,
                    backgroundColor: Colors.red[700],
                    elevation: 4,
                    child: Icon(Icons.close, color: Colors.white),
                    onPressed: _cancelComparison,
                  ),
                ),
              FloatingActionButton(
                heroTag: 'start_comparison',
                backgroundColor: isComparisonMode ? Colors.amber[700] : Colors.red[700],
                elevation: 6,
                child: Icon(
                  isComparisonMode ? Icons.sports_kabaddi : Icons.compare,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: isComparisonMode ? null : _handleComparisonMode,
              ),
            ],
          );
        },
      ),
      bottomSheet: ValueListenableBuilder<bool>(
        valueListenable: _comparisonModeNotifier,
        builder: (context, isComparisonMode, child) {
          if (!isComparisonMode) return SizedBox.shrink();
          return Container(
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.red[700]?.withOpacity(0.9),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (pokemonToCompare != null) Row(
                    children: [
                      Hero(
                        tag: 'compare-${pokemonToCompare!.id}',
                        child: CachedNetworkImage(
                          imageUrl: pokemonToCompare!.imageUrl,
                          height: 40,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        pokemonToCompare!.name.toUpperCase(),
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ) else SizedBox.shrink(),
                  Text(
                    pokemonToCompare == null 
                      ? 'Selecione o primeiro Pokémon'
                      : 'Selecione o oponente',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _hasNextPage(int page) async {
    try {
      bool hasActiveFilters = selectedTypes.isNotEmpty || 
                          selectedGeneration > 0 || 
                          powerRange != RangeValues(0, 1000);

      String cacheKey = hasActiveFilters 
          ? '${selectedTypes.toString()}_${selectedGeneration}_${powerRange.toString()}'
          : 'page_${page + 1}';

      // Verificar cache primeiro
      if (_shouldUseCache()) {
        if (hasActiveFilters && _filteredPokemonCache.containsKey(cacheKey)) {
          final cachedPokemons = _filteredPokemonCache[cacheKey]!;
          return (page * 20) < cachedPokemons.length;
        } else if (!hasActiveFilters && _pokemonPageCache.containsKey(page + 1)) {
          return _pokemonPageCache[page + 1]!.isNotEmpty;
        }
      }

      if (hasActiveFilters) {
        // Usar cache de pokémon filtrados se disponível
        if (_filteredPokemonCache.containsKey(cacheKey)) {
          final totalFilteredPokemon = _filteredPokemonCache[cacheKey]!.length;
          return totalFilteredPokemon > page * 20;
        }

        // Se não há cache, faz uma verificação rápida
        final pokemons = await _fetchPokemonList(page: page + 1);
        return pokemons.isNotEmpty;
      } else {
        // Verificação rápida para páginas sem filtro
        final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?offset=${page * 20}&limit=1'),
        );
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return (data['results'] as List).isNotEmpty;
        }
      }
      return false;
    } catch (e) {
      print('Erro ao verificar próxima página: $e');
      return false;
    }
  }
}

class _PokemonGrid extends StatelessWidget {
  final int currentPage;
  final Function(List<Pokemon>) onPokemonsLoaded;
  final ValueNotifier<Pokemon?> selectedPokemonNotifier;
  final ValueNotifier<bool> isLoadingStatsNotifier;
  final Function(Pokemon) onPokemonTap;
  final Color Function(String) getTypeColor;
  final AnimationController cardAnimationController;
  final AnimationController loadingAnimationController;
  final Map<String, bool> selectedTypes;
  final int selectedGeneration;
  final RangeValues powerRange;
  final Map<int, Map<String, int>> statsCache;
  final Function(int) onChangePage;
  final bool Function(Pokemon) shouldIncludePokemon;
  
  // Cache fields
  final Map<int, List<Pokemon>> _pokemonPageCache = {};
  final Map<String, List<Pokemon>> _filteredPokemonCache = {};
  int _lastCacheUpdate = 0;
  static const int _cacheDuration = 300000; // 5 minutos

  bool _shouldUseCache() {
    return DateTime.now().millisecondsSinceEpoch - _lastCacheUpdate < _cacheDuration;
  }

  _PokemonGrid({
    Key? key,
    required this.currentPage,
    required this.onPokemonsLoaded,
    required this.selectedPokemonNotifier,
    required this.isLoadingStatsNotifier,
    required this.onPokemonTap,
    required this.getTypeColor,
    required this.cardAnimationController,
    required this.loadingAnimationController,
    required this.selectedTypes,
    required this.selectedGeneration,
    required this.powerRange,
    required this.statsCache,
    required this.onChangePage,
    required this.shouldIncludePokemon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Pokemon>>(
      future: _fetchPokemonList(page: currentPage),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
            ),
          );
        } else if (snapshot.hasError) {
          return Center(
            child: Text('Erro: ${snapshot.error}'),
          );
        }

        final pokemonList = snapshot.data ?? [];
        onPokemonsLoaded(pokemonList);
        
        if (pokemonList.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Nenhum Pokémon encontrado\ncom os filtros selecionados',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }
        
        return AnimationLimiter(
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.80,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: pokemonList.length,
            itemBuilder: (context, index) {
              return AnimationConfiguration.staggeredGrid(
                position: index,
                duration: const Duration(milliseconds: 375),
                columnCount: 3,
                child: ScaleAnimation(
                  child: FadeInAnimation(
                    child: buildPokemonCard(pokemonList[index]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<List<Pokemon>> _fetchPokemonList({int page = 1}) async {
    bool hasActiveFilters = selectedTypes.isNotEmpty || 
                          selectedGeneration > 0 || 
                          powerRange != RangeValues(0, 1000);

    // Gerar chave única para o cache baseada nos filtros ativos
    String cacheKey = hasActiveFilters 
        ? '${selectedTypes.toString()}_${selectedGeneration}_${powerRange.toString()}'
        : 'page_$page';

    // Verificar cache
    if (_shouldUseCache()) {
      if (hasActiveFilters && _filteredPokemonCache.containsKey(cacheKey)) {
        final cachedPokemons = _filteredPokemonCache[cacheKey]!;
        int startIndex = (page - 1) * 20;
        if (startIndex < cachedPokemons.length) {
          return cachedPokemons.skip(startIndex).take(20).toList();
        }
      } else if (!hasActiveFilters && _pokemonPageCache.containsKey(page)) {
        return _pokemonPageCache[page]!;
      }
    }

    List<Pokemon> pokemons = [];
    int limit = hasActiveFilters ? 100 : 40;
    int offset = hasActiveFilters ? 0 : (page - 1) * 20;
    int maxAttempts = hasActiveFilters ? 5 : 2;
    int attempts = 0;

    try {
      while (pokemons.length < 20 && attempts < maxAttempts) {
        final response = await http.get(
          Uri.parse('https://pokeapi.co/api/v2/pokemon?offset=$offset&limit=$limit'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final List results = data['results'];
          
          await Future.wait(
            results.map((pokemon) async {
              try {
                final detailResponse = await http.get(Uri.parse(pokemon['url']));
                if (detailResponse.statusCode == 200) {
                  final detailData = json.decode(detailResponse.body);
                  final Pokemon newPokemon = Pokemon.fromDetailJson(detailData);
                  
                  if (shouldIncludePokemon(newPokemon)) {
                    pokemons.add(newPokemon);
                  }
                }
              } catch (e) {
                print('Erro ao buscar detalhes do pokemon: $e');
              }
            })
          );

          if (results.isEmpty || (!hasActiveFilters && pokemons.length >= 20)) break;
          
          offset += limit;
          attempts++;
        } else {
          break;
        }
      }

      // Atualizar cache
      if (hasActiveFilters) {
        _filteredPokemonCache[cacheKey] = pokemons;
      } else {
        _pokemonPageCache[page] = pokemons.take(20).toList();
      }
      _lastCacheUpdate = DateTime.now().millisecondsSinceEpoch;

      if (hasActiveFilters) {
        int startIndex = (page - 1) * 20;
        if (startIndex >= pokemons.length) return [];
        return pokemons.skip(startIndex).take(20).toList();
      }

      return pokemons.take(20).toList();
    } catch (e) {
      print('Erro ao buscar lista de Pokémon: $e');
      return [];
    }
  }

  Widget buildPokemonCard(Pokemon pokemon) {
    return ValueListenableBuilder<Pokemon?>(
      valueListenable: selectedPokemonNotifier,
      builder: (context, selectedPokemon, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: isLoadingStatsNotifier,
          builder: (context, isLoadingStats, _) {
            bool isSelected = (selectedPokemon?.id == pokemon.id);
            Color typeColor = getTypeColor(pokemon.types.first);

            return LayoutBuilder(
              builder: (context, constraints) {
                double imageHeight = constraints.maxHeight * 0.65;

                return GestureDetector(
                  onTap: isLoadingStats ? null : () => onPokemonTap(pokemon),
                  child: AnimatedBuilder(
                    animation: cardAnimationController,
                    builder: (context, child) {
                      final scale = isSelected 
                          ? 1.0 + (cardAnimationController.value * 0.05)
                          : 1.0;
                      
                      return Transform.scale(
                        scale: scale,
                        child: child!,
                      );
                    },
                    child: AnimatedContainer(
                      duration: Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.all(isSelected ? 4 : 0),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withOpacity(0.95) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: typeColor.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 3,
                            ),
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Container(
                                height: imageHeight,
                                alignment: Alignment.center,
                                padding: EdgeInsets.all(8),
                                child: Hero(
                                  tag: 'pokemon-${pokemon.id}',
                                  child: CachedNetworkImage(
                                    imageUrl: pokemon.imageUrl,
                                    height: imageHeight,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => _buildLoadingPokeball(),
                                    errorWidget: (context, url, error) => Icon(Icons.error_outline),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        pokemon.name.toUpperCase(),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 8),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: pokemon.types.map((type) {
                                          final color = getTypeColor(type);
                                          return Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: color,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              type.toUpperCase(),
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                          if (isLoadingStats)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: _buildLoadingPokeball(),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingPokeball() {
    return RotationTransition(
      turns: loadingAnimationController,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.red.shade700,
            width: 3,
          ),
        ),
        child: CustomPaint(
          painter: PokeballPainter(),
        ),
      ),
    );
  }
}

class PokeballPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red.shade700
      ..style = PaintingStyle.fill;

    // Desenha a linha horizontal
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.45, size.width, size.height * 0.1),
      paint,
    );

    // Desenha o círculo central
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.15,
      paint,
    );

    // Desenha o círculo central branco
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.5),
      size.width * 0.1,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
