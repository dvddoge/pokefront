import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/opponent.dart';
import '../../models/pokemon.dart';
import '../../services/tournament_service.dart';
import '../battle/pokemon_battle_screen.dart';

class TournamentScreen extends StatefulWidget {
  final Pokemon playerPokemon;

  const TournamentScreen({Key? key, required this.playerPokemon}) : super(key: key);

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  final List<Opponent> opponents = TournamentService.getTournamentOpponents();
  int currentOpponentIndex = 0; // Começa com o primeiro oponente
  bool isBattling = false;

  Future<Pokemon> _fetchOpponentPokemon(int id, int level) async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));
    if (response.statusCode == 200) {
      final pokemonData = Pokemon.fromDetailJson(json.decode(response.body));
      return pokemonData.copyWith(level: level); // Ajusta o nível do oponente
    } else {
      throw Exception('Falha ao carregar Pokémon do oponente');
    }
  }

  void _startBattle(Opponent opponent) async {
    setState(() {
      isBattling = true;
    });

    try {
      final opponentPokemon = await _fetchOpponentPokemon(opponent.pokemonId, opponent.pokemonLevel);
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PokemonBattleScreen(
            pokemon1: widget.playerPokemon,
            pokemon2: opponentPokemon,
          ),
        ),
      );

      if (result == true) { // Vitória
        setState(() {
          if (currentOpponentIndex < opponents.length - 1) {
            currentOpponentIndex++;
          } else {
            // Venceu o torneio!
            _showVictoryDialog();
          }
        });
      } else { // Derrota ou voltou
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${opponent.name} te derrotou! Tente novamente.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      print("Erro ao iniciar batalha: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao carregar dados da batalha.')));
    } finally {
      setState(() {
        isBattling = false;
      });
    }
  }

  void _showVictoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Parabéns, Campeão!'),
        content: const Text('Você venceu o Torneio dos Campeões!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                currentOpponentIndex = 0; // Reinicia o torneio
              });
            },
            child: const Text('Jogar Novamente'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Torneio dos Campeões'),
        backgroundColor: Colors.amber[800],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade100, Colors.deepOrange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView.builder(
          itemCount: opponents.length,
          itemBuilder: (context, index) {
            final opponent = opponents[index];
            final isDefeated = index < currentOpponentIndex;
            final isCurrent = index == currentOpponentIndex;

            return _buildOpponentCard(opponent, isDefeated, isCurrent);
          },
        ),
      ),
    );
  }

  Widget _buildOpponentCard(Opponent opponent, bool isDefeated, bool isCurrent) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isCurrent ? 8 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isCurrent 
          ? BorderSide(color: Colors.amber.shade800, width: 3)
          : BorderSide.none,
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: CachedNetworkImageProvider(opponent.avatarUrl),
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opponent.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        opponent.title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      isCurrent
                          ? ElevatedButton.icon(
                              onPressed: isBattling ? null : () => _startBattle(opponent),
                              icon: isBattling 
                                  ? SizedBox(width: 24, height: 24, child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white,))
                                  : const Icon(Icons.sports_kabaddi),
                              label: Text(isBattling ? 'Carregando...' : 'Lutar Agora!'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isDefeated)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent.withOpacity(0.8),
                    size: 80,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 