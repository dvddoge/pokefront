# PokéFront

## Description

PokéFront is a Flutter application to view information about Pokémon, using the PokeAPI to obtain the data.

## How to Run

### Prerequisites

*   Flutter SDK installed.

### Steps

1.  Clone the repository:

    ```bash
    git clone [Repository URL]
    ```
2.  Run `flutter pub get` to install dependencies:

    ```bash
    flutter pub get
    ```
3.  Run `flutter run` to start the application:

    ```bash
    flutter run
    ```

## Dependencies

*   `flutter_staggered_animations`: For animations.
*   `cached_network_image`: For efficient image loading.
*   `animations`: For screen transitions.
*   `google_fonts`: To use the Poppins font.
*   `http`: To make requests to the PokeAPI.
*   `shimmer`: For loading effects.
*   `firebase_core`: To initialize Firebase.

## Additional Information

*   The application uses the PokeAPI to fetch Pokémon data.
*   Firebase is used only for initialization, not for specific functionalities.
