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

    if (statsCache.containsKey(pokemon.id)) {
      int totalPower = statsCache[pokemon.id]!.values.reduce((a, b) => a + b);
      if (totalPower < powerRange.start || totalPower > powerRange.end) {
        return false;
      }
    }

    return true;
  }

  static int _getPokemonGeneration(int pokemonId) {
    if (pokemonId <= 151) return 1;
    if (pokemonId <= 251) return 2;
    if (pokemonId <= 386) return 3;
    if (pokemonId <= 493) return 4;
    if (pokemonId <= 649) return 5;
    if (pokemonId <= 721) return 6;
    if (pokemonId <= 809) return 7;
    return 8;
  }
} 