import 'package:flutter/material.dart';
import '../models/pokemon.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/animated_counter.dart';

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
      appBar: AppBar(
        title: Text('Comparação de Pokémon'),
        centerTitle: true,
        backgroundColor: Colors.red,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'compare-${pokemon1.id}',
                          child: CachedNetworkImage(
                            imageUrl: pokemon1.imageUrl,
                            height: 120,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          pokemon1.name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Wrap(
                          spacing: 4,
                          children: pokemon1.types.map((type) => 
                            _buildTypeChip(type, _getTypeColor(type))
                          ).toList(),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'VS',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Hero(
                          tag: 'compare-${pokemon2.id}',
                          child: CachedNetworkImage(
                            imageUrl: pokemon2.imageUrl,
                            height: 120,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          pokemon2.name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
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
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Status Total',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Column(
                                children: [
                                  AnimatedCounter(
                                    value: totalStats1,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: totalStats1 > totalStats2 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  Text(pokemon1.name.toUpperCase()),
                                ],
                              ),
                              Column(
                                children: [
                                  AnimatedCounter(
                                    value: totalStats2,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: totalStats2 > totalStats1 ? Colors.green : Colors.red,
                                    ),
                                  ),
                                  Text(pokemon2.name.toUpperCase()),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 16),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            'Comparação Detalhada',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: 16),
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
