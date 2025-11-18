import 'package:flutter/material.dart';
import '../services/pokemon_cache_service.dart';
import '../services/pokemon_list_service.dart';

class CacheDebugWidget extends StatefulWidget {
  const CacheDebugWidget({Key? key}) : super(key: key);

  @override
  _CacheDebugWidgetState createState() => _CacheDebugWidgetState();
}

class _CacheDebugWidgetState extends State<CacheDebugWidget> {
  Map<String, dynamic> _cacheStats = {};

  bool _isLoading = false;
  final PokemonListService _pokemonListService = PokemonListService();

  @override
  void initState() {
    super.initState();
    // Registrar a instância do service no cache
    PokemonCacheService.setPokemonListService(_pokemonListService);
    _loadCacheStats();
  }

  void _loadCacheStats() {
    setState(() {
      _cacheStats = PokemonCacheService.getCacheStatistics();
    });
  }

  Future<void> _clearCache() async {
    setState(() => _isLoading = true);

    try {
      await PokemonCacheService.clearCache();
      _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache limpo com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao limpar cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _forceSave() async {
    setState(() => _isLoading = true);

    try {
      await PokemonCacheService.forceSave();
      _loadCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cache salvo com sucesso!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar cache: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.storage, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  'Cache Inteligente',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(width: 8),
                _buildCacheStatusIndicator(),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadCacheStats,
                  tooltip: 'Atualizar Estatísticas',
                ),
              ],
            ),
            const Divider(),
            Text(
              '🧠 Cache Inteligente',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
            ),
            _buildStatRow('Pokémon', '${_cacheStats['pokemon_count'] ?? 0}'),
            _buildStatRow('Stats', '${_cacheStats['stats_count'] ?? 0}'),
            _buildStatRow('Índice de Busca',
                '${_cacheStats['search_index_size'] ?? 0} entradas'),
            _buildStatRow('Taxa de Acerto',
                '${((_cacheStats['cache_hit_rate'] ?? 0) * 100).toStringAsFixed(1)}%'),
            _buildStatRow('Uso de Memória',
                '${(_cacheStats['memory_usage_mb'] ?? 0).toStringAsFixed(2)} MB'),
            _buildStatRow('Último Salvamento',
                '${_cacheStats['last_save_time'] ?? 'Nunca'}'),
            _buildStatRow(
                'Idade do Cache', '${_cacheStats['cache_age_hours'] ?? 0}h'),
            _buildStatRow('Mais Acessado',
                '${_cacheStats['most_accessed_pokemon'] ?? 'Nenhum'}'),
            const SizedBox(height: 16),
            _buildCacheHealthIndicator(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _forceSave,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: const Text('Salvar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _clearCache,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.clear_all),
                    label: const Text('Limpar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheStatusIndicator() {
    final pokemonCount = _cacheStats['pokemon_count'] ?? 0;
    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    if (pokemonCount == 0) {
      statusColor = Colors.grey;
      statusText = 'Vazio';
      statusIcon = Icons.inbox;
    } else if (pokemonCount < 50) {
      statusColor = Colors.orange;
      statusText = 'Baixo';
      statusIcon = Icons.warning;
    } else if (pokemonCount < 200) {
      statusColor = Colors.blue;
      statusText = 'Médio';
      statusIcon = Icons.info;
    } else {
      statusColor = Colors.green;
      statusText = 'Ótimo';
      statusIcon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text(
            statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCacheHealthIndicator() {
    final pokemonCount = _cacheStats['pokemon_count'] ?? 0;
    final statsCount = _cacheStats['stats_count'] ?? 0;
    final searchIndexSize = _cacheStats['search_index_size'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Saúde do Cache',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (pokemonCount / 1000).clamp(0.0, 1.0),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              pokemonCount > 500
                  ? Colors.green
                  : pokemonCount > 100
                      ? Colors.orange
                      : Colors.red,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Progresso: $pokemonCount/1000 Pokémon (${(pokemonCount / 10).toStringAsFixed(1)}%)',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildHealthBadge(
                'Dados',
                pokemonCount > 0 ? 'OK' : 'Vazio',
                pokemonCount > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              _buildHealthBadge(
                'Stats',
                statsCount > 0 ? 'OK' : 'Vazio',
                statsCount > 0 ? Colors.green : Colors.grey,
              ),
              const SizedBox(width: 8),
              _buildHealthBadge(
                'Busca',
                searchIndexSize > 0 ? 'OK' : 'Vazio',
                searchIndexSize > 0 ? Colors.green : Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthBadge(String label, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $status',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
