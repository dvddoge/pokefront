import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../widgets/pokemon_net_image.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../../models/pokemon.dart';
import '../../services/image_preload_service.dart';
import '../../services/pokemon_list_service.dart';
import '../../widgets/subtle_no_results.dart';
import '../pokemon_comparison_screen.dart' as comparison;
import '../pokemon_detail_screen.dart' as detail;
import '../battle/pokemon_battle_screen.dart';
import '../battle/components/battle_transition.dart';
import 'pokemon_search.dart';
import 'pokemon_filters.dart';
import '../../services/pokemon_filter_service.dart';
import '../../services/pokemon_cache_service.dart';
import '../tournament/tournament_screen.dart';
import '../achievements_screen.dart';
import '../settings_screen.dart';
import '../../widgets/fan_menu.dart';

class PokemonScreen extends StatefulWidget {
  const PokemonScreen({super.key});

  @override
  _PokemonScreenState createState() => _PokemonScreenState();
}

class _PokemonScreenState extends State<PokemonScreen>
    with TickerProviderStateMixin {
  int currentPage = 1;
  final int pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  bool isSearching = false;
  String searchError = '';
  final _scrollController = ScrollController();
  Timer? _debounce;
  List<Pokemon> searchResults = [];
  List<Pokemon> allSearchResults =
      []; // Lista completa filtrada (localmente ou do serviço)
  List<Pokemon> originalSearchResults =
      []; // Lista original BRUTA da busca por texto
  int totalPages = 1;
  String currentSearchQuery = '';
  bool isSearchMode = false;
  bool isComparisonMode = false;
  bool isBattleMode = false;
  Pokemon? pokemonToCompare;
  Map<String, int>? statsToCompare;
  bool _isLoadingStats = false;

  // Novos estados para controle da transição
  bool _showClosingTransition = false;
  Pokemon? _pokemon1ForBattle;
  Pokemon? _pokemon2ForBattle;

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
  final ValueNotifier<Pokemon?> _selectedPokemonNotifier =
      ValueNotifier<Pokemon?>(null);
  final ValueNotifier<bool> _comparisonModeNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isLoadingStatsNotifier =
      ValueNotifier<bool>(false);

  // Filtros
  Map<String, bool> selectedTypes = {};
  RangeValues powerRange = const RangeValues(0, 1000);
  // Novos filtros numéricos
  RangeValues heightRange = const RangeValues(0, 20); // metros
  RangeValues weightRange = const RangeValues(0, 1000); // kg
  int selectedGeneration = 0;
  bool showAdvancedSearch = false;
  bool isFiltering = false;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();

    // Registrar a instância do service no cache para limpeza
    PokemonCacheService.setPokemonListService(_pokemonListService);

    _loadInitialPokemonList();
    _selectedPokemonNotifier.addListener(_handlePokemonSelectionChange);
    _comparisonModeNotifier.addListener(_handleComparisonModeChange);
  }

  void _setupAnimationControllers() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _bannerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 4000),
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
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        } else if (status == AnimationStatus.dismissed &&
            pokemonToCompare != null) {
          _shakeController.forward();
        }
      });

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _loadingAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(
          milliseconds: 2000), // Mais lento para ser mais visível
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
    if (!mounted) return;

    setState(() {
      isSearching = true;
      searchError = '';
    });

    try {
      print(
          'LoadInitialPokemonList: Buscando página $currentPage com filtros...');
      final result = await _pokemonListService
          .fetchPokemonList(
        page: currentPage,
        selectedTypes: selectedTypes,
        selectedGeneration: selectedGeneration,
        powerRange: powerRange,
        heightRange: heightRange,
        weightRange: weightRange,
      )
          .timeout(const Duration(seconds: 20), onTimeout: () {
        print('Timeout ao carregar Pokémon');
        return {'pokemons': _getDefaultPokemons(), 'total': 10};
      });

      if (!mounted) return;

      setState(() {
        // Recebe os resultados do serviço
        final List<Pokemon> fetchedPokemons = result['pokemons'];
        final int totalFetched = result['total'];

        searchResults = fetchedPokemons;
        totalPages = (totalFetched / pageSize).ceil();
        isSearching = false;

        // Verifica se a *página específica* está vazia, mas a busca geral não falhou
        if (fetchedPokemons.isEmpty && totalFetched > 0 && currentPage > 1) {
          searchError = 'Não há mais Pokémon para carregar.';
          // Não substitui por padrão, apenas informa o usuário.
          // A UI deve tratar a lista vazia corretamente.
        } else if (fetchedPokemons.isEmpty && totalFetched == 0) {
          searchError = 'Nenhum Pokémon encontrado com os filtros aplicados.';
          // Aqui também não substitui, a UI deve mostrar a mensagem.
        } else if (fetchedPokemons.isEmpty) {
          searchError = 'Nenhum Pokémon encontrado.';
          // Caso inicial ou erro inesperado, pode mostrar padrão se desejar
          // searchResults = _getDefaultPokemons();
        } else {
          searchError = ''; // Limpa erro se carregar com sucesso
          print(
              'Carregados ${searchResults.length} Pokémon com sucesso para a página $currentPage');
        }
      });
    } catch (e) {
      print('Erro ao carregar lista inicial: $e');
      if (!mounted) return;

      setState(() {
        isSearching = false;
        searchError = 'Erro ao carregar Pokémon. Tente novamente.';

        // Adiciona alguns Pokémon padrão para evitar tela vazia
        searchResults = _getDefaultPokemons();
        totalPages = 1;
      });
    } finally {
      // Garantir que o estado de carregamento seja desativado mesmo em caso de erro
      if (mounted && isSearching) {
        setState(() {
          isSearching = false;
        });
      }
    }
  }

  // Método para obter uma lista de Pokémon padrão quando ocorre um erro
  List<Pokemon> _getDefaultPokemons() {
    return List.generate(10, (index) {
      final id = index + 1;
      return Pokemon(
        id: id,
        name: 'Pokémon $id',
        imageUrl:
            'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$id.png',
        types: ['normal'],
      );
    });
  }

  List<Pokemon> _getPageItems(int page, [List<Pokemon>? sourceList]) {
    // Prioriza sourceList se fornecido, caso contrário usa a lógica padrão baseada em isSearchMode
    final list =
        sourceList ?? (isSearchMode ? allSearchResults : searchResults);
    final startIndex = (page - 1) * pageSize;
    final endIndex = math.min(startIndex + pageSize, list.length);
    if (startIndex >= list.length || startIndex < 0)
      return []; // Adicionado cheque startIndex < 0 por segurança
    return list.sublist(startIndex, endIndex);
  }

  void _handleSearchResults(List<Pokemon> rawResults) {
    if (!mounted) return;
    final currentQuery = _searchController.text;
    final stillInSearchMode = currentQuery.isNotEmpty;
    print(
        "HandleSearchResults: Recebido ${rawResults.length} resultados brutos para '$currentQuery'");

    setState(() {
      isSearchMode = stillInSearchMode;
      currentSearchQuery = currentQuery;
      originalSearchResults = rawResults;
      currentPage = 1;
      isSearching = false;

      if (stillInSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        print(
            "HandleSearchResults: Busca limpa, chamando _loadInitialPokemonList");
        searchResults = [];
        allSearchResults = [];
        totalPages = 0;
        searchError = '';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _loadInitialPokemonList();
          }
        });
      }
    });
  }

  Map<String, dynamic> _calculateFilteredState() {
    if (!isSearchMode) {
      print("_calculateFilteredState: Chamada inválida (isSearchMode = false)");
      // Retorna listas vazias do tipo correto para evitar type errors posteriores
      return {
        'searchResults': <Pokemon>[],
        'allSearchResults': <Pokemon>[],
        'totalPages': 0,
        'searchError': ''
      };
    }

    print(
        "CalculateFilteredState START: originalSearchResults.length = ${originalSearchResults.length}");
    bool filtersAreActive = selectedTypes.values.any((v) => v) ||
        selectedGeneration > 0 ||
        powerRange != const RangeValues(0, 1000) ||
        heightRange != const RangeValues(0, 20) ||
        weightRange != const RangeValues(0, 1000);
    print("CalculateFilteredState: Filters Active = $filtersAreActive");

    List<Pokemon> filteredList;
    if (filtersAreActive) {
      try {
        // Certifique-se que _shouldIncludePokemon lida bem com estados intermediários se necessário
        filteredList =
            originalSearchResults.where(_shouldIncludePokemon).toList();
      } catch (e) {
        print("CalculateFilteredState: ERRO durante .where: $e");
        filteredList = <Pokemon>[]; // Use tipo explícito
      }
    } else {
      // Cria uma nova lista para evitar modificar a original indiretamente
      filteredList = List<Pokemon>.from(originalSearchResults);
    }
    print(
        "CalculateFilteredState END: filteredList.length = ${filteredList.length}");

    // Calcula os novos valores
    List<Pokemon> newAllSearchResults = filteredList;
    // Usa currentPage que já foi resetado para 1
    // Passa newAllSearchResults explicitamente como sourceList para _getPageItems
    List<Pokemon> newSearchResults = _getPageItems(1, newAllSearchResults);
    int newTotalPages = newAllSearchResults.isEmpty
        ? 0
        : (newAllSearchResults.length / pageSize).ceil();
    // Garante que totalPages seja pelo menos 1 se houver resultados, mesmo que menos que pageSize
    if (newTotalPages == 0 && newAllSearchResults.isNotEmpty) {
      newTotalPages = 1;
    }

    String newSearchError = newAllSearchResults.isEmpty
        ? (filtersAreActive
            ? 'Nenhum Pokémon encontrado com esta busca e filtros.'
            : 'Nenhum Pokémon encontrado para "$currentSearchQuery".')
        : '';

    print(
        "CalculateFilteredState RESULT: newSearchResults.length=${newSearchResults.length}, newAllSearchResults.length=${newAllSearchResults.length}, newTotalPages=$newTotalPages, newSearchError='$newSearchError'");

    return {
      'searchResults': newSearchResults, // Esta é a lista para a página atual
      'allSearchResults':
          newAllSearchResults, // Esta é a lista completa filtrada
      'totalPages': newTotalPages,
      'searchError': newSearchError,
    };
  }

  void _reapplyLocalFiltersAndUpdateStateVariables() {
    final newState = _calculateFilteredState();
    searchResults = newState['searchResults'] as List<Pokemon>;
    allSearchResults = newState['allSearchResults'] as List<Pokemon>;
    totalPages = newState['totalPages'] as int;
    searchError = newState['searchError'] as String;
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
      if (isSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        _loadInitialPokemonList();
      }
    });
  }

  void _handleGenerationChanged(int generation) {
    setState(() {
      selectedGeneration = generation;
      currentPage = 1;
      if (isSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        _loadInitialPokemonList();
      }
    });
  }

  void _handlePowerRangeChanged(RangeValues range) {
    setState(() {
      powerRange = range;
      currentPage = 1;
      if (isSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        _loadInitialPokemonList();
      }
    });
  }

  void _handleHeightRangeChanged(RangeValues range) {
    setState(() {
      heightRange = range;
      currentPage = 1;
      if (isSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        _loadInitialPokemonList();
      }
    });
  }

  void _handleWeightRangeChanged(RangeValues range) {
    setState(() {
      weightRange = range;
      currentPage = 1;
      if (isSearchMode) {
        _reapplyLocalFiltersAndUpdateStateVariables();
      } else {
        _loadInitialPokemonList();
      }
    });
  }

  bool _shouldIncludePokemon(Pokemon pokemon) {
    return PokemonFilterService.shouldIncludePokemon(
      pokemon: pokemon,
      selectedTypes: selectedTypes,
      selectedGeneration: selectedGeneration,
      powerRange: powerRange,
      heightRange: heightRange,
      weightRange: weightRange,
    );
  }

  Color getTypeColor(String type) {
    final colors = {
      'fire': const Color(0xFFEE8130),
      'water': const Color(0xFF6390F0),
      'grass': const Color(0xFF7AC74C),
      'electric': const Color(0xFFF7D02C),
      'psychic': const Color(0xFFF95587),
      'ice': const Color(0xFF96D9D6),
      'dragon': const Color(0xFF6F35FC),
      'dark': const Color(0xFF705746),
      'fairy': const Color(0xFFD685AD),
      'fighting': const Color(0xFFC22E28),
      'flying': const Color(0xFFA98FF3),
      'poison': const Color(0xFFA33EA1),
      'ground': const Color(0xFFE2BF65),
      'rock': const Color(0xFFB6A136),
      'bug': const Color(0xFFA6B91A),
      'ghost': const Color(0xFF735797),
      'steel': const Color(0xFFB7B7CE),
      'normal': const Color(0xFFA8A77A),
    };
    return colors[type.toLowerCase()] ?? Colors.grey;
  }

  void _handlePokemonTap(Pokemon pokemon) {
    // Se um modo especial (Batalha/Comparação) estiver ativo, use a lógica dedicada.
    if (isComparisonMode) {
      _handleComparisonTap(pokemon);
      return;
    }
    if (isBattleMode) {
      _handleBattleTap(pokemon);
      return;
    }

    // Lógica de seleção padrão:
    // Se o Pokémon clicado já for o selecionado, vá para os detalhes.
    if (_selectedPokemonNotifier.value?.id == pokemon.id) {
      _handleDetailTap(pokemon);
    } else {
      // Caso contrário, apenas selecione o Pokémon.
      _selectedPokemonNotifier.value = pokemon;
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
          content: const Text('Selecione outro Pokémon para comparar!'),
          backgroundColor: Colors.orange[700],
        ),
      );
      return;
    } else {
      setState(() => _isLoadingStats = true);
      _selectedPokemonNotifier.value = pokemon;

      _pokemonListService.fetchPokemonStats(pokemon.id).then((stats) {
        if (stats != null && mounted) {
          _navigateToComparison(pokemon, stats);
        }
        if (mounted) setState(() => _isLoadingStats = false);
      });
    }
  }

  void _handleBattleTap(Pokemon pokemon) {
    if (_isLoadingStats) return;

    if (_pokemon1ForBattle == null) {
      setState(() => _isLoadingStats = true);
      _selectedPokemonNotifier.value = pokemon;

      _imagePreloadService.preloadPokemonImage(pokemon);

      setState(() {
        _pokemon1ForBattle = pokemon;
        _isLoadingStats = false;
      });
    } else if (_pokemon1ForBattle!.id == pokemon.id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Pokémon já selecionado. Escolha o oponente!'),
          backgroundColor: Colors.orange[700]));
    } else {
      setState(() => _isLoadingStats = true);
      _pokemon2ForBattle = pokemon;
      _selectedPokemonNotifier.value = null;

      _imagePreloadService
          .preloadBattle(_pokemon1ForBattle!, _pokemon2ForBattle!)
          .then((_) {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
            _showClosingTransition = true;
            isBattleMode = false;
          });
        }
      }).catchError((error) {
        print("Erro ao pre-carregar imagens da batalha: $error");
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
            _showClosingTransition = true;
            isBattleMode = false;
          });
        }
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

  void _navigateToBattle() {
    if (_pokemon1ForBattle != null && _pokemon2ForBattle != null) {
      print('Navegando para a tela de batalha...');
      if (mounted) {
        setState(() {
          _selectedPokemonNotifier.value = null;
          isBattleMode = false;
        });
      }
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation1, animation2) => PokemonBattleScreen(
            pokemon1: _pokemon1ForBattle!,
            pokemon2: _pokemon2ForBattle!,
            playOpeningAnimation: true,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ).then((_) {
        _pokemon1ForBattle = null;
        _pokemon2ForBattle = null;
        if (mounted) setState(() {});
      });
    } else {
      print("Erro: Pokémon para batalha não definidos ao tentar navegar.");
    }

    if (mounted) {
      setState(() => _showClosingTransition = false);
    }
  }

  void _cancelAction() {
    _cardAnimationController.stop();
    setState(() {
      pokemonToCompare = null;
      statsToCompare = null;
      isComparisonMode = false;
      isBattleMode = false;
    });
    _selectedPokemonNotifier.value = null;
  }

  void _handleComparisonMode() {
    setState(() {
      isComparisonMode = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
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

  void _handleBattleMode() {
    setState(() {
      isBattleMode = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.catching_pokemon, color: Colors.white),
              SizedBox(width: 12),
              Text('Selecione o primeiro Pokémon para a batalha!'),
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

  void _changePage(int newPage) {
    if (newPage < 1 || newPage > totalPages) return;

    setState(() {
      currentPage = newPage;
      // Se estiver em modo de busca, a paginação é local nos allSearchResults
      if (isSearchMode) {
        searchResults = _getPageItems(newPage, allSearchResults);
        isSearching = false; // Paginação local é rápida
      } else {
        // Senão, busca a nova página do serviço
        isSearching = true;
        _loadInitialPokemonList();
      }
    });

    // Scroll para o topo
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Widget _buildPageButton(int pageNumber) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: () => _changePage(pageNumber),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    bool isSelected = (_selectedPokemonNotifier.value?.id == pokemon.id) ||
        (pokemonToCompare?.id == pokemon.id);
    Color typeColor = getTypeColor(pokemon.types.first);

    return LayoutBuilder(
      builder: (context, constraints) {
        double imageHeight = constraints.maxHeight * 0.6;

        return AnimatedBuilder(
          animation: _cardAnimationController,
          builder: (context, child) {
            double scaleAnim = isSelected
                ? 1.0 +
                    0.03 *
                        math.sin(_cardAnimationController.value * 2 * math.pi)
                : 1.0;

            if (isSelected && !_cardAnimationController.isAnimating) {
              _cardAnimationController.repeat();
            }

            return Transform(
              transform: Matrix4.identity()..scale(scaleAnim),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: GestureDetector(
            onTap: () => _handlePokemonTap(pokemon),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isSelected
                    ? Border.all(
                        color: typeColor.withOpacity(0.8),
                        width: 2.5,
                      )
                    : null,
                boxShadow: [
                  if (isSelected) ...[
                    // Borda neon interna
                    BoxShadow(
                      color: typeColor.withOpacity(0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                    // Borda neon externa
                    BoxShadow(
                      color: typeColor.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                    // Brilho neon distante
                    BoxShadow(
                      color: typeColor.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
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
                            begin: Alignment(
                                -2.0 + _cardAnimationController.value * 4, 0),
                            end: Alignment(
                                -2.0 + _cardAnimationController.value * 4 + 1,
                                0),
                            colors: [
                              typeColor.withOpacity(0.0),
                              typeColor.withOpacity(0.15),
                              typeColor.withOpacity(0.0),
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                    ),
                  Column(
                    children: [
                      Container(
                        height: imageHeight,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(8),
                        child: Hero(
                          tag: 'pokemon-${pokemon.id}',
                          child: PokemonNetImage(
                            imageUrl: pokemon.imageUrl,
                            pokemonId: pokemon.id,
                            height: imageHeight,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              vertical: 4, horizontal: 8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                pokemon.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: pokemon.types.map((type) {
                                  final color = getTypeColor(type);
                                  return Container(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 2),
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          spreadRadius: 1,
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        type.substring(0, 1).toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              )
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
    return SafeArea(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.grey[100],
            appBar: AppBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade900.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.catching_pokemon,
                        color: Colors.red[700], size: 22),
                  ),
                  const SizedBox(width: 12),
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
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: 1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.2),
                            offset: const Offset(1, 1),
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
                    colors: [Colors.red[700]!, Colors.red[900]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              actions: const [],
            ),
            body: SafeArea(
              child: Stack(
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
                      if (showAdvancedSearch)
                        Container(
                          height: 260,
                          child: PokemonFilters(
                            selectedTypes: selectedTypes,
                            selectedGeneration: selectedGeneration,
                            powerRange: powerRange,
                            heightRange: heightRange,
                            weightRange: weightRange,
                            onTypesChanged: _handleTypesChanged,
                            onGenerationChanged: _handleGenerationChanged,
                            onPowerRangeChanged: _handlePowerRangeChanged,
                            onHeightRangeChanged: _handleHeightRangeChanged,
                            onWeightRangeChanged: _handleWeightRangeChanged,
                            getTypeColor: getTypeColor,
                            showAdvancedSearch: showAdvancedSearch,
                            onAdvancedSearchToggle: (value) {
                              setState(() => showAdvancedSearch = value);
                            },
                          ),
                        ),
                      Expanded(
                        child: searchError.isNotEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(
                                    searchError,
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              )
                            : LayoutBuilder(
                                builder: (context, constraints) {
                                  return Stack(
                                    children: [
                                      CustomScrollView(
                                        controller: _scrollController,
                                        slivers: [
                                          if (searchResults.isEmpty &&
                                              !isSearching &&
                                              isSearchMode)
                                            SliverFillRemaining(
                                              child: SubtleNoResults(
                                                searchQuery: currentSearchQuery,
                                              ),
                                            )
                                          else if (searchResults.isEmpty &&
                                              !isSearching &&
                                              (selectedTypes.isNotEmpty ||
                                                  selectedGeneration > 0 ||
                                                  powerRange !=
                                                      const RangeValues(
                                                          0, 1000) ||
                                                  heightRange !=
                                                      const RangeValues(
                                                          0, 20) ||
                                                  weightRange !=
                                                      const RangeValues(
                                                          0, 1000)))
                                            SliverFillRemaining(
                                              child: SubtleNoResults(
                                                searchQuery: isSearchMode
                                                    ? currentSearchQuery
                                                    : 'Nenhum Pokémon encontrado com os filtros selecionados:\n${[
                                                        if (selectedTypes
                                                            .isNotEmpty)
                                                          'Tipos: ${selectedTypes.entries.where((e) => e.value).map((e) => e.key.toUpperCase()).join(", ")}',
                                                        if (selectedGeneration >
                                                            0)
                                                          'Geração: $selectedGeneration',
                                                        if (powerRange !=
                                                            const RangeValues(
                                                                0, 1000))
                                                          'Poder: ${powerRange.start.toInt()} - ${powerRange.end.toInt()}',
                                                        if (heightRange !=
                                                            const RangeValues(
                                                                0, 20))
                                                          'Altura: ${heightRange.start.toStringAsFixed(1)}m - ${heightRange.end.toStringAsFixed(1)}m',
                                                        if (weightRange !=
                                                            const RangeValues(
                                                                0, 1000))
                                                          'Peso: ${weightRange.start.toInt()}kg - ${weightRange.end.toInt()}kg',
                                                      ].join('\n')}',
                                              ),
                                            )
                                          else if (searchResults.isEmpty &&
                                              !isSearching)
                                            const SliverFillRemaining(
                                              child: Center(
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.red),
                                                ),
                                              ),
                                            )
                                          else
                                            SliverPadding(
                                              padding: EdgeInsets.only(
                                                left: 12,
                                                right: 12,
                                                top: 12,
                                                bottom:
                                                    totalPages > 1 ? 80 : 12,
                                              ),
                                              sliver: SliverGrid(
                                                delegate:
                                                    SliverChildBuilderDelegate(
                                                  (context, index) {
                                                    return AnimationConfiguration
                                                        .staggeredGrid(
                                                      position: index,
                                                      duration: const Duration(
                                                          milliseconds: 375),
                                                      columnCount:
                                                          MediaQuery.of(context)
                                                                      .size
                                                                      .width <
                                                                  360
                                                              ? 2
                                                              : 3,
                                                      child: ScaleAnimation(
                                                        child: FadeInAnimation(
                                                          child:
                                                              buildPokemonCard(
                                                                  searchResults[
                                                                      index]),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                  childCount:
                                                      searchResults.length,
                                                ),
                                                gridDelegate:
                                                    SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount:
                                                      MediaQuery.of(context)
                                                                  .size
                                                                  .width <
                                                              360
                                                          ? 2
                                                          : 3,
                                                  childAspectRatio: 0.65,
                                                  crossAxisSpacing: 6,
                                                  mainAxisSpacing: 6,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (totalPages > 1)
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, -4),
                                                ),
                                              ],
                                            ),
                                            child: SafeArea(
                                              child: SingleChildScrollView(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.arrow_back_ios),
                                                      onPressed: currentPage > 1
                                                          ? () => _changePage(
                                                              currentPage - 1)
                                                          : null,
                                                      color: currentPage > 1
                                                          ? Colors.red[700]
                                                          : Colors.grey,
                                                    ),
                                                    if (currentPage > 2)
                                                      _buildPageButton(1),
                                                    if (currentPage > 3)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8),
                                                        child: Text('...',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.grey[
                                                                        600])),
                                                      ),
                                                    if (currentPage > 1)
                                                      _buildPageButton(
                                                          currentPage - 1),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 16,
                                                          vertical: 8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.red[700],
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(20),
                                                      ),
                                                      child: Text(
                                                        currentPage.toString(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                    if (currentPage <
                                                        totalPages)
                                                      _buildPageButton(
                                                          currentPage + 1),
                                                    if (currentPage <
                                                        totalPages - 1)
                                                      Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 8),
                                                        child: Text('...',
                                                            style: TextStyle(
                                                                color:
                                                                    Colors.grey[
                                                                        600])),
                                                      ),
                                                    if (currentPage <
                                                        totalPages - 2)
                                                      _buildPageButton(
                                                          totalPages),
                                                    IconButton(
                                                      icon: const Icon(Icons
                                                          .arrow_forward_ios),
                                                      onPressed: currentPage <
                                                              totalPages
                                                          ? () => _changePage(
                                                              currentPage + 1)
                                                          : null,
                                                      color: currentPage <
                                                              totalPages
                                                          ? Colors.red[700]
                                                          : Colors.grey,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                  if (isSearching)
                    Container(
                      color: Colors.black.withOpacity(0.1),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                        ),
                      ),
                    ),
                  if (_showClosingTransition)
                    Positioned.fill(
                      child: BattleTransition(
                        phase: TransitionPhase.closing,
                        onMidpoint: _navigateToBattle,
                        onTransitionComplete: () {
                          if (mounted && _showClosingTransition) {
                            setState(() => _showClosingTransition = false);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
            floatingActionButton: null,
            bottomSheet: isComparisonMode
                ? Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: Colors.red[700]?.withOpacity(0.9),
                    child: SafeArea(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (pokemonToCompare != null)
                            Row(
                              children: [
                                Hero(
                                  tag: 'compare-${pokemonToCompare!.id}',
                                  child: PokemonNetImage(
                                    imageUrl: pokemonToCompare!.imageUrl,
                                    pokemonId: pokemonToCompare!.id,
                                    height: 40,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  pokemonToCompare!.name.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          else
                            const SizedBox.shrink(),
                          Text(
                            pokemonToCompare == null
                                ? 'Selecione o primeiro Pokémon'
                                : 'Selecione o oponente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          ),
          // FanMenu posicionado no canto inferior direito
          Positioned(
            bottom: totalPages > 1 ? -30 : -20,
            right: -100,
            child: isComparisonMode || isBattleMode
                ? FloatingActionButton(
                    heroTag: 'cancel_action',
                    mini: true,
                    backgroundColor: Colors.red[700],
                    elevation: 4,
                    onPressed: _cancelAction,
                    child: Icon(Icons.close, color: Colors.white),
                  )
                : FanMenu(
                    toggleIcon: Icons.menu,
                    toggleColor: Colors.deepPurple[600]!,
                    items: [
                      FanMenuItem(
                        icon: Icons.military_tech,
                        color: Colors.purple[700]!,
                        tooltip: 'Conquistas',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AchievementsScreen(),
                            ),
                          );
                        },
                      ),
                      FanMenuItem(
                        icon: Icons.emoji_events,
                        color: Colors.amber[700]!,
                        tooltip: 'Iniciar Torneio',
                        onTap: () {
                          if (_selectedPokemonNotifier.value != null) {
                            _showTournamentConfirmation();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Primeiro, selecione um Pokémon para o torneio!'),
                                backgroundColor: Colors.amber.shade800,
                              ),
                            );
                          }
                        },
                      ),
                      FanMenuItem(
                        icon: Icons.catching_pokemon,
                        color: Colors.blue[700]!,
                        tooltip: 'Batalha',
                        onTap: _handleBattleMode,
                      ),
                      FanMenuItem(
                        icon: Icons.compare,
                        color: Colors.red[700]!,
                        tooltip: 'Comparar',
                        onTap: _handleComparisonMode,
                      ),
                      FanMenuItem(
                        icon: Icons.settings,
                        color: Colors.green[700]!,
                        tooltip: 'Configurações',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleBattleMode() {
    setState(() {
      isBattleMode = !isBattleMode;
      isComparisonMode = false;
      pokemonToCompare = null;
      _selectedPokemonNotifier.value = null;
      _pokemon1ForBattle = null;
      _pokemon2ForBattle = null;
      _comparisonModeNotifier.value = false;
    });
  }

  void _handlePokemonSelectionChange() {
    // Garante que a UI reconstrua ao mudar o pokémon selecionado
    setState(() {});
  }

  void _handleComparisonModeChange() {
    if (!_comparisonModeNotifier.value) {
      setState(() {
        pokemonToCompare = null;
        _selectedPokemonNotifier.value = null;
        isComparisonMode = false;
        isBattleMode = false;
      });
    } else {
      setState(() {
        isComparisonMode = true;
        isBattleMode = false;
        pokemonToCompare = null;
        _selectedPokemonNotifier.value = null;
      });
    }
  }

  void _showTournamentConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ValueListenableBuilder<Pokemon?>(
          valueListenable: _selectedPokemonNotifier,
          builder: (context, currentPokemon, child) {
            if (currentPokemon == null) {
              Navigator.pop(context);
              return const SizedBox.shrink();
            }

            final typeColor = getTypeColor(currentPokemon.types.first);

            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: typeColor, width: 4)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Confirmar para o Torneio?',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800),
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: typeColor.withOpacity(0.1),
                    child: PokemonNetImage(
                      imageUrl: currentPokemon.imageUrl,
                      pokemonId: currentPokemon.id,
                      height: 80,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    currentPokemon.name.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Text("Trocar Pokémon"),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.emoji_events),
                        label: const Text("Iniciar Torneio!"),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TournamentScreen(
                                playerPokemon: currentPokemon,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _searchPokemonTrigger(String query) async {
    if (query.isEmpty) {
      setState(() {
        currentSearchQuery = '';
        isSearchMode = false;
        searchResults = [];
        originalSearchResults = [];
        allSearchResults = [];
        currentPage = 1;
        totalPages = 1;
        searchError = '';
      });
      _loadInitialPokemonList();
      return;
    }

    setState(() {
      isSearching = true;
      searchError = '';
      currentSearchQuery = query;
      isSearchMode = true;
    });
    try {
      print("SearchPokemonTrigger: Buscando resultados brutos para '$query'");
      final results = await _pokemonListService.searchPokemonByName(
        query,
        selectedTypes: selectedTypes,
        selectedGeneration: selectedGeneration,
        powerRange: powerRange,
        heightRange: heightRange,
        weightRange: weightRange,
      );
      _handleSearchResults(results);
    } catch (e) {
      _handleSearchError('Erro ao buscar Pokémon: $e');
      if (mounted) setState(() => isSearching = false);
    }
  }
}
