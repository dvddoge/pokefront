import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PokemonNetImage extends StatelessWidget {
  final String imageUrl;
  final int pokemonId;
  final double? height;
  final double? width;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? fallbackPlaceholder;

  const PokemonNetImage({
    super.key,
    required this.imageUrl,
    required this.pokemonId,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.fallbackPlaceholder,
  });

  String get _fallbackUrl => 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$pokemonId.png';

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: imageUrl,
      height: height,
      width: width,
      fit: fit,
      placeholder: (context, url) => placeholder ?? const SizedBox.shrink(),
      errorWidget: (context, url, error) => CachedNetworkImage(
        imageUrl: _fallbackUrl,
        height: height,
        width: width,
        fit: fit,
        placeholder: (context, url) => fallbackPlaceholder ?? const SizedBox.shrink(),
        errorWidget: (context, url, error) => Icon(
          Icons.catching_pokemon,
          color: Colors.grey[400],
          size: (height != null) ? (height! * 0.6) : 48,
        ),
      ),
    );
  }
}


