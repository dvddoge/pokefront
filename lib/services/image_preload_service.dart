import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/pokemon.dart';

class ImagePreloadService {
  static final ImagePreloadService _instance = ImagePreloadService._internal();
  factory ImagePreloadService() => _instance;
  ImagePreloadService._internal();

  final Set<String> _preloadedImages = {};

  Future<void> preloadPokemonImage(Pokemon pokemon) async {
    if (_preloadedImages.contains(pokemon.imageUrl)) return;

    try {
      final context = NavigationService.navigatorKey.currentContext;
      if (context == null) return;

      final provider = CachedNetworkImageProvider(pokemon.imageUrl);
      await precacheImage(provider, context);
      _preloadedImages.add(pokemon.imageUrl);
    } catch (e) {
      debugPrint('Aviso: Imagem não pré-carregada para ${pokemon.name}');
    }
  }

  Future<void> preloadBattle(Pokemon pokemon1, Pokemon pokemon2) async {
    try {
      await Future.wait([
        preloadPokemonImage(pokemon1),
        preloadPokemonImage(pokemon2),
      ], eagerError: false);
    } catch (e) {
      debugPrint('Aviso: Algumas imagens da batalha não foram pré-carregadas');
    }
  }

  void clearCache() {
    _preloadedImages.clear();
  }
}

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}