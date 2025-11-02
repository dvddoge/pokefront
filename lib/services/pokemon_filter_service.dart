import 'package:flutter/material.dart';
import '../models/pokemon.dart';

class PokemonFilterService {
  static bool shouldIncludePokemon({
    required Pokemon pokemon,
    required Map<String, bool> selectedTypes,
    required int selectedGeneration,
    required RangeValues powerRange,
    Map<int, Map<String, int>>? statsCache,
    RangeValues? heightRange,
    RangeValues? weightRange,
  }) {
    const defaultPower = RangeValues(0, 1000);
    const defaultHeight = RangeValues(0, 20);
    const defaultWeight = RangeValues(0, 1000);

    final effectiveHeight = heightRange ?? defaultHeight;
    final effectiveWeight = weightRange ?? defaultWeight;
    final hasSelectedTypes =
        selectedTypes.entries.any((entry) => entry.value == true);

    if (!hasSelectedTypes &&
        selectedGeneration == 0 &&
        powerRange == defaultPower &&
        effectiveHeight == defaultHeight &&
        effectiveWeight == defaultWeight) {
      return true;
    }

    final selectedTypesList = selectedTypes.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();

    if (selectedTypesList.isNotEmpty) {
      final hasAnySelectedType = selectedTypesList.any((selectedType) => pokemon
          .types
          .map((t) => t.toLowerCase())
          .contains(selectedType.toLowerCase()));

      if (!hasAnySelectedType) {
        return false;
      }
    }

    if (selectedGeneration > 0) {
      int pokemonGen = _getPokemonGeneration(pokemon.id);
      if (pokemonGen != selectedGeneration) return false;
    }

    if (powerRange != defaultPower) {
      final totalPower = _resolveTotalPower(pokemon, statsCache);
      if (totalPower == null) {
        return false;
      }
      if (totalPower < powerRange.start || totalPower > powerRange.end) {
        return false;
      }
    }

    if (effectiveHeight != defaultHeight) {
      final h = pokemon.heightMeters;
      if (h == null || h < effectiveHeight.start || h > effectiveHeight.end) {
        return false;
      }
    }

    if (effectiveWeight != defaultWeight) {
      final w = pokemon.weightKg;
      if (w == null || w < effectiveWeight.start || w > effectiveWeight.end) {
        return false;
      }
    }

    return true;
  }

  static int? _resolveTotalPower(
    Pokemon pokemon,
    Map<int, Map<String, int>>? statsCache,
  ) {
    if (statsCache != null) {
      final cached = statsCache[pokemon.id];
      if (cached != null && cached.isNotEmpty) {
        final totalFromCache = cached['total_power'];
        if (totalFromCache != null && totalFromCache > 0) {
          return totalFromCache;
        }
        final relevant = cached.entries
            .where((entry) => entry.key != 'total_power')
            .map((entry) => entry.value);
        if (relevant.isNotEmpty) {
          return relevant.fold<int>(0, (sum, value) => sum + value);
        }
      }
    }

    final fallback = pokemon.totalBaseStats;
    return fallback > 0 ? fallback : null;
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
