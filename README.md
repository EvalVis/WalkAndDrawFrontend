# Walk and Draw

A Flutter application that combines walking with creative drawing on maps. Users can walk around and create drawings on a map, which are then saved and shared with others.

## Features

- **Interactive Map Drawing**: Draw on Google Maps by walking around
- **User Authentication**: Secure login with Auth0
- **Leaderboard**: Compete with other users based on distance walked
- **Drawing Gallery**: View and share your drawings with others

## Project Structure

- `lib/`: Contains the main application code
  - `main.dart`: Entry point and authentication logic
  - `leaderboard_screen.dart`: Leaderboard functionality
  - `drawings_screen.dart`: Drawing gallery and management
  - `services/`: Service layer for API communication
- `android/`: Android-specific configuration
- `test/`: Unit and widget tests

## Dependencies

- **Flutter**: UI framework
- **google_maps_flutter**: For map display and interaction
- **geolocator**: For location tracking
- **auth0_flutter**: For user authentication
- **mongo_dart**: For database operations
- **http**: For API communication

## Licensing

This project is released under the [GNU General Public License v3.0](LICENSE) (GPL-3.0).

### Open Source Components

The core application code is released under the GPL-3.0, which allows you to freely use, modify, and distribute the code, provided that any derivative works are also released under the same license.

### Proprietary API Usage

This application uses several proprietary APIs:

- **Google Maps API**: Used for map display and location tracking
- **Auth0**: Used for user authentication

Please setup API keys for these APIs.

## Getting Started

1. Clone this repository
2. Install Flutter dependencies: `flutter pub get`
3. Set up your own API keys for Google Maps and Auth0
4. Run the application: `flutter run`

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.