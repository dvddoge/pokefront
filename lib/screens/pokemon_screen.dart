import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

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
  late AnimationController _cardAnimationController;
  late AnimationController _bannerAnimationController;

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
      duration: Duration(milliseconds: 4000),
      vsync: this,
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
    _cardAnimationController.dispose();
    _bannerAnimationController.dispose();
    super.dispose();
  }

  Future<List<Pokemon>> fetchPokemonList({int page = 1}) async {
    int offset = (page - 1) * pageSize;
    final response = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon?offset=$offset&limit=$pageSize'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List results = data['results'];
      
      // Buscar detalhes para cada pokémon
      List<Pokemon> pokemons = [];
      for (var pokemon in results) {
        final detailResponse = await http.get(Uri.parse(pokemon['url']));
        if (detailResponse.statusCode == 200) {
          final detailData = json.decode(detailResponse.body);
          pokemons.add(Pokemon.fromDetailJson(detailData));
        }
      }
      return pokemons;
    } else {
      throw Exception('Falha ao carregar os Pokémon');
    }
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
    final normalizedQuery = query.toLowerCase().trim();
    
    if (normalizedQuery.isEmpty) {
      setState(() {
        searchResults = [];
        suggestions = [];
        isSearching = false;
      });
      return;
    }

    try {
      // Primeiro, buscar as sugestões
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );
      
      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'];
        
        // Filtrar pokémons que correspondem à busca
        final filteredResults = results.where((pokemon) => 
          pokemon['name'].toString().toLowerCase().contains(normalizedQuery)
        ).toList();

        // Atualizar sugestões imediatamente
        setState(() {
          suggestions = filteredResults
              .take(5)
              .map((pokemon) => pokemon['name'].toString())
              .toList();
        });

        // Buscar detalhes dos Pokémon filtrados em paralelo
        final pokemonFutures = filteredResults.take(10).map((pokemon) async {
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

        // Aguardar todos os detalhes serem carregados
        final pokemons = (await Future.wait(pokemonFutures))
            .where((pokemon) => pokemon != null)
            .cast<Pokemon>()
            .toList();

        if (!mounted) return;

        setState(() {
          searchResults = pokemons;
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

  // Otimizando a mudança de página
  void changePage(int page) {
    if (page != currentPage) {
      setState(() {
        currentPage = page;
        searchResults = [];
        suggestions = [];
      });
    }
  }

  List<int> getPageRange() {
    List<int> pages = [];
    if (currentPage > 1) pages.add(currentPage - 1);
    pages.add(currentPage);
    if (currentPage < 50) pages.add(currentPage + 1);
    return pages;
  }

  void _cancelComparison() {
    setState(() {
      pokemonToCompare = null;
      statsToCompare = null;
      isComparisonMode = false;
    });
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

  void _handlePokemonTap(Pokemon pokemon) {
    if (isComparisonMode) {
      if (_isLoadingStats) return;

      if (pokemonToCompare == null) {
        setState(() => _isLoadingStats = true);
        
        _imagePreloadService.preloadPokemonImage(pokemon);

        if (_statsCache.containsKey(pokemon.id)) {
          setState(() {
            pokemonToCompare = pokemon;
            statsToCompare = _statsCache[pokemon.id];
          });
          setState(() => _isLoadingStats = false);
          return;
        }

        fetchPokemonStats(pokemon.id).then((stats) {
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

        _imagePreloadService.preloadBattle(pokemonToCompare!, pokemon).then((_) {
          if (_statsCache.containsKey(pokemon.id)) {
            _navigateToComparison(pokemon, _statsCache[pokemon.id]!);
            return;
          }

          fetchPokemonStats(pokemon.id).then((stats) {
            if (stats != null) {
              _navigateToComparison(pokemon, stats);
            }
            setState(() => _isLoadingStats = false);
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
      setState(() {
        pokemonToCompare = null;
        statsToCompare = null;
        isComparisonMode = false;
        _isLoadingStats = false;
      });
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
      child: Focus(
        onFocusChange: (hasFocus) {
          if (!hasFocus && _searchController.text.isEmpty) {
            setState(() {
              suggestions = [];
            });
          }
        },
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
            suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
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
                )
              : null,
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
    );
  }

  Widget buildPokemonCard(Pokemon pokemon) {
    bool isSelected = (pokemonToCompare?.id == pokemon.id);
    Color typeColor = getTypeColor(pokemon.types.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Obtemos o tamanho total disponível para o card
        // Definimos a área da imagem com 65% da altura do card
        double imageHeight = constraints.maxHeight * 0.65;

        return AnimatedBuilder(
          animation: _cardAnimationController,
          builder: (context, child) {
            double scaleAnim = isSelected
                ? 1.0 + 0.05 * math.sin(_cardAnimationController.value * 2 * math.pi)
                : 1.0;
            return Transform.scale(
              scale: scaleAnim,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _handlePokemonTap(pokemon),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
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
              child: Column(
                children: [
                  // Área da imagem obtida dinamicamente
                  Container(
                    height: imageHeight,
                    alignment: Alignment.center,
                    padding: EdgeInsets.all(8),
                    child: Hero(
                      tag: 'pokemon-${pokemon.id}',
                      child: CachedNetworkImage(
                        imageUrl: pokemon.imageUrl,
                        // define a altura da imagem com base no cálculo
                        height: imageHeight,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                        errorWidget: (context, url, error) => Icon(Icons.error_outline),
                      ),
                    ),
                  ),
                  // Área de textos (nome e tipos) ocupa o restante do espaço
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
            ),
          ),
        );
      },
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
    for (var pokemon in pokemons) {
      if (!_statsCache.containsKey(pokemon.id)) {
        fetchPokemonStats(pokemon.id).then((stats) {
          if (stats != null) {
            _statsCache[pokemon.id] = stats;
          }
        });
      }
    }
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
          ...getPageRange().map((page) => Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: page == currentPage ? Colors.red : Colors.white,
                foregroundColor: page == currentPage ? Colors.white : Colors.red,
                elevation: page == currentPage ? 4 : 2,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => changePage(page),
              child: Text(
                page.toString(),
                style: TextStyle(
                  fontWeight: page == currentPage ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          )),
          SizedBox(width: 8),
          if (currentPage < 50)
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('PokéDex'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade700, Colors.red.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            buildSearchArea(),
            if (_searchController.text.isNotEmpty) buildSuggestions(),
            if (searchResults.isNotEmpty) buildSearchResults(),
            if (_searchController.text.isEmpty)
              FutureBuilder<List<Pokemon>>(
                future: fetchPokemonList(page: currentPage),
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
                  // Pre-fetch stats para otimizar a performance
                  if (isComparisonMode) {
                    _prefetchStats(pokemonList);
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
              ),
            buildPaginationButtons(),
          ],
        ),
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
      // Adiciona um overlay quando estiver no modo de batalha
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
