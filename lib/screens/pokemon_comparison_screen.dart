import 'package:flutter/material.dart';
import '../models/pokemon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/animated_counter.dart';
import '../widgets/banner_pattern_painter.dart';

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

  Widget _buildStatComparison(BuildContext context, String statName, int value1, int value2) {
    final difference = value1 - value2;
    final better = difference > 0 ? 1 : (difference < 0 ? 2 : 0);
    final maxValue = 255.0; // Valor máximo possível para stats
    final percentage1 = value1 / maxValue;
    final percentage2 = value2 / maxValue;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  statName,
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              // Barra de progresso do primeiro Pokémon
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        color: Colors.grey[200],
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 800),
                        height: 24,
                        width: MediaQuery.of(context).size.width * 0.4 * percentage1,
                        decoration: BoxDecoration(
                          color: better == 1 ? Colors.green : (better == 0 ? Colors.blue : Colors.red),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: AnimatedCounter(
                          value: value1,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 8),
              // Barra de progresso do segundo Pokémon
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Stack(
                    children: [
                      Container(
                        height: 24,
                        color: Colors.grey[200],
                      ),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 800),
                        height: 24,
                        width: MediaQuery.of(context).size.width * 0.4 * percentage2,
                        decoration: BoxDecoration(
                          color: better == 2 ? Colors.green : (better == 0 ? Colors.blue : Colors.red),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      Center(
                        child: AnimatedCounter(
                          value: value2,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black26,
                                blurRadius: 2,
                                offset: Offset(1, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, Color color) {
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

  Color _getTypeColor(String type) {
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
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Arena de batalha com os Pokémon
                      Container(
                        height: 320,
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
                        child: CustomPaint(
                          painter: BannerPatternPainter(
                            color: Colors.white.withOpacity(0.1),
                            progress: DateTime.now().millisecondsSinceEpoch / 1000,
                            type: 'battle',
                          ),
                          child: Stack(
                            children: [
                              // Pokémon 1 (Esquerda)
                              Positioned(
                                left: 20,
                                bottom: 20,
                                child: Column(
                                  children: [
                                    Hero(
                                      tag: 'compare-${pokemon1.id}',
                                      child: TweenAnimationBuilder<double>(
                                        duration: Duration(milliseconds: 800),
                                        tween: Tween(begin: -100.0, end: 0.0),
                                        builder: (context, value, child) {
                                          return Transform.translate(
                                            offset: Offset(value, 0),
                                            child: CachedNetworkImage(
                                              imageUrl: pokemon1.imageUrl,
                                              height: 180,
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            pokemon1.name.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            children: pokemon1.types.map((type) =>
                                              _buildTypeChip(type, _getTypeColor(type))
                                            ).toList(),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              // VS no centro
                              Center(
                                child: TweenAnimationBuilder<double>(
                                  duration: Duration(milliseconds: 1000),
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  builder: (context, value, child) {
                                    return Transform.scale(
                                      scale: value,
                                      child: Container(
                                        padding: EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.3),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          'VS',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red.shade900,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Pokémon 2 (Direita)
                              Positioned(
                                right: 20,
                                bottom: 20,
                                child: Column(
                                  children: [
                                    Hero(
                                      tag: 'compare-${pokemon2.id}',
                                      child: TweenAnimationBuilder<double>(
                                        duration: Duration(milliseconds: 800),
                                        tween: Tween(begin: 100.0, end: 0.0),
                                        builder: (context, value, child) {
                                          return Transform.translate(
                                            offset: Offset(value, 0),
                                            child: Transform.scale(
                                              scaleX: -1, // Espelha a imagem horizontalmente
                                              child: CachedNetworkImage(
                                                imageUrl: pokemon2.imageUrl,
                                                height: 180,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            pokemon2.name.toUpperCase(),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red.shade900,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Wrap(
                                            spacing: 4,
                                            children: pokemon2.types.map((type) =>
                                              _buildTypeChip(type, _getTypeColor(type))
                                            ).toList(),
                                          ),
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

                      // Status Total Card
                      Padding(
                        padding: EdgeInsets.all(16),
                        child: Card(
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
                        ),
                      ),

                      // Comparação detalhada de status
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
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
                                  return _buildStatComparison(
                                    context,
                                    stat.value,
                                    stats1[stat.key] ?? 0,
                                    stats2[stat.key] ?? 0,
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
}
