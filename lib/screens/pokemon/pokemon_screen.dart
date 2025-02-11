import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../models/pokemon.dart';
import '../../widgets/banner_pattern_painter.dart';
import '../../services/image_preload_service.dart';
import '../../services/pokemon_list_service.dart';
import '../../widgets/subtle_no_results.dart';
import '../pokemon_comparison_screen.dart' as comparison;
import '../pokemon_detail_screen.dart' as detail;
import 'pokemon_grid.dart';
import 'pokemon_search.dart';
import 'pokemon_filters.dart';
import '../../services/pokemon_filter_service.dart';

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
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<Pokemon> searchResults = [];
  List<Pokemon> allSearchResults = []; // Lista completa de resultados
  int totalPages = 1;
  String currentSearchQuery = '';
  bool isSearchMode = false;
  bool isComparisonMode = false;
  Pokemon? pokemonToCompare;
  Map<String, int>? statsToCompare;
  bool _isLoadingStats = false;
  final Map<int, Map<String, int>> _statsCache = {};
  
  // Serviços
  final ImagePreloadService _imagePreloadService = ImagePreloadService();
  final PokemonListService _pokemonListService = PokemonListService();
  
  // Controladores de animação
  late AnimationController _animationController;
  late AnimationController _bannerAnimationController;
  late AnimationController _loadingAnimationController;
  late AnimationController _shakeController;
  late AnimationController _cardAnimationController;
  
  // Notificadores
  final ValueNotifier<Pokemon?> _selectedPokemonNotifier = ValueNotifier<Pokemon?>(null);
  final ValueNotifier<bool> _comparisonModeNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingStatsNotifier = ValueNotifier<bool>(false);
  
  // Filtros
  Map<String, bool> selectedTypes = {};
  RangeValues powerRange = RangeValues(0, 1000);
  int selectedGeneration = 0;
  bool showAdvancedSearch = false;
  bool isFiltering = false;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
    _loadInitialPokemonList();
  }

  void _setupAnimationControllers() {
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    
    _bannerAnimationController = AnimationController(
      duration: Duration(milliseconds: 4000),
      vsync: this,
    )..addStatusListener((status) {
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
    );

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
    super.dispose();
  }

  Future<void> _loadInitialPokemonList() async {
    setState(() => isSearching = true);
    try {
      final result = await _pokemonListService.fetchPokemonList(
        page: currentPage,
        selectedTypes: selectedTypes,
        selectedGeneration: selectedGeneration,
        powerRange: powerRange,
      );
      if (mounted) {
        setState(() {
          searchResults = result['pokemons'];
          totalPages = (result['total'] / pageSize).ceil();
          isSearching = false;
        });
      }
    } catch (e) {
      print('Erro ao carregar lista inicial: $e');
      if (mounted) {
        setState(() => isSearching = false);
      }
    }
  }

  List<Pokemon> _getPageItems(int page) {
    final startIndex = (page - 1) * pageSize;
    final endIndex = math.min(startIndex + pageSize, allSearchResults.length);
    if (startIndex >= allSearchResults.length) return [];
    return allSearchResults.sublist(startIndex, endIndex);
  }

  void _handleSearchResults(List<Pokemon> results) {
    if (!mounted) return;
    
    setState(() {
      currentSearchQuery = _searchController.text;
      isSearchMode = currentSearchQuery.isNotEmpty;

      if (isSearchMode) {
        // Atualiza os resultados da busca
        allSearchResults = results;
        currentPage = 1;
        // Aplica os filtros aos resultados da busca
        if (selectedTypes.isNotEmpty || selectedGeneration > 0 || powerRange != RangeValues(0, 1000)) {
          _applyFilters();
        } else {
          searchResults = _getPageItems(currentPage);
          totalPages = results.isEmpty ? 0 : (results.length / pageSize).ceil();
        }
      } else {
        // Se não estiver em modo de busca, mantém a lista inicial
        if (selectedTypes.isNotEmpty || selectedGeneration > 0 || powerRange != RangeValues(0, 1000)) {
          _applyFilters();
        } else {
          _loadInitialPokemonList();
        }
      }

      isSearching = false;
    });
  }

  void _handleSearchError(String error) {
    setState(() {
      searchError = error;
      isSearching = false;
      searchResults = [];
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleTypesChanged(Map<String, bool> newTypes) {
    setState(() {
      selectedTypes = newTypes;
      currentPage = 1;
      _applyFilters();
    });
  }

  void _handleGenerationChanged(int generation) {
    setState(() {
      selectedGeneration = generation;
      currentPage = 1;
      _applyFilters();
    });
  }

  void _handlePowerRangeChanged(RangeValues range) {
    setState(() {
      powerRange = range;
      currentPage = 1;
      _applyFilters();
    });
  }

  void _applyFilters() async {
    setState(() => isSearching = true);

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    try {
      if (isSearchMode) {
        final filteredResults = allSearchResults.where(_shouldIncludePokemon).toList();
        setState(() {
          allSearchResults = filteredResults;
          searchResults = _getPageItems(currentPage);
          totalPages = filteredResults.isEmpty ? 0 : (filteredResults.length / pageSize).ceil();
          isSearching = false;
        });
      } else {
        final result = await _pokemonListService.fetchPokemonList(
          page: currentPage,
          selectedTypes: selectedTypes,
          selectedGeneration: selectedGeneration,
          powerRange: powerRange,
        );

        if (mounted) {
          setState(() {
            searchResults = result['pokemons'];
            totalPages = (result['total'] / pageSize).ceil();
            isSearching = false;
          });
        }
      }
    } catch (e) {
      print('Erro ao aplicar filtros: $e');
      if (mounted) {
        setState(() => isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aplicar filtros. Tente novamente.'),
            backgroundColor: Colors.red[700],
          ),
        );
      }
    }
  }

  bool _shouldIncludePokemon(Pokemon pokemon) {
    return PokemonFilterService.shouldIncludePokemon(
      pokemon: pokemon,
      selectedTypes: selectedTypes,
      selectedGeneration: selectedGeneration,
      powerRange: powerRange,
      statsCache: _statsCache,
    );
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

  void _handlePokemonTap(Pokemon pokemon) {
    if (isComparisonMode) {
      _handleComparisonTap(pokemon);
    } else {
      _handleDetailTap(pokemon);
    }
  }

  void _handleComparisonTap(Pokemon pokemon) {
    if (_isLoadingStats) return;

    if (pokemonToCompare == null) {
      setState(() => _isLoadingStats = true);
      _selectedPokemonNotifier.value = pokemon;
      
      _imagePreloadService.preloadPokemonImage(pokemon);

      _pokemonListService.fetchPokemonStats(pokemon.id).then((stats) {
        if (stats != null) {
          setState(() {
            pokemonToCompare = pokemon;
            statsToCompare = stats;
          });
        }
        setState(() => _isLoadingStats = false);
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
      setState(() => _isLoadingStats = true);
      _selectedPokemonNotifier.value = pokemon;

      _imagePreloadService.preloadBattle(pokemonToCompare!, pokemon).then((_) {
        _pokemonListService.fetchPokemonStats(pokemon.id).then((stats) {
          if (stats != null) {
            _navigateToComparison(pokemon, stats);
          }
          setState(() => _isLoadingStats = false);
        });
      });
    }
  }

  void _handleDetailTap(Pokemon pokemon) {
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

  void _navigateToComparison(Pokemon pokemon2, Map<String, int> stats2) {
    _cardAnimationController.stop();
    _selectedPokemonNotifier.value = null;
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
      setState(() {
        pokemonToCompare = null;
        statsToCompare = null;
        isComparisonMode = false;
        _isLoadingStats = false;
      });
    });
  }

  void _cancelComparison() {
    _cardAnimationController.stop();
    setState(() {
      pokemonToCompare = null;
      statsToCompare = null;
      isComparisonMode = false;
    });
    _selectedPokemonNotifier.value = null;
  }

  void _handleComparisonMode() {
    setState(() {
      isComparisonMode = true;
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
    });
  }

  void _changePage(int newPage) async {
    if (newPage < 1 || newPage > totalPages) return;
    
    setState(() {
      currentPage = newPage;
      isSearching = true;
    });

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    
    if (isSearchMode) {
      setState(() {
        searchResults = _getPageItems(newPage);
        isSearching = false;
      });
    } else {
      try {
        final result = await _pokemonListService.fetchPokemonList(
          page: newPage,
          selectedTypes: selectedTypes,
          selectedGeneration: selectedGeneration,
          powerRange: powerRange,
        );
        if (mounted) {
          setState(() {
            searchResults = result['pokemons'];
            totalPages = (result['total'] / pageSize).ceil();
            isSearching = false;
          });
        }
      } catch (e) {
        print('Erro ao carregar página $newPage: $e');
        if (mounted) {
          setState(() {
            isSearching = false;
            currentPage = currentPage > 1 ? currentPage - 1 : 1;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao carregar página $newPage. Tente novamente.'),
              backgroundColor: Colors.red[700],
            ),
          );
        }
      }
    }
  }

  Widget _buildPageButton(int pageNumber) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => _changePage(pageNumber),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          backgroundColor: Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Text(
          pageNumber.toString(),
          style: TextStyle(
            color: Colors.red[700],
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget buildPokemonCard(Pokemon pokemon) {
    bool isSelected = (_selectedPokemonNotifier.value?.id == pokemon.id) || (pokemonToCompare?.id == pokemon.id);
    Color typeColor = getTypeColor(pokemon.types.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        double imageHeight = constraints.maxHeight * 0.65;

        return AnimatedBuilder(
          animation: _cardAnimationController,
          builder: (context, child) {
            double scaleAnim = isSelected
                ? 1.0 + 0.03 * math.sin(_cardAnimationController.value * 2 * math.pi)
                : 1.0;
            
            double rotateAnim = isSelected
                ? 0.02 * math.sin(_cardAnimationController.value * 2 * math.pi)
                : 0.0;

            if (isSelected && !_cardAnimationController.isAnimating) {
              _cardAnimationController.repeat();
            }

            return Transform(
              transform: Matrix4.identity()
                ..scale(scaleAnim)
                ..rotateZ(rotateAnim),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _handlePokemonTap(pokemon),
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: typeColor.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
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
                  if (isSelected)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _cardAnimationController.value * 2, 0),
                            end: Alignment(-1.0 + _cardAnimationController.value * 2 + 0.5, 0),
                            colors: [
                              Colors.white.withOpacity(0.0),
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.0),
                            ],
                            stops: [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
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
                            placeholder: (context, url) => CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
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
                ],
              ),
            ),
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
      body: Stack(
        children: [
          Column(
            children: [
              PokemonSearch(
                onSearchResults: _handleSearchResults,
                onError: _handleSearchError,
                shouldIncludePokemon: _shouldIncludePokemon,
                isSearching: isSearching,
                showAdvancedSearch: showAdvancedSearch,
                onAdvancedSearchToggle: (value) {
                  setState(() => showAdvancedSearch = value);
                },
                searchController: _searchController,
              ),
              if (showAdvancedSearch) PokemonFilters(
                selectedTypes: selectedTypes,
                selectedGeneration: selectedGeneration,
                powerRange: powerRange,
                onTypesChanged: _handleTypesChanged,
                onGenerationChanged: _handleGenerationChanged,
                onPowerRangeChanged: _handlePowerRangeChanged,
                getTypeColor: getTypeColor,
                showAdvancedSearch: showAdvancedSearch,
                onAdvancedSearchToggle: (value) {
                  setState(() => showAdvancedSearch = value);
                },
              ),
              Expanded(
                child: searchError.isNotEmpty
                  ? Center(
                      child: Text(
                        searchError,
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : Stack(
                      children: [
                        SingleChildScrollView(
                          controller: _scrollController,
                          child: Column(
                            children: [
                              if (searchResults.isEmpty && !isSearching && isSearchMode)
                                SubtleNoResults(searchQuery: currentSearchQuery)
                              else
                                AnimationLimiter(
                                  child: GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: MediaQuery.of(context).size.width < 360 ? 2 : 3,
                                      childAspectRatio: 0.65,
                                      crossAxisSpacing: 6,
                                      mainAxisSpacing: 6,
                                    ),
                                    itemCount: searchResults.length,
                                    itemBuilder: (context, index) {
                                      return buildPokemonCard(searchResults[index]);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: Offset(0, -4),
                                ),
                              ],
                            ),
                            child: SafeArea(
                              child: totalPages > 1 ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.arrow_back_ios),
                                    onPressed: currentPage > 1
                                      ? () => _changePage(currentPage - 1)
                                      : null,
                                    color: currentPage > 1 ? Colors.red[700] : Colors.grey,
                                  ),
                                  if (currentPage > 2)
                                    _buildPageButton(1),
                                  if (currentPage > 3)
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('...', style: TextStyle(color: Colors.grey[600])),
                                    ),
                                  if (currentPage > 1)
                                    _buildPageButton(currentPage - 1),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red[700],
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      currentPage.toString(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  if (currentPage < totalPages)
                                    _buildPageButton(currentPage + 1),
                                  if (currentPage < totalPages - 1)
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('...', style: TextStyle(color: Colors.grey[600])),
                                    ),
                                  if (currentPage < totalPages - 2)
                                    _buildPageButton(totalPages),
                                  IconButton(
                                    icon: Icon(Icons.arrow_forward_ios),
                                    onPressed: currentPage < totalPages
                                      ? () => _changePage(currentPage + 1)
                                      : null,
                                    color: currentPage < totalPages ? Colors.red[700] : Colors.grey,
                                  ),
                                ],
                              ) : SizedBox.shrink(),
                            ),
                          ),
                        ),
                      ],
                    ),
              ),
            ],
          ),
          if (isSearching)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Column(
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
      ),
      bottomSheet: isComparisonMode ? Container(
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
      ) : null,
    );
  }
} 