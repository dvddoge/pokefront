import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pokemon.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PokemonBattleScreen extends StatefulWidget {
  final Pokemon pokemon1;
  final Pokemon pokemon2;

  const PokemonBattleScreen({
    Key? key,
    required this.pokemon1,
    required this.pokemon2,
  }) : super(key: key);

  @override
  _PokemonBattleScreenState createState() => _PokemonBattleScreenState();
}

class _PokemonBattleScreenState extends State<PokemonBattleScreen> with TickerProviderStateMixin {
  late AnimationController _battleAnimationController;
  late AnimationController _shakeAnimationController;
  late AnimationController _damageAnimationController;
  
  late double pokemon1MaxHP;
  late double pokemon2MaxHP;
  late double pokemon1HP;
  late double pokemon2HP;
  String battleLog = '';
  bool isPlayer1Turn = true;
  bool isAnimating = false;
  bool isLoading = true;
  List<PokemonMove> pokemon1Moves = [];
  List<PokemonMove> pokemon2Moves = [];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadPokemonData();
  }

  void _setupAnimations() {
    _battleAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _shakeAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 300),
    );

    _damageAnimationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _battleAnimationController.dispose();
    _shakeAnimationController.dispose();
    _damageAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadPokemonData() async {
    try {
      // Carrega dados do Pokémon 1
      final response1 = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon1.id}'),
      );
      
      if (response1.statusCode == 200) {
        final data1 = json.decode(response1.body);
        final stats1 = data1['stats'] as List;
        pokemon1MaxHP = (stats1.firstWhere((stat) => stat['stat']['name'] == 'hp')['base_stat'] as int).toDouble();
        pokemon1HP = pokemon1MaxHP;

        final moves1 = (data1['moves'] as List).take(4).map((m) async {
          final moveUrl = m['move']['url'] as String;
          final moveResponse = await http.get(Uri.parse(moveUrl));
          if (moveResponse.statusCode == 200) {
            final moveData = json.decode(moveResponse.body);
            return PokemonMove(
              name: moveData['name'].toString().replaceAll('-', ' '),
              damage: (moveData['power'] ?? 50).toDouble(),
              type: moveData['type']['name'],
              accuracy: (moveData['accuracy'] ?? 90).toDouble(),
            );
          }
          return null;
        }).toList();

        pokemon1Moves = (await Future.wait(moves1))
            .where((move) => move != null)
            .cast<PokemonMove>()
            .toList();

        if (pokemon1Moves.isEmpty) {
          pokemon1Moves = _getDefaultMoves();
        }
      }

      // Carrega dados do Pokémon 2
      final response2 = await http.get(
        Uri.parse('https://pokeapi.co/api/v2/pokemon/${widget.pokemon2.id}'),
      );
      
      if (response2.statusCode == 200) {
        final data2 = json.decode(response2.body);
        final stats2 = data2['stats'] as List;
        pokemon2MaxHP = (stats2.firstWhere((stat) => stat['stat']['name'] == 'hp')['base_stat'] as int).toDouble();
        pokemon2HP = pokemon2MaxHP;

        final moves2 = (data2['moves'] as List).take(4).map((m) async {
          final moveUrl = m['move']['url'] as String;
          final moveResponse = await http.get(Uri.parse(moveUrl));
          if (moveResponse.statusCode == 200) {
            final moveData = json.decode(moveResponse.body);
            return PokemonMove(
              name: moveData['name'].toString().replaceAll('-', ' '),
              damage: (moveData['power'] ?? 50).toDouble(),
              type: moveData['type']['name'],
              accuracy: (moveData['accuracy'] ?? 90).toDouble(),
            );
          }
          return null;
        }).toList();

        pokemon2Moves = (await Future.wait(moves2))
            .where((move) => move != null)
            .cast<PokemonMove>()
            .toList();

        if (pokemon2Moves.isEmpty) {
          pokemon2Moves = _getDefaultMoves();
        }
      }

      setState(() => isLoading = false);
    } catch (e) {
      print('Erro ao carregar dados: $e');
      // Em caso de erro, usa valores padrão
      setState(() {
        pokemon1MaxHP = 100;
        pokemon2MaxHP = 100;
        pokemon1HP = 100;
        pokemon2HP = 100;
        pokemon1Moves = _getDefaultMoves();
        pokemon2Moves = _getDefaultMoves();
        isLoading = false;
      });
    }
  }

  List<PokemonMove> _getDefaultMoves() {
    return [
      PokemonMove(
        name: 'Ataque Rápido',
        damage: 20,
        type: 'normal',
        accuracy: 95,
      ),
      PokemonMove(
        name: 'Investida',
        damage: 25,
        type: 'normal',
        accuracy: 90,
      ),
      PokemonMove(
        name: 'Ataque Especial',
        damage: 35,
        type: 'special',
        accuracy: 80,
      ),
      PokemonMove(
        name: 'Golpe Final',
        damage: 45,
        type: 'special',
        accuracy: 70,
      ),
    ];
  }

  Future<void> _executeMove(PokemonMove move) async {
    if (isAnimating) return;

    setState(() {
      isAnimating = true;
      battleLog = '${isPlayer1Turn ? widget.pokemon1.name : widget.pokemon2.name} usa ${move.name}!';
    });

    // Calcula se o ataque acertou baseado na accuracy
    bool hitSuccess = math.Random().nextDouble() * 100 <= move.accuracy;

    if (!hitSuccess) {
      setState(() {
        battleLog = 'O ataque de ${isPlayer1Turn ? widget.pokemon1.name : widget.pokemon2.name} errou!';
        isAnimating = false;
        isPlayer1Turn = !isPlayer1Turn;
      });
      
      if (!isPlayer1Turn) {
        await Future.delayed(Duration(milliseconds: 1000));
        await _executeAIMove();
      }
      return;
    }

    // Animação de ataque
    await _battleAnimationController.forward();
    await _battleAnimationController.reverse();

    // Animação de dano
    await _shakeAnimationController.forward();
    await _shakeAnimationController.reverse();

    // Calcula e aplica o dano
    double damage = move.damage;
    setState(() {
      if (isPlayer1Turn) {
        pokemon2HP = math.max(0, pokemon2HP - damage);
        battleLog = '${widget.pokemon1.name} causou ${damage.toInt()} de dano! (${pokemon2HP.toInt()}/${pokemon2MaxHP.toInt()} HP)';
      } else {
        pokemon1HP = math.max(0, pokemon1HP - damage);
        battleLog = '${widget.pokemon2.name} causou ${damage.toInt()} de dano! (${pokemon1HP.toInt()}/${pokemon1MaxHP.toInt()} HP)';
      }
    });

    await _damageAnimationController.forward();
    await _damageAnimationController.reverse();

    // Verifica se a batalha acabou
    if (pokemon1HP <= 0 || pokemon2HP <= 0) {
      setState(() {
        battleLog = '${pokemon1HP <= 0 ? widget.pokemon2.name : widget.pokemon1.name} venceu a batalha!';
      });
      _showBattleEndDialog();
    } else {
      setState(() {
        isAnimating = false;
        isPlayer1Turn = !isPlayer1Turn;
      });

      if (!isPlayer1Turn) {
        await Future.delayed(Duration(milliseconds: 1000));
        await _executeAIMove();
      }
    }
  }

  Future<void> _executeAIMove() async {
    if (pokemon1HP <= 0 || pokemon2HP <= 0) return;

    // Lógica de IA melhorada para escolher o movimento
    PokemonMove selectedMove;
    
    if (pokemon2HP <= 20) {
      // Se o HP do oponente estiver baixo, prioriza ataques mais fortes
      selectedMove = pokemon2Moves.reduce((a, b) => a.damage > b.damage ? a : b);
    } else if (pokemon1HP <= 35) {
      // Se o jogador estiver com pouco HP, tenta finalizar com um ataque forte
      var forteMoves = pokemon2Moves.where((move) => move.damage >= 35).toList();
      selectedMove = forteMoves.isEmpty 
          ? pokemon2Moves[math.Random().nextInt(pokemon2Moves.length)]
          : forteMoves[math.Random().nextInt(forteMoves.length)];
    } else if (pokemon2HP >= 70) {
      // Se estiver com bastante HP, usa ataques mais precisos
      var preciseMoves = pokemon2Moves.where((move) => move.accuracy >= 90).toList();
      selectedMove = preciseMoves.isEmpty
          ? pokemon2Moves[math.Random().nextInt(pokemon2Moves.length)]
          : preciseMoves[math.Random().nextInt(preciseMoves.length)];
    } else {
      // Caso contrário, escolhe um movimento aleatório
      selectedMove = pokemon2Moves[math.Random().nextInt(pokemon2Moves.length)];
    }

    await _executeMove(selectedMove);
  }

  void _showBattleEndDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Batalha Finalizada!'),
        content: Text('${pokemon1HP <= 0 ? widget.pokemon2.name : widget.pokemon1.name} é o vencedor!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Fecha o diálogo
              Navigator.of(context).pop(); // Volta para a tela anterior
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildPokemonInfo(Pokemon pokemon, double hp, double maxHp, bool isLeft) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: isLeft ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pokemon.name.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(width: 8),
              Text(
                '${hp.toInt()}/${maxHp.toInt()} HP',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Container(
            width: 200,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: LinearProgressIndicator(
                    value: hp / maxHp,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      hp / maxHp > 0.5 ? Colors.green :
                      hp / maxHp > 0.2 ? Colors.orange : Colors.red,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${(hp / maxHp * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
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

  IconData getTypeIcon(String type) {
    final icons = {
      'fire': Icons.local_fire_department,
      'water': Icons.water_drop,
      'grass': Icons.grass,
      'electric': Icons.bolt,
      'psychic': Icons.psychology,
      'ice': Icons.ac_unit,
      'dragon': Icons.auto_awesome,
      'dark': Icons.nights_stay,
      'fairy': Icons.star,
      'fighting': Icons.sports_kabaddi,
      'flying': Icons.air,
      'poison': Icons.science,
      'ground': Icons.landscape,
      'rock': Icons.terrain,
      'bug': Icons.bug_report,
      'ghost': Icons.blur_on,
      'steel': Icons.shield,
      'normal': Icons.circle_outlined,
    };
    return icons[type.toLowerCase()] ?? Icons.help_outline;
  }

  Widget _buildMoveButton(PokemonMove move) {
    final Color typeColor = getTypeColor(move.type);
    final IconData typeIcon = getTypeIcon(move.type);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: 'Dano: ${move.damage.toInt()} | Precisão: ${move.accuracy.toInt()}%',
        child: ElevatedButton(
          onPressed: isAnimating || !isPlayer1Turn ? null : () => _executeMove(move),
          style: ElevatedButton.styleFrom(
            backgroundColor: typeColor,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    move.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    'Dano: ${move.damage.toInt()}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              SizedBox(width: 6),
              Icon(
                typeIcon,
                color: Colors.white,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[100],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red[700]!),
              ),
              SizedBox(height: 16),
              Text(
                'Carregando habilidades...',
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('Batalha Pokémon'),
        backgroundColor: Colors.red[700],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Fundo da batalha
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage('https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/items/quick-powder.png'),
                      fit: BoxFit.cover,
                      opacity: 0.1,
                    ),
                  ),
                ),
                
                // Informações dos Pokémon
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPokemonInfo(widget.pokemon2, pokemon2HP, pokemon2MaxHP, false),
                        ],
                      ),
                      Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildPokemonInfo(widget.pokemon1, pokemon1HP, pokemon1MaxHP, true),
                        ],
                      ),
                    ],
                  ),
                ),

                // Pokémon
                Positioned(
                  right: 30,
                  top: 80,
                  child: AnimatedBuilder(
                    animation: _shakeAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          math.sin(_shakeAnimationController.value * math.pi * 8) * 5,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: CachedNetworkImage(
                      imageUrl: widget.pokemon2.imageUrl,
                      height: 150,
                    ),
                  ),
                ),
                Positioned(
                  left: 30,
                  bottom: 80,
                  child: AnimatedBuilder(
                    animation: _shakeAnimationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(
                          math.sin(_shakeAnimationController.value * math.pi * 8) * 5,
                          0,
                        ),
                        child: child,
                      );
                    },
                    child: CachedNetworkImage(
                      imageUrl: widget.pokemon1.imageUrl,
                      height: 150,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Log de batalha
          Container(
            padding: EdgeInsets.all(8),
            color: Colors.white,
            width: double.infinity,
            child: Text(
              battleLog,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Movimentos
          if (isPlayer1Turn) Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: pokemon1Moves.sublist(0, math.min(2, pokemon1Moves.length))
                      .map(_buildMoveButton)
                      .toList(),
                ),
                if (pokemon1Moves.length > 2) ...[
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: pokemon1Moves.sublist(2, pokemon1Moves.length)
                        .map(_buildMoveButton)
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PokemonMove {
  final String name;
  final double damage;
  final String type;
  final double accuracy;

  const PokemonMove({
    required this.name,
    required this.damage,
    required this.type,
    required this.accuracy,
  });
} 