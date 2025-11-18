import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import '../../models/opponent.dart';
import '../../models/pokemon.dart';
import '../../models/tournament_progress.dart';
import '../../models/tournament_reward.dart';
import '../../services/tournament_service.dart';
import '../../services/achievement_service.dart';
import '../battle/pokemon_battle_screen.dart';
import 'components/tournament_bracket.dart';
import 'components/victory_particles.dart';

class TournamentScreen extends StatefulWidget {
  final Pokemon playerPokemon;

  const TournamentScreen({Key? key, required this.playerPokemon})
      : super(key: key);

  @override
  _TournamentScreenState createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen>
    with TickerProviderStateMixin {
  final List<Opponent> opponents = TournamentService.getTournamentOpponents();
  late TournamentProgress progress;
  late AnimationController _progressAnimationController;
  late AnimationController _headerAnimationController;
  late AnimationController _bracketAnimationController;
  bool isBattling = false;
  bool showVictoryParticles = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    progress = TournamentProgress(
      tournamentId:
          'champions_tournament_${DateTime.now().millisecondsSinceEpoch}',
      startTime: DateTime.now(),
    );

    _progressAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _bracketAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _startTimer();

    // Inicia animações
    _headerAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _bracketAnimationController.forward();
    });
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !progress.isCompleted) {
        setState(() {
          // Força rebuild para atualizar o tempo
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressAnimationController.dispose();
    _headerAnimationController.dispose();
    _bracketAnimationController.dispose();
    super.dispose();
  }

  Future<Pokemon> _fetchOpponentPokemon(int id, int level) async {
    final response =
        await http.get(Uri.parse('https://pokeapi.co/api/v2/pokemon/$id'));
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
      final opponentPokemon = await _fetchOpponentPokemon(
          opponent.pokemonId, opponent.pokemonLevel);

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
          playerLevel: widget.playerPokemon.level,
          battleTime: battleDuration,
          playerWon: true,
        );

        // Atualiza estatísticas da batalha
        await TournamentService.updatePlayerStats(
          tournamentCompleted: false,
          battleWon: true,
          tournamentTime: battleDuration,
          tournamentScore: battleScore,
        );

        // Atualiza conquistas (batalha concluída)
        final newlyUnlocked = await AchievementService.onBattleFinished(
          playerWon: true,
          battleTime: battleDuration,
          // Dano sofrido: indisponível aqui, mantemos como >0 para não liberar 'intocável' indevidamente
          damageTaken: 1,
        );
        if (newlyUnlocked.isNotEmpty) {
          for (final def in newlyUnlocked) {
            _showGenericAchievementToast(def.name, '+${def.points} XP');
            await Future.delayed(const Duration(milliseconds: 400));
          }
        }

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

        // Ativa partículas de vitória
        setState(() {
          showVictoryParticles = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              showVictoryParticles = false;
            });
          }
        });

        // Verifica conquistas desbloqueadas
        _checkAndShowAchievements();

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

  void _completeTournament() async {
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

    // Atualiza estatísticas do jogador
    await TournamentService.updatePlayerStats(
      tournamentCompleted: true,
      battleWon: true,
      tournamentTime: progress.totalTime,
      tournamentScore: progress.currentScore,
    );

    // Atualiza milestones baseados em estatísticas
    final updatedStats = await TournamentService.loadPlayerStats();
    final unlockedByStats =
        await AchievementService.onStatsUpdated(updatedStats);
    if (unlockedByStats.isNotEmpty) {
      for (final def in unlockedByStats) {
        _showGenericAchievementToast(def.name, '+${def.points} XP');
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    // Carrega estatísticas atualizadas
    final stats = await TournamentService.loadPlayerStats();

    // Calcula recompensas
    final earnedRewards = await TournamentService.calculateEarnedRewards(
      progress: progress,
      stats: stats,
    );

    _showVictoryDialog(earnedMedal, earnedRewards);
  }

  void _showGenericAchievementToast(String title, String subtitle) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple[700],
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  const Icon(Icons.emoji_events, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '🏅 Novo Desafio Cumprido!',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(title, style: const TextStyle(fontSize: 16)),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.purple[100]),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.purple[600],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showBattleScoreDialog(int score, String opponentName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.stars, color: Colors.amber[700]),
            const SizedBox(width: 8),
            const Text('Vitória!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Você derrotou $opponentName!'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.emoji_events, color: Colors.amber[700]),
                  const SizedBox(width: 8),
                  Text(
                    '+$score pontos',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  // Função para verificar e exibir conquistas em tempo real
  void _checkAndShowAchievements() async {
    final stats = await TournamentService.loadPlayerStats();

    // Verifica se há novas conquistas baseadas no progresso atual
    final tempProgress = progress.copyWith(
        isCompleted: false); // Para não calcular medalhas ainda
    final newAchievements = await TournamentService.calculateEarnedRewards(
      progress: tempProgress,
      stats: stats,
    );

    // Mostra conquistas desbloqueadas
    if (newAchievements.isNotEmpty && mounted) {
      for (final achievement in newAchievements) {
        _showAchievementUnlocked(achievement);
        // Pequeno delay entre conquistas
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  void _showAchievementUnlocked(TournamentReward achievement) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[700],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🏆 Conquista Desbloqueada!',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      achievement.name,
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (achievement.pointsValue > 0)
                      Text(
                        '+${achievement.pointsValue} pontos',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[200],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green[700],
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
                    color: TournamentService.getMedalColor(medal)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: TournamentService.getMedalColor(medal)),
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
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
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
                  tournamentId:
                      'champions_tournament_${DateTime.now().millisecondsSinceEpoch}',
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
        title: AnimatedBuilder(
          animation: _headerAnimationController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, 20 * (1 - _headerAnimationController.value)),
              child: Opacity(
                opacity: _headerAnimationController.value,
                child: const Text('Torneio dos Campeões'),
              ),
            );
          },
        ),
        backgroundColor: Colors.amber[800],
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.amber[700]!, Colors.amber[900]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.amber.shade50, Colors.deepOrange.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                // Header com progresso animado
                AnimatedBuilder(
                  animation: _headerAnimationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                          0, -50 * (1 - _headerAnimationController.value)),
                      child: Opacity(
                        opacity: _headerAnimationController.value,
                        child: _buildProgressHeader(),
                      ),
                    );
                  },
                ),

                // Bracket visual com scroll horizontal
                Expanded(
                  child: AnimatedBuilder(
                    animation: _bracketAnimationController,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 0.5 + (_bracketAnimationController.value * 0.5),
                        child: Opacity(
                          opacity: _bracketAnimationController.value,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: TournamentBracket(
                              opponents: opponents,
                              playerPokemon: widget.playerPokemon,
                              progress: progress,
                              onPlayerTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Seu Pokémon: ${widget.playerPokemon.name}'),
                                    backgroundColor: Colors.blue[700],
                                  ),
                                );
                              },
                              onOpponentTap: _startBattle,
                              isBattling: isBattling,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Partículas de vitória
          if (showVictoryParticles)
            Positioned.fill(
              child: IgnorePointer(
                child: VictoryParticles(
                  isActive: showVictoryParticles,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard(
                'Pontuação',
                '${progress.currentScore}',
                Colors.amber,
                Icons.stars,
              ),
              _buildStatCard(
                'Tempo',
                '${progress.totalTime.inMinutes}:${(progress.totalTime.inSeconds % 60).toString().padLeft(2, '0')}',
                Colors.blue,
                Icons.timer,
              ),
              _buildStatCard(
                'Progresso',
                '${progress.currentOpponentIndex}/${opponents.length}',
                Colors.green,
                Icons.trending_up,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Barra de progresso animada
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey[200],
            ),
            child: AnimatedBuilder(
              animation: _progressAnimationController,
              builder: (context, child) {
                return FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor:
                      (progress.currentOpponentIndex / opponents.length) *
                          _progressAnimationController.value,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [Colors.amber[600]!, Colors.amber[800]!],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
