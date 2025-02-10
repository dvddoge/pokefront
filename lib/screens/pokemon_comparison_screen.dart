import 'package:flutter/material.dart';
import '../models/pokemon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/animated_counter.dart';
import '../widgets/banner_pattern_painter.dart';
import '../widgets/stat_comparison_bar.dart';

// Funções utilitárias globais
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
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red.shade800,
              Colors.red.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Barra superior com botão de voltar e título
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
              
              Expanded(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _BattleArenaDelegate(
                        pokemon1: pokemon1,
                        pokemon2: pokemon2,
                        maxHeight: 320,
                        minHeight: 200,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        children: [
                          // Status Total Card
                          Padding(
                            padding: EdgeInsets.all(16),
                            child: _buildTotalStatsCard(
                              pokemon1: pokemon1,
                              pokemon2: pokemon2,
                              totalStats1: totalStats1,
                              totalStats2: totalStats2,
                            ),
                          ),
                          // Comparação detalhada
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: _buildDetailedStatsCard(
                              context: context,
                              statNames: statNames,
                              stats1: stats1,
                              stats2: stats2,
                            ),
                          ),
                          SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background pattern
          Opacity(
            opacity: fadeAnimation,
            child: CustomPaint(
              painter: BannerPatternPainter(
                color: Colors.white.withOpacity(0.1),
                progress: DateTime.now().millisecondsSinceEpoch / 1000,
                type: 'battle',
              ),
            ),
          ),
          
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Pokemon 1
                Transform.translate(
                  offset: Offset(-shrinkOffset * 0.3, shrinkOffset * 0.2),
                  child: Transform.scale(
                    scale: 1 - (progress * 0.3),
                    child: _buildPokemonDisplay(
                      pokemon: pokemon1,
                      fadeAnimation: fadeAnimation,
                      isLeft: true,
                    ),
                  ),
                ),

                // VS Symbol
                Transform.translate(
                  offset: Offset(0, 40),
                  child: Transform.scale(
                    scale: 1 - (progress * 0.5),
                    child: Opacity(
                      opacity: fadeAnimation,
                      child: Container(
                        padding: EdgeInsets.all(16 * (1 - progress)),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3 * fadeAnimation),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Text(
                          'VS',
                          style: TextStyle(
                            fontSize: 24 * (1 - progress * 0.3),
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Pokemon 2
                Transform.translate(
                  offset: Offset(shrinkOffset * 0.3, shrinkOffset * 0.2),
                  child: Transform.scale(
                    scale: 1 - (progress * 0.3),
                    child: _buildPokemonDisplay(
                      pokemon: pokemon2,
                      fadeAnimation: fadeAnimation,
                      isLeft: false,
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

  Widget _buildPokemonDisplay({
    required Pokemon pokemon,
    required double fadeAnimation,
    required bool isLeft,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Hero(
          tag: 'compare-${pokemon.id}',
          child: Transform.scale(
            scaleX: isLeft ? 1 : -1,
            child: SizedBox(
              height: 180,
              width: 180,
              child: CachedNetworkImage(
                imageUrl: pokemon.imageUrl,
                fadeInDuration: Duration.zero,
                placeholderFadeInDuration: Duration.zero,
                placeholder: (context, url) => Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                errorWidget: (context, url, error) => Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        Opacity(
          opacity: fadeAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  pokemon.name.toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
                if (fadeAnimation > 0.5) ...[
                  SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: pokemon.types.map((type) =>
                      buildTypeChip(type, getTypeColor(type))
                    ).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  double get maxExtent => maxHeight;

  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant _BattleArenaDelegate oldDelegate) {
    return pokemon1 != oldDelegate.pokemon1 || 
           pokemon2 != oldDelegate.pokemon2 ||
           maxHeight != oldDelegate.maxHeight ||
           minHeight != oldDelegate.minHeight;
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
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: isHigher ? Colors.green : Colors.red.shade900,
            ),
          );
        },
      ),
      SizedBox(height: 8),
      Text(
        name.toUpperCase(),
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
      if (isHigher)
        Icon(
          Icons.arrow_upward,
          color: Colors.green,
          size: 20,
        ),
    ],
  );
}
