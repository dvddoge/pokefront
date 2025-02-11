import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

import '../../models/pokemon.dart';
import '../../widgets/pokeball_painter.dart';
import '../../services/pokemon_list_service.dart';

class PokemonGrid extends StatefulWidget {
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

  const PokemonGrid({
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
  _PokemonGridState createState() => _PokemonGridState();
}

class _PokemonGridState extends State<PokemonGrid> {
  final Map<String, List<Pokemon>> _cache = {};
  bool _isLoading = false;
  List<Pokemon> _currentPokemons = [];
  final ScrollController _scrollController = ScrollController();
  bool _disposed = false;
  String? _lastCacheKey;

  @override
  void initState() {
    super.initState();
    _fetchPokemonList();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _disposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PokemonGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTypes != widget.selectedTypes ||
        oldWidget.selectedGeneration != widget.selectedGeneration ||
        oldWidget.powerRange != widget.powerRange) {
      _cache.clear();
      _lastCacheKey = null;
    }
    if (oldWidget.currentPage != widget.currentPage ||
        oldWidget.selectedTypes != widget.selectedTypes ||
        oldWidget.selectedGeneration != widget.selectedGeneration ||
        oldWidget.powerRange != widget.powerRange) {
      _fetchPokemonList();
    }
  }

  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) {
      setState(fn);
    }
  }

  void _onScroll() {
    if (!_isLoading && !_disposed &&
        _scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      _loadMorePokemons();
    }
  }

  Future<void> _loadMorePokemons() async {
    if (_isLoading || _disposed) return;
    
    _safeSetState(() => _isLoading = true);
    widget.onChangePage(widget.currentPage + 1);
    await _fetchPokemonList();
    if (!_disposed) {
      _safeSetState(() => _isLoading = false);
    }
  }

  Future<void> _fetchPokemonList() async {
    if (_isLoading || _disposed) return;
    _safeSetState(() => _isLoading = true);

    try {
      final hasActiveFilters = widget.selectedTypes.isNotEmpty || 
                             widget.selectedGeneration > 0 || 
                             widget.powerRange != RangeValues(0, 1000);

      final String cacheKey = hasActiveFilters 
        ? '${widget.selectedTypes.toString()}_${widget.selectedGeneration}_${widget.powerRange.toString()}_page_${widget.currentPage}'
        : 'page_${widget.currentPage}';

      if (_cache.containsKey(cacheKey)) {
        _safeSetState(() {
          _currentPokemons = List<Pokemon>.from(_cache[cacheKey]!);
          _isLoading = false;
        });
        widget.onPokemonsLoaded(_currentPokemons);
        return;
      }

      final pokemonService = PokemonListService();
      final result = await pokemonService.fetchPokemonList(
        page: widget.currentPage,
        selectedTypes: widget.selectedTypes,
        selectedGeneration: widget.selectedGeneration,
        powerRange: widget.powerRange,
      );

      if (_disposed) return;

      final List<Pokemon> pokemons = result['pokemons'];
      if (pokemons.isNotEmpty) {
        pokemons.sort((a, b) => a.id.compareTo(b.id));
        _cache[cacheKey] = List<Pokemon>.from(pokemons);
        
        _safeSetState(() {
          _currentPokemons = List<Pokemon>.from(pokemons);
          _isLoading = false;
        });
        
        widget.onPokemonsLoaded(_currentPokemons);
      } else {
        _safeSetState(() => _isLoading = false);
      }
    } catch (e) {
      if (!_disposed) {
        _safeSetState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Pokemon?>(
      valueListenable: widget.selectedPokemonNotifier,
      builder: (context, selectedPokemon, child) {
        return ValueListenableBuilder<bool>(
          valueListenable: widget.isLoadingStatsNotifier,
          builder: (context, isLoadingStats, child) {
            return Column(
              children: [
                AnimationLimiter(
                  child: GridView.builder(
                    controller: _scrollController,
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.80,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: _currentPokemons.length,
                    itemBuilder: (context, index) {
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375),
                        columnCount: 3,
                        child: ScaleAnimation(
                          scale: 0.5,
                          child: FadeInAnimation(
                            child: buildPokemonCard(_currentPokemons[index]),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_isLoading)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget buildPokemonCard(Pokemon pokemon) {
    bool isSelected = (widget.selectedPokemonNotifier.value?.id == pokemon.id);
    Color typeColor = widget.getTypeColor(pokemon.types.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        double imageHeight = constraints.maxHeight * 0.65;

        return AnimatedBuilder(
          animation: widget.cardAnimationController,
          builder: (context, child) {
            double scaleAnim = isSelected
                ? 1.0 + 0.05 * math.sin(widget.cardAnimationController.value * 2 * math.pi)
                : 1.0;

            if (isSelected && !widget.cardAnimationController.isAnimating) {
              widget.cardAnimationController.repeat();
            }

            return Transform.scale(
              scale: scaleAnim,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () {
              widget.onPokemonTap(pokemon);
              if (!isSelected) {
                widget.cardAnimationController.reset();
                widget.cardAnimationController.repeat();
              }
            },
            child: AnimatedContainer(
              duration: Duration(milliseconds: 300),
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
                              final color = widget.getTypeColor(type);
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
} 