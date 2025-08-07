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
    if (selectedTypes.isEmpty && selectedGeneration == 0 && powerRange == const RangeValues(0, 1000)) {
      return true;
    }

    if (selectedTypes.isNotEmpty) {
      final selectedTypesList = selectedTypes.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();
      
      bool hasAnySelectedType = selectedTypesList.any((selectedType) =>
        pokemon.types.map((t) => t.toLowerCase()).contains(selectedType.toLowerCase())
      );
      
      if (!hasAnySelectedType) return false;
    }

    if (selectedGeneration > 0) {
      int pokemonGen = _getPokemonGeneration(pokemon.id);
      if (pokemonGen != selectedGeneration) return false;
    }

    if (powerRange != const RangeValues(0, 1000)) {
      if (statsCache.containsKey(pokemon.id)) {
        final stats = statsCache[pokemon.id]!;
        final keys = const ['hp','attack','defense','special-attack','special-defense','speed'];
        int totalPower = 0;
        for (final k in keys) {
          if (stats.containsKey(k)) totalPower += stats[k]!;
        }
        if (totalPower == 0) {
          totalPower = stats.entries
              .where((e) => e.key != 'total_power')
              .fold<int>(0, (sum, e) => sum + e.value);
        }
        if (totalPower < powerRange.start || totalPower > powerRange.end) {
          return false;
        }
      } else {
        print("Excluindo ${pokemon.name} (ID: ${pokemon.id}) do filtro de poder por falta de stats no cache.");
        return false;
      }
    }

    return true;
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
    // Assumindo que IDs > 898 são Gen 9 (ou posteriores, mas a API buscada vai até ~1000)
    return 9; 
  }
}