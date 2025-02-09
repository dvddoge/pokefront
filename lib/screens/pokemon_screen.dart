import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../models/pokemon.dart';
import 'pokemon_detail_screen.dart';

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
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
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

  Widget buildSearchArea() {
    return Container(
      margin: EdgeInsets.all(16),
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

        return MouseRegion(
          onEnter: (_) => setState(() => isHovered = true),
          onExit: (_) => setState(() => isHovered = false),
          cursor: SystemMouseCursors.click,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Card(
              elevation: isHovered ? 8 : 4,
              color: isHovered ? Colors.grey[50] : Colors.white,
              shadowColor: getTypeColor(pokemon.primaryType).withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PokemonDetailScreen(
                        pokemonId: pokemon.id,
                        pokemonName: pokemon.name,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Hero(
                        tag: 'pokemon-${pokemon.id}',
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          transform: Matrix4.identity()..scale(isHovered ? 1.2 : 1.0),
                          child: CachedNetworkImage(
                            imageUrl: pokemon.imageUrl,
                            placeholder: (context, url) => Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isHovered 
                            ? getTypeColor(pokemon.primaryType).withOpacity(0.08)
                            : Colors.transparent,
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            pokemon.name.toUpperCase(),
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isHovered 
                                  ? getTypeColor(pokemon.primaryType)
                                  : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            children: pokemon.types.map((type) => _buildTypeChip(
                              type: type,
                              isHovered: isHovered,
                            )).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
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
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: EdgeInsets.all(16),
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
              SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions.map((suggestion) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        _searchController.text = suggestion;
                        _searchController.selection = TextSelection.fromPosition(
                          TextPosition(offset: suggestion.length),
                        );
                        _performSearch(suggestion);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          suggestion.toUpperCase(),
                          style: TextStyle(
                            color: Colors.red[700],
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
                    return const Padding(
                      padding: EdgeInsets.only(top: 80.0),
                      child: Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(
                        child: Text('Erro: ${snapshot.error}'),
                      ),
                    );
                  } else {
                    final pokemonList = snapshot.data ?? [];
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, // Alterado para 3 pokémons por linha
                        childAspectRatio: 0.75, // Ajustado para melhor proporção
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
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
                    );
                  }
                },
              ),
            buildPaginationButtons(),
          ],
        ),
      ),
    );
  }
}
