import 'package:flutter/material.dart';
import '../models/pokemon.dart';

class PokemonFilterService {
  static bool shouldIncludePokemon({
    required Pokemon pokemon,
    required Map<String, bool> selectedTypes,
    required int selectedGeneration,
    required RangeValues powerRange,
    required Map<int, Map<String, int>> statsCache,
  }) {
    // Lógica OR: incluir se casar com QUALQUER filtro ativo (tipos OU geração OU poder)
    final bool hasActiveTypeFilters = selectedTypes.entries.any((e) => e.value);
    final bool hasGenerationFilter = selectedGeneration > 0;
    final bool hasPowerFilter = powerRange != const RangeValues(0, 1000);
    final bool anyFilterActive = hasActiveTypeFilters || hasGenerationFilter || hasPowerFilter;

    if (!anyFilterActive) return true; // Sem filtros => inclui tudo

    bool matchesType = false;
    bool matchesGeneration = false;
    bool matchesPower = false;

    if (hasActiveTypeFilters) {
      final activeTypes = selectedTypes.entries
          .where((e) => e.value)
          .map((e) => e.key.toLowerCase())
          .toList();
      final pokemonTypesLower = pokemon.types.map((t) => t.toLowerCase());
      matchesType = pokemonTypesLower.any((t) => activeTypes.contains(t));
    }

    if (hasGenerationFilter) {
      matchesGeneration = _getPokemonGeneration(pokemon.id) == selectedGeneration;
    }

    if (hasPowerFilter) {
      if (statsCache.containsKey(pokemon.id)) {
        final stats = statsCache[pokemon.id]!;
        const keys = ['hp','attack','defense','special-attack','special-defense','speed'];
        int totalPower = 0;
        for (final k in keys) {
          final val = stats[k];
          if (val != null) totalPower += val;
        }
        if (totalPower == 0) {
          totalPower = stats.entries
              .where((e) => e.key != 'total_power')
              .fold<int>(0, (sum, e) => sum + e.value);
        }
        matchesPower = totalPower >= powerRange.start && totalPower <= powerRange.end;
      } else {
        // Não tem stats ainda => simplesmente não casa com poder
        matchesPower = false;
      }
    }

    return matchesType || matchesGeneration || matchesPower;
  }

  // Método público para obter a geração de um Pokémon
  static int getPokemonGeneration(int pokemonId) {
  return _getPokemonGeneration(pokemonId);
  }

  static int _getPokemonGeneration(int pokemonId) {
    if (pokemonId <= 151) return 1; // Gen 1
    if (pokemonId <= 251) return 2; // Gen 2
    if (pokemonId <= 386) return 3; // Gen 3
    if (pokemonId <= 493) return 4; // Gen 4
    if (pokemonId <= 649) return 5; // Gen 5
    if (pokemonId <= 721) return 6; // Gen 6
    if (pokemonId <= 809) return 7; // Gen 7
    if (pokemonId <= 898) return 8; // Gen 8
    return 9; // Gen 9 ou superior
  }
}