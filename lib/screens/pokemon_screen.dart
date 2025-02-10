import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/pokemon.dart';
import 'pokemon_detail_screen.dart';
import 'pokemon_comparison_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1000),
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shakeController.reverse();
      } else if (status == AnimationStatus.dismissed && pokemonToCompare != null) {
        _shakeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _shakeController.dispose();
    _debounce?.cancel();
    _imagePreloadService.clearCache();
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

  void _handleComparison(Pokemon pokemon, Map<String, int> stats) {
    setState(() {
      if (pokemonToCompare == null) {
        pokemonToCompare = pokemon;
        statsToCompare = stats;
        _shakeController.forward(from: 0);
        
        // Mostra mensagem de confirmação
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                CachedNetworkImage(
                  imageUrl: pokemon.imageUrl,
                  height: 30,
                  width: 30,
                ),
                SizedBox(width: 12),
                Text('${pokemon.name.toUpperCase()} selecionado para batalha!'),
              ],
            ),
            backgroundColor: Colors.red[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'Cancelar',
              textColor: Colors.white,
              onPressed: _cancelComparison,
            ),
          ),
        );
      } else {
        // Verifica se não está tentando comparar com o mesmo Pokémon
        if (pokemonToCompare!.id == pokemon.id) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Escolha um Pokémon diferente para a batalha!'),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          return;
        }

        // Se já existe um Pokémon selecionado, navega para a tela de comparação
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PokemonComparisonScreen(
              pokemon1: pokemonToCompare!,
              pokemon2: pokemon,
              stats1: statsToCompare!,
              stats2: stats,
            ),
          ),
        ).then((_) {
          setState(() {
            pokemonToCompare = null;
            statsToCompare = null;
          });
        });
      }
    });
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
      if (_isLoadingStats) return; // Previne múltiplos taps enquanto carrega

      if (pokemonToCompare == null) {
        setState(() => _isLoadingStats = true);
        
        // Pré-carregar a imagem quando selecionar o primeiro pokémon
        _imagePreloadService.preloadPokemonImage(pokemon);

        // Verifica primeiro se já temos os stats em cache
        if (_statsCache.containsKey(pokemon.id)) {
          setState(() {
            pokemonToCompare = pokemon;
            statsToCompare = _statsCache[pokemon.id];
            _isLoadingStats = false;
            _shakeController.reset();
            _shakeController.forward();
          });
          return;
        }

        // Se não estiver em cache, busca os stats
        fetchPokemonStats(pokemon.id).then((stats) {
          if (stats != null) {
            setState(() {
              pokemonToCompare = pokemon;
              statsToCompare = stats;
              _shakeController.reset();
              _shakeController.forward();
            });
          }
          setState(() => _isLoadingStats = false);
        });
      } else if (pokemonToCompare!.id != pokemon.id) {
        setState(() => _isLoadingStats = true);

        // Pré-carregar as imagens antes de navegar para a comparação
        _imagePreloadService.preloadBattle(pokemonToCompare!, pokemon).then((_) {
          // Verifica o cache primeiro
          if (_statsCache.containsKey(pokemon.id)) {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => PokemonComparisonScreen(
                  pokemon1: pokemonToCompare!,
                  pokemon2: pokemon,
                  stats1: statsToCompare!,
                  stats2: _statsCache[pokemon.id]!,
                ),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  const begin = Offset(1.0, 0.0);
                  const end = Offset.zero;
                  const curve = Curves.easeInOutCubic;
                  var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                  var offsetAnimation = animation.drive(tween);
                  return SlideTransition(position: offsetAnimation, child: child);
                },
              ),
            ).then((_) {
              setState(() {
                pokemonToCompare = null;
                statsToCompare = null;
                isComparisonMode = false;
                _isLoadingStats = false;
              });
            });
            return;
          }

          // Se não estiver em cache, busca os stats
          fetchPokemonStats(pokemon.id).then((stats) {
            if (stats != null) {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => PokemonComparisonScreen(
                    pokemon1: pokemonToCompare!,
                    pokemon2: pokemon,
                    stats1: statsToCompare!,
                    stats2: stats,
                  ),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOutCubic;
                    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(position: offsetAnimation, child: child);
                  },
                ),
              ).then((_) {
                setState(() {
                  pokemonToCompare = null;
                  statsToCompare = null;
                  isComparisonMode = false;
                });
              });
            }
            setState(() => _isLoadingStats = false);
          });
        });
      }
    } else {
      // Pré-carregar a imagem antes de navegar para os detalhes
      _imagePreloadService.preloadPokemonImage(pokemon).then((_) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PokemonDetailScreen(
              pokemonId: pokemon.id,
              pokemonName: pokemon.name,
            ),
          ),
        );
      });
    }
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
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;
        bool isSelected = pokemonToCompare?.id == pokemon.id;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: AnimatedBuilder(
            animation: _shakeController,
            builder: (context, child) {
              double shake = isSelected ? 
                sin(_shakeController.value * 2 * 3.14159) * 3 : 0;
              return Transform.translate(
                offset: Offset(shake, 0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? Border.all(
                      color: getTypeColor(pokemon.primaryType),
                      width: 3,
                    ) : null,
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: getTypeColor(pokemon.primaryType).withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ] : null,
                  ),
                  child: Card(
                    elevation: isHovered || isSelected ? 8 : 4,
                    color: isSelected ? 
                      getTypeColor(pokemon.primaryType).withOpacity(0.1) : 
                      (isHovered ? Colors.grey[50] : Colors.white),
                    shadowColor: getTypeColor(pokemon.primaryType).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: InkWell(
                      onTap: () => _handlePokemonTap(pokemon),
                      hoverColor: isComparisonMode ? 
                        getTypeColor(pokemon.primaryType).withOpacity(0.1) : 
                        Colors.grey.withOpacity(0.1),
                      splashColor: isComparisonMode ? 
                        getTypeColor(pokemon.primaryType).withOpacity(0.2) : 
                        Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Center(
                                    child: Hero(
                                      tag: pokemonToCompare?.id == pokemon.id ? 
                                        'compare-${pokemon.id}' : 
                                        'pokemon-${pokemon.id}',
                                      child: CachedNetworkImage(
                                        imageUrl: pokemon.imageUrl,
                                        height: 220,
                                        width: 220,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => Shimmer.fromColors(
                                          baseColor: Colors.grey[300]!,
                                          highlightColor: Colors.grey[100]!,
                                          child: Container(
                                            height: 220,
                                            width: 220,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      pokemon.name.toUpperCase(),
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: pokemon.types.map((type) => 
                                        Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 4),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: getTypeColor(type),
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
                                          ),
                                        ),
                                      ).toList(),
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          if (isSelected)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: getTypeColor(pokemon.primaryType),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.sports_kabaddi,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
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

  Widget _buildTypeChip({required String type, required bool isHovered}) {
    final typeColor = getTypeColor(type);
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(
        horizontal: isHovered ? 12 : 8,
        vertical: isHovered ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: isHovered ? typeColor : typeColor.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isHovered ? [
          BoxShadow(
            color: typeColor.withOpacity(0.4),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ] : [],
      ),
      child: Text(
        type.toUpperCase(),
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
          fontSize: isHovered ? 13 : 12,
        ),
      ),
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
          child: Text(
            searchError,
            style: TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    if (searchResults.isNotEmpty) {
      return AnimationLimiter(
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.75,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
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
              Text(
                'Nenhum Pokémon encontrado',
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
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
          childAspectRatio: 0.65,
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
            child: buildPageButton(page, isSelected: page == currentPage),
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

  Widget buildPageButton(int page, {bool isSelected = false}) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isHovered = false;

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: TweenAnimationBuilder(
            duration: Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            tween: Tween<double>(begin: 0, end: isSelected ? 1.1 : (isHovered ? 1.05 : 1.0)),
            builder: (context, double scale, child) {
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 50,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected 
                          ? Colors.red 
                          : (isHovered ? Colors.red.withOpacity(0.1) : Colors.white),
                      foregroundColor: isSelected 
                          ? Colors.white 
                          : (isHovered ? Colors.red : Colors.black87),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      elevation: isSelected ? 8 : (isHovered ? 4 : 2),
                      shadowColor: isSelected 
                          ? Colors.red.withOpacity(0.4) 
                          : (isHovered ? Colors.red.withOpacity(0.2) : Colors.black12),
                    ),
                    onPressed: () => changePage(page),
                    child: Text(
                      page.toString(),
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: isSelected || isHovered 
                            ? FontWeight.bold 
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            },
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
        title: TweenAnimationBuilder(
          duration: Duration(milliseconds: 1000),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Transform.scale(
              scale: value,
              child: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    Colors.blue,
                    Colors.red,
                    Colors.yellow,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  transform: GradientRotation(value * 6.28),
                ).createShader(bounds),
                child: Text(
                  'PokéDex',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    shadows: [
                      Shadow(
                        color: Colors.red.withOpacity(0.3),
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                      Shadow(
                        color: Colors.blue.withOpacity(0.3),
                        offset: Offset(-2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        centerTitle: true,
        flexibleSpace: TweenAnimationBuilder(
          duration: Duration(milliseconds: 1500),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.red.withOpacity(0.1 * value),
                    Colors.blue.withOpacity(0.05 * value),
                    Colors.yellow.withOpacity(0.05 * value),
                  ],
                  stops: [0, 0.3, 0.6, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Transform.rotate(
                      angle: value * 6.28,
                      child: Opacity(
                        opacity: value * 0.3,
                        child: Icon(
                          Icons.catching_pokemon,
                          size: 64,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
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
                        childAspectRatio: 0.65,
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
