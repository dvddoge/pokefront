import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;
import '../models/pokemon.dart';
import '../widgets/pokemon_net_image.dart';
import '../widgets/animated_counter.dart';
import '../widgets/banner_pattern_painter.dart';
import '../widgets/stat_comparison_bar.dart';

// Funções utilitárias globais
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

// Mapa de vantagens de tipo
final Map<String, List<String>> typeAdvantages = {
  'fire': ['grass', 'ice', 'bug', 'steel'],
  'water': ['fire', 'ground', 'rock'],
  'grass': ['water', 'ground', 'rock'],
  'electric': ['water', 'flying'],
  'psychic': ['fighting', 'poison'],
  'ice': ['grass', 'ground', 'flying', 'dragon'],
  'dragon': ['dragon'],
  'dark': ['psychic', 'ghost'],
  'fairy': ['fighting', 'dragon', 'dark'],
  'fighting': ['normal', 'ice', 'rock', 'dark', 'steel'],
  'flying': ['grass', 'fighting', 'bug'],
  'poison': ['grass', 'fairy'],
  'ground': ['fire', 'electric', 'poison', 'rock', 'steel'],
  'rock': ['fire', 'ice', 'flying', 'bug'],
  'bug': ['grass', 'psychic', 'dark'],
  'ghost': ['psychic', 'ghost'],
  'steel': ['ice', 'rock', 'fairy'],
  'normal': [],
};

class BattleParticle {
  Offset position;
  double size;
  double opacity;
  Color color;
  double velocity;
  double angle;

  BattleParticle({
    required this.position,
    required this.size,
    required this.opacity,
    required this.color,
    required this.velocity,
    required this.angle,
  });

  void update() {
    position = Offset(
      position.dx + math.cos(angle) * velocity,
      position.dy + math.sin(angle) * velocity,
    );
    opacity *= 0.95;
    size *= 0.95;
  }
}

class PokemonComparisonScreen extends StatefulWidget {
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
  _PokemonComparisonScreenState createState() => _PokemonComparisonScreenState();
}

class _PokemonComparisonScreenState extends State<PokemonComparisonScreen> with TickerProviderStateMixin {
  late AnimationController _battleAnimationController;
  late AnimationController _pokemon1AnimationController;
  late AnimationController _pokemon2AnimationController;
  late AnimationController _floatingAnimationController;
  late Animation<double> _pokemon1SlideAnimation;
  late Animation<double> _pokemon2SlideAnimation;
  late Animation<double> _pokemon1ScaleAnimation;
  late Animation<double> _pokemon2ScaleAnimation;
  late Animation<Offset> _pokemon1FloatingAnimation;
  late Animation<Offset> _pokemon2FloatingAnimation;
  final List<BattleParticle> _particles = [];
  bool _showTypeAdvantage = false;

  @override
  void initState() {
    super.initState();
    
    // Ajustar duração das animações existentes
    _floatingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 4000), // Aumentado para 4 segundos
      vsync: this,
    )..repeat(reverse: true);

    _pokemon1FloatingAnimation = Tween<Offset>(
      begin: const Offset(0, -6),
      end: const Offset(0, 6),
    ).animate(CurvedAnimation(
      parent: _floatingAnimationController,
      curve: Curves.easeInOut,
    ));

    _pokemon2FloatingAnimation = Tween<Offset>(
      begin: const Offset(0, 6),
      end: const Offset(0, -6),
    ).animate(CurvedAnimation(
      parent: _floatingAnimationController,
      curve: Curves.easeInOut,
    ));

    // Configurar animações de entrada dos Pokémon
    _pokemon1AnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Aumentado para 2 segundos
      vsync: this,
    );

    _pokemon2AnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _pokemon1SlideAnimation = Tween<double>(
      begin: -200.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pokemon1AnimationController,
      curve: Curves.elasticOut, // Curva elástica para entrada mais suave
    ));

    _pokemon2SlideAnimation = Tween<double>(
      begin: 200.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _pokemon2AnimationController,
      curve: Curves.elasticOut,
    ));

    _pokemon1ScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.1),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 60.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _pokemon1AnimationController,
      curve: Curves.easeOutCubic,
    ));

    _pokemon2ScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.8, end: 1.1),
        weight: 40.0,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 60.0,
      ),
    ]).animate(CurvedAnimation(
      parent: _pokemon2AnimationController,
      curve: Curves.easeOutCubic,
    ));

    // Configurar animação de batalha com duração mais longa
    _battleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();

    // Iniciar animações com timing ajustado
    Future.delayed(const Duration(milliseconds: 300), () {
      _pokemon1AnimationController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _pokemon2AnimationController.forward();
        Future.delayed(const Duration(milliseconds: 800), () {
          setState(() => _showTypeAdvantage = true);
        });
      });
    });
  }

  @override
  void dispose() {
    _battleAnimationController.dispose();
    _pokemon1AnimationController.dispose();
    _pokemon2AnimationController.dispose();
    _floatingAnimationController.dispose();
    super.dispose();
  }

  void _generateParticles() {
    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(
        BattleParticle(
          position: Offset(
            MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height * 0.3,
          ),
          size: random.nextDouble() * 10 + 5,
          opacity: 1.0,
          color: Color.lerp(
            getTypeColor(widget.pokemon1.types.first),
            getTypeColor(widget.pokemon2.types.first),
            random.nextDouble(),
          )!,
          velocity: random.nextDouble() * 8 + 2,
          angle: random.nextDouble() * 2 * math.pi,
        ),
      );
    }
  }

  void _updateParticles() {
    _particles.removeWhere((particle) => particle.opacity < 0.1);
    for (var particle in _particles) {
      particle.update();
    }
    setState(() {});
  }

  double _calculateTypeAdvantage(Pokemon attacker, Pokemon defender) {
    double advantage = 1.0;
    for (String attackerType in attacker.types) {
      for (String defenderType in defender.types) {
        if (typeAdvantages[attackerType]?.contains(defenderType) ?? false) {
          advantage *= 1.5;
        }
      }
    }
    return advantage;
  }

  Widget _buildPokemon(Pokemon pokemon, Animation<double> slideAnimation, 
      Animation<double> scaleAnimation, Animation<Offset> floatingAnimation, 
      double typeAdvantage, bool isLeft) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        slideAnimation, 
        scaleAnimation, 
        floatingAnimation,
      ]),
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(slideAnimation.value, 0),
          child: Transform.translate(
            offset: floatingAnimation.value,
            child: Transform.scale(
              scale: scaleAnimation.value,
              child: Transform.rotate(
                angle: math.sin((_floatingAnimationController.value * math.pi * 2)) * 0.03,
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Hero(
                          tag: 'pokemon-${pokemon.id}',
                          child: PokemonNetImage(imageUrl: pokemon.imageUrl, pokemonId: pokemon.id, height: 200, fit: BoxFit.contain),
                        ),
                        if (_showTypeAdvantage && typeAdvantage > 1.0)
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.elasticOut,
                            tween: Tween(begin: 0.0, end: 1.0),
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'Vantagem ${(typeAdvantage * 100 - 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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

    final totalStats1 = widget.stats1.values.reduce((a, b) => a + b);
    final totalStats2 = widget.stats2.values.reduce((a, b) => a + b);

    final typeAdvantage1 = _calculateTypeAdvantage(widget.pokemon1, widget.pokemon2);
    final typeAdvantage2 = _calculateTypeAdvantage(widget.pokemon2, widget.pokemon1);

    Color type1Color = getTypeColor(widget.pokemon1.types.first);
    Color type2Color = getTypeColor(widget.pokemon2.types.first);

    return Scaffold(
      backgroundColor: Colors.red.shade900,
      body: Stack(
        children: [
          // Fundo animado
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _battleAnimationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: BannerPatternPainter(
                    color: Colors.white.withOpacity(0.1),
                    progress: _battleAnimationController.value,
                    type: 'battle',
                  ),
                );
              },
            ),
          ),
          
          // Partículas de batalha
          if (_particles.isNotEmpty)
            CustomPaint(
              size: Size.infinite,
              painter: _BattleParticlesPainter(particles: _particles),
            ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // AppBar com título
                SliverAppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  pinned: true,
                  expandedHeight: 60,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      'Batalha Pokémon',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            color: Colors.black.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                    centerTitle: true,
                  ),
                ),
                
                // Arena de Batalha
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: Stack(
                      children: [
                        // VS Text Background
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // VS principal (grande)
                              Text(
                                'VS',
                                style: TextStyle(
                                  fontSize: 130,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white.withOpacity(0.15),
                                ),
                              ),
                              // Círculo branco com VS menor
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    'VS',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red[900],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // Pokémon 1
                        Positioned(
                          left: 40,
                          bottom: 20,
                          child: _buildPokemon(
                            widget.pokemon1,
                            _pokemon1SlideAnimation,
                            _pokemon1ScaleAnimation,
                            _pokemon1FloatingAnimation,
                            typeAdvantage1,
                            true,
                          ),
                        ),
                        
                        // Pokémon 2
                        Positioned(
                          right: 40,
                          bottom: 20,
                          child: _buildPokemon(
                            widget.pokemon2,
                            _pokemon2SlideAnimation,
                            _pokemon2ScaleAnimation,
                            _pokemon2FloatingAnimation,
                            typeAdvantage2,
                            false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Cards de Status
                SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              _buildTotalStatsCard(
                                pokemon1: widget.pokemon1,
                                pokemon2: widget.pokemon2,
                                totalStats1: totalStats1,
                                totalStats2: totalStats2,
                                typeAdvantage1: typeAdvantage1,
                                typeAdvantage2: typeAdvantage2,
                                type1Color: type1Color,
                                type2Color: type2Color,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailedStatsCard(
                                context: context,
                                statNames: statNames,
                                stats1: widget.stats1,
                                stats2: widget.stats2,
                                type1Color: type1Color,
                                type2Color: type2Color,
                              ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildTotalStatsCard({
    required Pokemon pokemon1,
    required Pokemon pokemon2,
    required int totalStats1,
    required int totalStats2,
    required double typeAdvantage1,
    required double typeAdvantage2,
    required Color type1Color,
    required Color type2Color,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [type1Color, type2Color],
              ).createShader(bounds),
              child: const Text(
                'PODER TOTAL',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalStats(
                  name: pokemon1.name,
                  total: totalStats1,
                  isHigher: totalStats1 >= totalStats2,
                  typeAdvantage: typeAdvantage1,
                  color: type1Color,
                ),
                Container(
                  width: 2,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [type1Color.withOpacity(0.3), type2Color.withOpacity(0.3)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
                _buildTotalStats(
                  name: pokemon2.name,
                  total: totalStats2,
                  isHigher: totalStats2 >= totalStats1,
                  typeAdvantage: typeAdvantage2,
                  color: type2Color,
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
    required Color type1Color,
    required Color type2Color,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
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
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [type1Color, type2Color],
              ).createShader(bounds),
              child: const Text(
                'COMPARAÇÃO DE STATUS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...statNames.entries.map((stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: StatComparisonBar(
                  statName: stat.value,
                  value1: stats1[stat.key] ?? 0,
                  value2: stats2[stat.key] ?? 0,
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalStats({
    required String name,
    required int total,
    required bool isHigher,
    required double typeAdvantage,
    required Color color,
  }) {
    final effectiveTotal = (total * typeAdvantage).round();
    final textColor = isHigher ? Colors.green : Colors.red[700];
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 1500),
              tween: Tween(begin: 0, end: 1),
              builder: (context, value, child) {
                return Text(
                  (effectiveTotal * value).toInt().toString(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    shadows: const [
                      Shadow(
                        color: Colors.black12,
                        offset: Offset(2, 2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              },
            ),
            if (typeAdvantage > 1.0)
              Positioned(
                right: -8,
                top: -8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Text(
                    '↑',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }
}

class _BattleParticlesPainter extends CustomPainter {
  final List<BattleParticle> particles;

  _BattleParticlesPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(particle.position, particle.size, paint);
    }
  }

  @override
  bool shouldRepaint(_BattleParticlesPainter oldDelegate) => true;
}

class BannerPatternPainter extends CustomPainter {
  final Color color;
  final double progress;
  final String type;

  BannerPatternPainter({
    required this.color,
    required this.progress,
    required this.type,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final maxRadius = math.min(size.width, size.height) * 0.6;

    // Desenha 3 círculos concêntricos com animação suave
    for (int i = 0; i < 3; i++) {
      final phase = progress * 2 * math.pi;
      final wave = math.sin(phase) * 15;
      final baseRadius = maxRadius * (0.4 + i * 0.25);
      final radius = baseRadius + wave;
      
      canvas.drawCircle(
        Offset(centerX, centerY),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(BannerPatternPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.color != color ||
           oldDelegate.type != type;
  }
}

class SineCurve extends Curve {
  @override
  double transformInternal(double t) {
    return (math.sin(2 * math.pi * t) + 1) / 2;
  }
}
     