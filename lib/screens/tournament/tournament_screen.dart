import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/opponent.dart';
import '../../models/pokemon.dart';
import '../../models/tournament_progress.dart';
import '../../models/tournament_reward.dart';
import '../../services/tournament_service.dart';
import '../battle/pokemon_battle_screen.dart';

class TournamentScreen extends StatefulWidget {
  final Pokemon playerPokemon;

  const TournamentScreen({Key? key, required this.playerPokemon}) : super(key: key);

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> with TickerProviderStateMixin {
  final List<Opponent> opponents = TournamentService.getTournamentOpponents();
  late TournamentProgress progress;
  late AnimationController _progressAnimationController;
  bool isBattling = false;

  @override
  void initState() {
    super.initState();
    progress = TournamentProgress(
      tournamentId: 'champions_tournament_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
    );
    
    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _progressAnimationController.dispose();
    super.dispose();
  }

  Future<Pokemon> _fetchOpponentPokemon(int id, int level) async {
    final response = await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));
    if (response.statusCode == 200) {
      final pokemonData = Pokemon.fromDetailJson(json.decode(response.body));
      return pokemonData.copyWith(level: level);
    } else {
      throw Exception('Falha ao carregar Pokémon do oponente');
    }
  }

  void _startBattle(Opponent opponent) async {
    setState(() {
      isBattling = true;
    });

    final battleStartTime = DateTime.now();

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

      final battleEndTime = DateTime.now();
      final battleDuration = battleEndTime.difference(battleStartTime);

      if (result == true) {
        // Calcula pontuação da batalha
        final battleScore = TournamentService.calculateBattleScore(
          opponentLevel: opponent.pokemonLevel,
          playerLevel: widget.playerPokemon.level ?? 50,
          battleTime: battleDuration,
          playerWon: true,
        );

        setState(() {
          progress = progress.copyWith(
            currentOpponentIndex: progress.currentOpponentIndex + 1,
            currentScore: progress.currentScore + battleScore,
            battleScores: [...progress.battleScores, battleScore],
          );

          // Verifica se completou o torneio
          if (progress.currentOpponentIndex >= opponents.length) {
            _completeTournament();
          }
        });

        _progressAnimationController.forward();
        
        // Mostra pontuação da batalha
        _showBattleScoreDialog(battleScore, opponent.name);
        
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${opponent.name} te derrotou! Tente novamente.'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } catch (e) {
      print("Erro ao iniciar batalha: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao carregar dados da batalha.')),
      );
    } finally {
      setState(() {
        isBattling = false;
      });
    }
  }

  void _completeTournament() {
    final endTime = DateTime.now();
    final earnedMedal = TournamentService.calculateMedal(
      totalScore: progress.currentScore,
      totalTime: endTime.difference(progress.startTime),
      tournamentCompleted: true,
    );

    setState(() {
      progress = progress.copyWith(
        endTime: endTime,
        isCompleted: true,
        earnedMedal: earnedMedal,
      );
    });

    // Calcula recompensas
    final stats = TournamentStats(
      battlesWon: progress.battleScores.length,
      tournamentsWon: 1,
    );
    
    final earnedRewards = TournamentService.calculateEarnedRewards(
      progress: progress,
      stats: stats,
    );

    _showVictoryDialog(earnedMedal, earnedRewards);
  }

  void _showBattleScoreDialog(int score, String opponentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.stars, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Batalha Vencida!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Você derrotou $opponentName!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Column(
                children: [
                  Text(
                    '+$score pontos',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pontuação Total: ${progress.currentScore}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _showVictoryDialog(MedalType? medal, List<TournamentReward> rewards) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text(
          '🏆 Parabéns, Campeão!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Você venceu o Torneio dos Campeões!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              
              // Estatísticas finais
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Pontuação Total:'),
                        Text(
                          '${progress.currentScore}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Tempo Total:'),
                        Text(
                          '${progress.totalTime.inMinutes}:${(progress.totalTime.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              if (medal != null) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TournamentService.getMedalColor(medal).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: TournamentService.getMedalColor(medal)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        TournamentService.getMedalIcon(medal),
                        style: const TextStyle(fontSize: 48),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Medalha ${medal.name.toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (rewards.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Recompensas Desbloqueadas:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...rewards.map((reward) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.emoji_events, color: Colors.green[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              reward.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              reward.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (reward.pointsValue > 0)
                        Text(
                          '+${reward.pointsValue}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                progress = TournamentProgress(
                  tournamentId: 'champions_tournament_${DateTime.now().millisecondsSinceEpoch}',
                  startTime: DateTime.now(),
                );
              });
              _progressAnimationController.reset();
            },
            child: const Text('Jogar Novamente'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Voltar'),
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
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.amber.shade100, Colors.deepOrange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            // Header com progresso
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pontuação',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${progress.currentScore}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Tempo',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            '${progress.totalTime.inMinutes}:${(progress.totalTime.inSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Barra de progresso
                  Row(
                    children: [
                      Text('Progresso: ${progress.currentOpponentIndex}/${opponents.length}'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress.currentOpponentIndex / opponents.length,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.amber[700]!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Lista de oponentes
            Expanded(
              child: ListView.builder(
                itemCount: opponents.length,
                itemBuilder: (context, index) {
                  final opponent = opponents[index];
                  final isDefeated = index < progress.currentOpponentIndex;
                  final isCurrent = index == progress.currentOpponentIndex && !progress.isCompleted;

                  return _buildOpponentCard(opponent, isDefeated, isCurrent, index);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOpponentCard(Opponent opponent, bool isDefeated, bool isCurrent, int index) {
    final battleScore = index < progress.battleScores.length ? progress.battleScores[index] : 0;
    
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
                      if (isDefeated) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '+$battleScore pontos',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (isCurrent)
                        ElevatedButton.icon(
                          onPressed: isBattling ? null : () => _startBattle(opponent),
                          icon: isBattling 
                              ? const SizedBox(
                                  width: 16, 
                                  height: 16, 
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sports_kabaddi),
                          label: Text(isBattling ? 'Carregando...' : 'Lutar Agora!'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
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
                  color: Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
} 