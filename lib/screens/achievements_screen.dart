import 'package:flutter/material.dart';
import '../models/tournament_reward.dart';
import '../services/tournament_service.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  _AchievementsScreenState createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  List<TournamentReward> allRewards = [];
  List<TournamentReward> unlockedRewards = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRewards();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadRewards() {
    allRewards = TournamentService.getAllRewards();
    // Simular algumas conquistas desbloqueadas para demonstração
    unlockedRewards = allRewards.take(2).map((reward) => 
      reward.copyWith(isUnlocked: true, unlockedAt: DateTime.now())
    ).toList();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final medals = allRewards.where((r) => r.type == RewardType.medal).toList();
    final achievements = allRewards.where((r) => r.type == RewardType.points).toList();
    final unlockedMedals = unlockedRewards.where((r) => r.type == RewardType.medal).toList();
    final unlockedAchievements = unlockedRewards.where((r) => r.type == RewardType.points).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Conquistas'),
        backgroundColor: Colors.purple[800],
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events), text: 'Todas'),
            Tab(icon: Icon(Icons.military_tech), text: 'Medalhas'),
            Tab(icon: Icon(Icons.star), text: 'Conquistas'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.purple.shade100, Colors.indigo.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildAllAchievements(),
            _buildMedalsTab(medals, unlockedMedals),
            _buildAchievementsTab(achievements, unlockedAchievements),
          ],
        ),
      ),
    );
  }

  Widget _buildAllAchievements() {
    final totalRewards = allRewards.length;
    final unlockedCount = unlockedRewards.length;
    final progressPercentage = unlockedCount / totalRewards;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header com progresso geral
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
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
                          'Progresso Geral',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$unlockedCount de $totalRewards conquistas',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    CircularProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[700]!),
                      strokeWidth: 6,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: progressPercentage,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[700]!),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(progressPercentage * 100).toInt()}% Completo',
                  style: TextStyle(
                    color: Colors.purple[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Medalhas Recentes
          if (unlockedRewards.isNotEmpty) ...[
            const Text(
              'Conquistas Recentes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...unlockedRewards.take(3).map((reward) => _buildRewardCard(reward, true)),
            const SizedBox(height: 24),
          ],
          
          // Próximas Conquistas
          const Text(
            'Próximas Conquistas',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...allRewards.where((r) => !unlockedRewards.contains(r)).take(5)
              .map((reward) => _buildRewardCard(reward, false)),
        ],
      ),
    );
  }

  Widget _buildMedalsTab(List<TournamentReward> medals, List<TournamentReward> unlockedMedals) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.military_tech, color: Colors.amber[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Medalhas do Torneio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${unlockedMedals.length} de ${medals.length} medalhas conquistadas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Grid de medalhas
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.0,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: medals.length,
              itemBuilder: (context, index) {
                final medal = medals[index];
                final isUnlocked = unlockedMedals.any((r) => r.id == medal.id);
                return _buildMedalCard(medal, isUnlocked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab(List<TournamentReward> achievements, List<TournamentReward> unlockedAchievements) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(Icons.star, color: Colors.orange[700], size: 32),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Conquistas Especiais',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${unlockedAchievements.length} de ${achievements.length} conquistas desbloqueadas',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          Expanded(
            child: ListView.builder(
              itemCount: achievements.length,
              itemBuilder: (context, index) {
                final achievement = achievements[index];
                final isUnlocked = unlockedAchievements.any((r) => r.id == achievement.id);
                return _buildRewardCard(achievement, isUnlocked);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(TournamentReward reward, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked 
          ? Border.all(color: Colors.green[300]!, width: 2)
          : Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isUnlocked ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Ícone da recompensa
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isUnlocked 
                ? _getRewardColor(reward).withOpacity(0.2)
                : Colors.grey[300],
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              _getRewardIcon(reward),
              color: isUnlocked ? _getRewardColor(reward) : Colors.grey[500],
              size: 28,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Informações da recompensa
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? Colors.black : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  reward.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
                  ),
                ),
                if (reward.pointsValue > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUnlocked ? Colors.amber[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '+${reward.pointsValue} pontos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUnlocked ? Colors.amber[800] : Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          // Status
          if (isUnlocked) ...[
            Column(
              children: [
                Icon(Icons.check_circle, color: Colors.green[600], size: 24),
                const SizedBox(height: 4),
                if (reward.unlockedAt != null)
                  Text(
                    _formatDate(reward.unlockedAt!),
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
          ] else ...[
            Icon(Icons.lock, color: Colors.grey[400], size: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildMedalCard(TournamentReward medal, bool isUnlocked) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: isUnlocked 
          ? Border.all(color: TournamentService.getMedalColor(medal.medalType!), width: 2)
          : Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isUnlocked ? 0.1 : 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isUnlocked 
              ? TournamentService.getMedalIcon(medal.medalType!)
              : '🔒',
            style: const TextStyle(fontSize: 40),
          ),
          const SizedBox(height: 8),
          Flexible(
            flex: 2,
            child: Text(
              medal.name.replaceAll('Medalha de ', ''),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isUnlocked ? Colors.black : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Flexible(
            flex: 3,
            child: Text(
              medal.description,
              style: TextStyle(
                fontSize: 9,
                color: isUnlocked ? Colors.grey[700] : Colors.grey[500],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (medal.pointsValue > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: isUnlocked 
                  ? TournamentService.getMedalColor(medal.medalType!).withOpacity(0.2)
                  : Colors.grey[200],
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '+${medal.pointsValue}',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: isUnlocked 
                    ? TournamentService.getMedalColor(medal.medalType!)
                    : Colors.grey[600],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getRewardColor(TournamentReward reward) {
    if (reward.medalType != null) {
      return TournamentService.getMedalColor(reward.medalType!);
    }
    
    switch (reward.type) {
      case RewardType.points:
        return Colors.orange;
      case RewardType.pokemon:
        return Colors.blue;
      case RewardType.item:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getRewardIcon(TournamentReward reward) {
    if (reward.medalType != null) {
      return Icons.military_tech;
    }
    
    switch (reward.type) {
      case RewardType.points:
        return Icons.star;
      case RewardType.pokemon:
        return Icons.catching_pokemon;
      case RewardType.item:
        return Icons.inventory;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
} 