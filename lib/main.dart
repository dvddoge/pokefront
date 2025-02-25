import 'package:flutter/material.dart';
import 'screens/pokemon/pokemon_screen.dart';
import 'theme.dart' hide NavigationService;
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

// Tela temporária para evitar erros
class PokemonListScreen extends StatelessWidget {
  const PokemonListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pokémon App'),
        backgroundColor: Colors.red[700],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Carregando aplicativo...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(
              color: Colors.red[700],
            ),
          ],
        ),
      ),
    );
  }
}
