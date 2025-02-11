import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../widgets/animated_counter.dart';
import '../widgets/banner_pattern_painter.dart';
import '../models/pokemon.dart';
import '../widgets/stat_comparison_bar.dart';

class PokemonDetailScreen extends StatefulWidget {
  final int pokemonId;
  final String pokemonName;

  const PokemonDetailScreen({
    Key? key,
    required this.pokemonId,
    required this.pokemonName,
  }) : super(key: key);

  @override
  _PokemonDetailScreenState createState() => _PokemonDetailScreenState();
}

class _PokemonDetailScreenState extends State<PokemonDetailScreen> with SingleTickerProviderStateMixin {
  late Future<Map<String, dynamic>> _pokemonDetailFuture;
  late AnimationController _bannerAnimationController;
  late Animation<double> _floatingAnimation;
  GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _pokemonDetailFuture = fetchPokemonDetail(widget.pokemonId);
    
    _bannerAnimationController = AnimationController(
      duration: Duration(milliseconds: 4000), // Aumentando a duração para ser mais suave
      vsync: this,
    );

    _bannerAnimationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _bannerAnimationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _bannerAnimationController.forward();
      }
    });

    _floatingAnimation = CurvedAnimation(
      parent: _bannerAnimationController,
      curve: Curves.easeInOut,
    ).drive(Tween<double>(
      begin: -10.0,
      end: 10.0,
    ));

    _bannerAnimationController.forward();
  }

  @override
  void dispose() {
    _bannerAnimationController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> fetchPokemonDetail(int id) async {
    final responsePokemon = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'),
    );
    if (responsePokemon.statusCode != 200) {
      throw Exception('Erro ao carregar detalhes do Pokémon');
    }
    final pokemonData = json.decode(responsePokemon.body) as Map<String, dynamic>;

    final responseSpecies = await http.get(
      Uri.parse('https://pokeapi.co/api/v2/pokemon-species/$id'),
    );
    if (responseSpecies.statusCode != 200) {
      throw Exception('Erro ao carregar dados da espécie');
    }
    final speciesData = json.decode(responseSpecies.body) as Map<String, dynamic>;
    final evolutionChainUrl = speciesData['evolution_chain']?['url'];

    Map<String, dynamic> evolutionData = {};
    if (evolutionChainUrl != null) {
      final responseEvolution = await http.get(Uri.parse(evolutionChainUrl));
      if (responseEvolution.statusCode == 200) {
        evolutionData = json.decode(responseEvolution.body) as Map<String, dynamic>;
      }
    }

    return {
      'pokemon': pokemonData,
      'species': speciesData,
      'evolution': evolutionData,
    };
  }

  List<Map<String, dynamic>> parseEvolutionChain(Map<String, dynamic> evolutionData) {
    List<Map<String, dynamic>> chain = [];
    if (evolutionData.isEmpty) return chain;
    
    void addToChain(Map<String, dynamic> current) {
      if (current['species'] != null) {
        final species = Map<String, dynamic>.from(current['species'] as Map<String, dynamic>);
        chain.add(species);
      }
      
      if (current['evolves_to'] != null && 
          (current['evolves_to'] as List).isNotEmpty) {
        final nextEvolution = Map<String, dynamic>.from(current['evolves_to'][0] as Map<String, dynamic>);
        addToChain(nextEvolution);
      }
    }

    if (evolutionData['chain'] != null) {
      final chainData = Map<String, dynamic>.from(evolutionData['chain'] as Map<String, dynamic>);
      addToChain(chainData);
    }

    return chain;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _bannerAnimationController.stop();
        Navigator.of(context).pop();
        return false;
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.grey[100],
        body: FutureBuilder<Map<String, dynamic>>(
          future: _pokemonDetailFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      'Carregando detalhes...',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16.0),
                    Text(
                      'Erro ao carregar detalhes',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final details = Map<String, dynamic>.from(snapshot.data!);
            final pokemonData = Map<String, dynamic>.from(details['pokemon'] as Map<String, dynamic>);
            final weight = (pokemonData['weight'] as int) / 10.0;
            final height = (pokemonData['height'] as int) / 10.0;
            final types = (pokemonData['types'] as List)
                .map((t) => ((t as Map<String, dynamic>)['type']['name'] as String))
                .toList();
            final abilities = (pokemonData['abilities'] as List)
                .map((a) => ((a as Map<String, dynamic>)['ability']['name'] as String))
                .toList();
            final stats = Map<String, int>.fromEntries(
              (pokemonData['stats'] as List).map(
                (s) => MapEntry(
                  (s['stat']['name'] as String),
                  (s['base_stat'] as int),
                ),
              ),
            );

            List<Map<String, dynamic>> evolutionChain = [];
            if (details['evolution'] != null && 
                (details['evolution'] as Map<String, dynamic>).isNotEmpty) {
              evolutionChain = parseEvolutionChain(
                details['evolution'] as Map<String, dynamic>
              );
            }

            Color typeColor = getTypeColor(types.first);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 300,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  backgroundColor: typeColor,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [
                      StretchMode.zoomBackground,
                      StretchMode.blurBackground,
                    ],
                    title: Text(
                      widget.pokemonName.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        AnimatedBuilder(
                          animation: _bannerAnimationController,
                          builder: (context, child) {
                            return Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    typeColor,
                                    typeColor.withOpacity(0.7),
                                  ],
                                ),
                              ),
                              child: CustomPaint(
                                painter: BannerPatternPainter(
                                  color: Colors.white.withOpacity(0.1),
                                  progress: _bannerAnimationController.value,
                                  type: types.first,
                                ),
                              ),
                            );
                          },
                        ),
                        Center(
                          child: AnimatedBuilder(
                            animation: _floatingAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset: Offset(0, _floatingAnimation.value),
                                child: Hero(
                                  tag: 'pokemon-${widget.pokemonId}',
                                  child: CachedNetworkImage(
                                    imageUrl: pokemonData['sprites']['other']['official-artwork']['front_default'] ?? 
                                        'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/${widget.pokemonId}.png',
                                    height: 200,
                                    fit: BoxFit.contain,
                                    placeholder: (context, url) => Shimmer.fromColors(
                                      baseColor: Colors.grey[300]!,
                                      highlightColor: Colors.grey[100]!,
                                      child: Container(color: Colors.white),
                                    ),
                                    errorWidget: (context, url, error) => Icon(Icons.error),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Types
                        Wrap(
                          spacing: 8.0,
                          children: types.map((type) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            decoration: BoxDecoration(
                              color: getTypeColor(type),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: getTypeColor(type).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )).toList(),
                        ),
                        const SizedBox(height: 24.0),
                        
                        // Basic Info Card
                        Card(
                          elevation: 8,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [Colors.white, Colors.grey.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Informações',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: typeColor,
                                  ),
                                ),
                                SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildInfoItem('Altura', height.toStringAsFixed(1) + 'm'),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    _buildInfoItem('Peso', weight.toStringAsFixed(1) + 'kg'),
                                    Container(
                                      width: 1,
                                      height: 40,
                                      color: Colors.grey.withOpacity(0.3),
                                    ),
                                    _buildInfoItem('ID', '#${pokemonData["id"].toString().padLeft(3, "0")}'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24.0),

                        // Stats
                        Text(
                          'Estatísticas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        ..._buildStats(stats, typeColor),
                        const SizedBox(height: 24.0),

                        // Abilities
                        Text(
                          'Habilidades',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        _buildAbilities(abilities, typeColor),
                        const SizedBox(height: 24.0),

                        // Evolution Chain
                        _buildEvolutionChain(evolutionChain, typeColor),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 500),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animValue)),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildStats(Map<String, dynamic> stats, Color typeColor) {
    final statNames = {
      'hp': 'HP',
      'attack': 'Ataque',
      'defense': 'Defesa',
      'special-attack': 'Atq. Especial',
      'special-defense': 'Def. Especial',
      'speed': 'Velocidade',
    };

    return stats.entries.map((stat) {
      final percentage = (stat.value as int) / 255.0;
      return TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 1000),
        tween: Tween<double>(begin: 0, end: percentage),
        builder: (context, double animValue, child) {
          return Container(
            padding: EdgeInsets.all(8),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: typeColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      statNames[stat.key] ?? stat.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    AnimatedCounter(
                      value: (stat.value * animValue).toInt(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return AnimatedContainer(
                          duration: Duration(milliseconds: 500),
                          height: 8,
                          width: constraints.maxWidth * animValue,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                typeColor.withOpacity(0.7),
                                typeColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: typeColor.withOpacity(0.2),
                                blurRadius: 4,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    }).toList();
  }

  Widget _buildAbilities(List<String> abilities, Color typeColor) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: abilities.map((ability) => MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: typeColor.withOpacity(0.2),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            ability.replaceAll('-', ' ').toUpperCase(),
            style: TextStyle(
              color: typeColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildEvolutionChain(List<Map<String, dynamic>> evolutionChain, Color typeColor) {
    if (evolutionChain.isEmpty) return SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Evolução',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          height: 150,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: evolutionChain.length,
            itemBuilder: (context, index) {
              final evo = evolutionChain[index];
              final evoUrl = evo['url'];
              final regExp = RegExp(r'/pokemon-species/(\d+)/');
              final match = regExp.firstMatch(evoUrl);
              int evoId = match != null ? int.parse(match.group(1)!) : 0;
              final imageUrl = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/$evoId.png';
              
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: GestureDetector(
                    onTap: () {
                      if (evoId != widget.pokemonId) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PokemonDetailScreen(
                              pokemonId: evoId,
                              pokemonName: evo['name'],
                            ),
                          ),
                        );
                      }
                    },
                    child: TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 200),
                      tween: Tween<double>(begin: 1, end: evoId == widget.pokemonId ? 1.1 : 1.0),
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 200),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: evoId == widget.pokemonId 
                                  ? typeColor.withOpacity(0.2) 
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: typeColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  height: 100,
                                  placeholder: (context, url) => Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(color: Colors.white),
                                  ),
                                  errorWidget: (context, url, error) => Icon(Icons.error),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  evo['name'].toString().toUpperCase(),
                                  style: TextStyle(
                                    color: typeColor,
                                    fontWeight: evoId == widget.pokemonId 
                                        ? FontWeight.bold 
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
}

Widget buildTypeChip(String type, Color color) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.4),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Text(
      type.toUpperCase(),
      style: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

Widget buildStatComparison(BuildContext context, String statName, int value1, int value2) {
  return StatComparisonBar(
    statName: statName,
    value1: value1,
    value2: value2,
  );
}

class PokemonComparisonScreen extends StatelessWidget {
  final Pokemon pokemon1;
  final Pokemon pokemon2;
  final Map<String, int> stats1;
  final Map<String, int> stats2;

  const PokemonComparisonScreen({
    Key? key,
    required this.pokemon1,
    required this.pokemon2,
    required this.stats1,
    required this.stats2,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final statNames = {
      'hp': 'HP',
      'attack': 'Ataque',
      'defense': 'Defesa',
      'special-attack': 'Atq. Especial',
      'special-defense': 'Def. Especial',
      'speed': 'Velocidade',
    };

    final totalStats1 = stats1.values.reduce((a, b) => a + b);
    final totalStats2 = stats2.values.reduce((a, b) => a + b);

    return Scaffold(
      backgroundColor: Colors.red.shade900,
      extendBody: true,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Barra superior com botão de voltar e título
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'BATALHA POKÉMON',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 48), // Para balancear o layout
                ],
              ),
            ),
          ),
          // Header animado (arena da batalha)
          SliverPersistentHeader(
            pinned: true,
            delegate: _BattleArenaDelegate(
              pokemon1: pokemon1,
              pokemon2: pokemon2,
              maxHeight: 320,
              minHeight: 120, // Altura mínima para melhor scroll
            ),
          ),
          // Conteúdo da comparação (stats)
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 32,
              left: 16,
              right: 16,
              top: 16,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildTotalStatsCard(
                    pokemon1: pokemon1,
                    pokemon2: pokemon2,
                    totalStats1: totalStats1,
                    totalStats2: totalStats2,
                  ),
                  SizedBox(height: 16),
                  _buildDetailedStatsCard(
                    context: context,
                    statNames: statNames,
                    stats1: stats1,
                    stats2: stats2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BattleArenaDelegate extends SliverPersistentHeaderDelegate {
  final Pokemon pokemon1;
  final Pokemon pokemon2;
  final double maxHeight;
  final double minHeight;

  _BattleArenaDelegate({
    required this.pokemon1,
    required this.pokemon2,
    required this.maxHeight,
    required this.minHeight,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final progress = shrinkOffset / (maxExtent - minExtent);
    final fadeAnimation = (1 - progress).clamp(0.0, 1.0);
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;
    final time = DateTime.now().millisecondsSinceEpoch / 4000.0;

    return Container(
      height: maxHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade900,
            Colors.red.shade800,
            Colors.orange.shade900,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background animado
          Opacity(
            opacity: fadeAnimation,
            child: CustomPaint(
              painter: BannerPatternPainter(
                color: Colors.white.withOpacity(0.15),
                progress: time % 1,
                type: 'battle',
              ),
            ),
          ),
          // Texto VS animado
          if (fadeAnimation > 0.3)
            Center(
              child: TweenAnimationBuilder<double>(
                duration: Duration(milliseconds: 1500),
                curve: Curves.easeInOut,
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 120,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  );
                },
              ),
            ),
          // Outras informações podem ser adicionadas aqui
        ],
      ),
    );
  }

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;
  @override
  bool shouldRebuild(covariant _BattleArenaDelegate oldDelegate) {
    return oldDelegate.maxHeight != maxHeight || oldDelegate.minHeight != minHeight;
  }
}

Widget _buildTotalStatsCard({
  required Pokemon pokemon1,
  required Pokemon pokemon2,
  required int totalStats1,
  required int totalStats2,
}) {
  return Card(
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'PODER TOTAL',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade900,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTotalStats(
                pokemon1.name,
                totalStats1,
                totalStats1 >= totalStats2,
              ),
              Container(
                width: 2,
                height: 50,
                color: Colors.grey.shade300,
              ),
              _buildTotalStats(
                pokemon2.name,
                totalStats2,
                totalStats2 >= totalStats1,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildDetailedStatsCard({
  required BuildContext context,
  required Map<String, String> statNames,
  required Map<String, int> stats1,
  required Map<String, int> stats2,
}) {
  return Card(
    elevation: 8,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.white, Colors.grey.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Text(
            'COMPARAÇÃO DE STATUS',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade900,
            ),
          ),
          SizedBox(height: 24),
          ...statNames.entries.map((stat) {
            return buildStatComparison(
              context,
              stat.value,
              stats1[stat.key] ?? 0,
              stats2[stat.key] ?? 0,
            );
          }).toList(),
        ],
      ),
    ),
  );
}

Widget _buildTotalStats(String name, int total, bool isHigher) {
  return Column(
    children: [
      TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 1500),
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          return AnimatedCounter(
            value: (total * value).toInt(),
          );
        },
      ),
      SizedBox(height: 8),
      Text(
        name.toUpperCase(),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.red.shade900,
        ),
      ),
    ],
  );
}