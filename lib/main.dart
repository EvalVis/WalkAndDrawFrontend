import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'leaderboard_screen.dart';
import 'drawings_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'squad_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const App());
}

class App extends StatefulWidget {
  final GoogleSignIn? googleSignIn;

  const App({super.key, this.googleSignIn});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  GoogleSignInAccount? _currentUser;
  late GoogleSignIn _googleSignIn;

  @override
  void initState() {
    super.initState();
    _googleSignIn = widget.googleSignIn ??
        GoogleSignIn(
          clientId: const String.fromEnvironment('GOOGLE_CLIENT_ID'),
        );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Walk and Draw',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: _currentUser == null
          ? LoginScreen(
              googleSignIn: _googleSignIn,
              onLogin: (user) {
                setState(() {
                  _currentUser = user;
                });
              },
            )
          : MainApp(
              user: _currentUser!,
              onLogout: _handleLogout,
            ),
    );
  }

  Future<void> _handleLogout() async {
    try {
      await _googleSignIn.signOut();
      setState(() {
        _currentUser = null;
      });
    } catch (e) {
      print('Logout error: $e');
    }
  }
}

class MainApp extends StatefulWidget {
  final GoogleSignInAccount user;
  final VoidCallback onLogout;

  const MainApp({
    super.key,
    required this.user,
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
            user: widget.user,
            onLogout: widget.onLogout,
          ),
          LeaderboardScreen(
            user: widget.user,
          ),
          DrawingsScreen(
            user: widget.user,
          ),
          SquadScreen(
            user: widget.user,
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
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
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
          BottomNavigationBarItem(
            icon: Icon(Icons.group),
            label: 'Squad',
          ),
        ],
      ),
    );
  }
}
