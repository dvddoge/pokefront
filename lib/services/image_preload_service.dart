import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/pokemon.dart';

class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  final Set<String> _preloadedImages = {};

  Future<void> preloadPokemonImage(Pokemon pokemon) async {
    if (_preloadedImages.contains(pokemon.imageUrl)) return;

    try {
      await CachedNetworkImageProvider(pokemon.imageUrl)
        .resolve(ImageConfiguration.empty);
      _preloadedImages.add(pokemon.imageUrl);
    } catch (e) {
      print('Error preloading image: $e');
    }
  }

  Future<void> preloadBattle(Pokemon pokemon1, Pokemon pokemon2) async {
    await Future.wait([
      preloadPokemonImage(pokemon1),
      preloadPokemonImage(pokemon2),
    ]);
  }

  void clearCache() {
    _preloadedImages.clear();
  }
}