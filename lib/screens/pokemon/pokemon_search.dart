import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../models/pokemon.dart';
import '../../widgets/pokeball_painter.dart';
import '../../widgets/subtle_no_results.dart';

class PokemonSearch extends StatefulWidget {
  final Function(List<Pokemon>) onSearchResults;
  final Function(String) onError;
  final bool Function(Pokemon) shouldIncludePokemon;
  final bool isSearching;
  final bool showAdvancedSearch;
  final Function(bool) onAdvancedSearchToggle;
  final TextEditingController searchController;

  const PokemonSearch({
    Key? key,
    required this.onSearchResults,
    required this.onError,
    required this.shouldIncludePokemon,
    required this.isSearching,
    required this.showAdvancedSearch,
    required this.onAdvancedSearchToggle,
    required this.searchController,
  }) : super(key: key);

  @override
  _PokemonSearchState createState() => _PokemonSearchState();
}

class _PokemonSearchState extends State<PokemonSearch> with SingleTickerProviderStateMixin {
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounceTimer;
  bool _isSearching = false;
  String _searchError = '';
  List<String> _suggestions = [];
  late AnimationController _pokeballAnimationController;
  Timer? _debounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(() => _onSearchChanged(widget.searchController.text));
    _pokeballAnimationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    _pokeballAnimationController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    
    setState(() {
      _searchQuery = query;
      _isSearching = query.isNotEmpty;
    });

    if (query.isEmpty) {
      widget.onSearchResults([]);
      return;
    }

    _debounce = Timer(Duration(milliseconds: 300), () async {
      if (!mounted) return;
      
      try {
        final results = await _performSearch(query);
        if (!mounted) return;
        
        setState(() => _isSearching = false);
        widget.onSearchResults(results);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSearching = false);
        widget.onError('Erro ao buscar Pokémon. Tente novamente.');
      }
    });
  }

  bool _containsSequence(String name, String query) {
    if (query.isEmpty) return true;
    return name.toLowerCase().contains(query.toLowerCase());
  }

  Future<List<Pokemon>> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _isSearching = false);
      return [];
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon?limit=1000'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List;
        final List<Pokemon> matchingPokemons = [];

        for (var result in results) {
          final name = result['name'] as String;
          if (_containsSequence(name, query)) {
            final pokemonUrl = result['url'] as String;
            final pokemonId = int.parse(pokemonUrl.split('/')[6]);

            try {
              final pokemonResponse = await http.get(Uri.parse(pokemonUrl));
              if (pokemonResponse.statusCode == 200) {
                final pokemonData = json.decode(pokemonResponse.body);
                final pokemon = Pokemon.fromDetailJson(pokemonData);

                if (widget.shouldIncludePokemon(pokemon)) {
                  matchingPokemons.add(pokemon);
                }
              }
            } catch (e) {
              print('Erro ao buscar detalhes do Pokémon: $e');
              continue;
            }
          }
        }

        matchingPokemons.sort((a, b) => a.id.compareTo(b.id));
        return matchingPokemons;

      } else {
        throw Exception('Erro ao buscar Pokémon');
      }
    } catch (e) {
      throw Exception('Erro na busca: Verifique sua conexão com a internet');
    } finally {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Widget _buildSuffixIcon() {
    if (widget.searchController.text.isEmpty) {
      return SizedBox.shrink();
    }

    if (_isSearching) {
      return Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
          ),
        ),
      );
    }

    return IconButton(
      icon: Icon(Icons.close, color: Colors.grey[600]),
      onPressed: () {
        widget.searchController.clear();
        widget.onSearchResults([]);
        setState(() {
          _suggestions = [];
          _searchError = '';
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
          if (!hasFocus && widget.searchController.text.isEmpty) {
            setState(() {
              _suggestions = [];
            });
          }
        },
        child: TextField(
          controller: widget.searchController,
          decoration: InputDecoration(
            hintText: 'Buscar Pokémon...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            prefixIcon: AnimatedRotation(
              duration: Duration(milliseconds: 300),
              turns: widget.isSearching ? 1 : 0,
              child: Icon(
                Icons.catching_pokemon,
                color: widget.isSearching ? Colors.red : Colors.grey,
              ),
            ),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSuffixIcon(),
                IconButton(
                  icon: Icon(
                    Icons.tune,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    widget.onAdvancedSearchToggle(!widget.showAdvancedSearch);
                  },
                ),
              ],
            ),
          ),
          onChanged: (value) => _onSearchChanged(value),
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            if (value.isNotEmpty) {
              _onSearchChanged(value);
            }
          },
        ),
      ),
    );
  }
} 