import '../models/opponent.dart';

class TournamentService {
  static List<Opponent> getTournamentOpponents() {
    return [
      // Rodada 1: Quartas de Final
      Opponent(
        name: 'Brawly',
        title: 'Lutador de Ondas',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/3/39/Ruby_Sapphire_Brawly.png/200px-Ruby_Sapphire_Brawly.png',
        pokemonId: 257, // Blaziken
        pokemonLevel: 55,
      ),
      // Rodada 2: Semifinal
      Opponent(
        name: 'Elesa',
        title: 'Modelo Eletrizante',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/5/5f/Black_2_White_2_Elesa.png/200px-Black_2_White_2_Elesa.png',
        pokemonId: 604, // Eelektross
        pokemonLevel: 65,
      ),
      // Rodada 3: Final
      Opponent(
        name: 'Cynthia',
        title: 'Campeã de Sinnoh',
        avatarUrl: 'https://archives.bulbagarden.net/media/upload/thumb/3/3b/Diamond_Pearl_Cynthia.png/200px-Diamond_Pearl_Cynthia.png',
        pokemonId: 445, // Garchomp
        pokemonLevel: 78,
      ),
    ];
  }
} 