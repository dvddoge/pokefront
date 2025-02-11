import 'package:flutter/material.dart';
import 'screens/pokemon/pokemon_screen.dart';
import 'theme.dart';
import 'services/image_preload_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PokéDex',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      navigatorKey: NavigationService.navigatorKey,
      home: PokemonScreen(),
    );
  }
}
