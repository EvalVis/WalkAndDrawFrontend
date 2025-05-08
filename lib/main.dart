import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';
import 'leaderboard_screen.dart';
import 'drawings_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Credentials? _credentials;
  late Auth0 auth0;

  @override
  void initState() {
    super.initState();
    auth0 = Auth0('dev-nfxagfo4wp0f5ee7.us.auth0.com',
        'Cj3Mrzu9h99Nd2ZCzWC5NFrJoxKzftRa');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk and Draw',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _credentials == null
          ? LoginScreen(
              auth0: auth0,
              onLogin: (credentials) {
                setState(() {
                  _credentials = credentials;
                });
              },
            )
          : MainApp(
              credentials: _credentials!,
              onLogout: _handleLogout,
            ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await auth0
          .webAuthentication(scheme: 'com.programmersdiary.walkanddraw')
          .logout();

      setState(() {
        _credentials = null;
      });
    } catch (e) {
      print('Logout error: $e');
    }
  }
}

class MainApp extends StatefulWidget {
  final Credentials credentials;
  final VoidCallback onLogout;

  const MainApp({
    super.key,
    required this.credentials,
    required this.onLogout,
  });

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          MapScreen(
            credentials: widget.credentials,
            onLogout: widget.onLogout,
          ),
          LeaderboardScreen(
            credentials: widget.credentials,
          ),
          DrawingsScreen(
            credentials: widget.credentials,
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.leaderboard),
            label: 'Leaderboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.brush),
            label: 'Drawings',
          ),
        ],
      ),
    );
  }
}
