import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class LoginScreen extends StatelessWidget {
  final GoogleSignIn googleSignIn;
  final Function(GoogleSignInAccount) onLogin;

  const LoginScreen({
    super.key,
    required this.googleSignIn,
    required this.onLogin,
  });

  Future<void> _handleLogin() async {
    try {
      final user = await googleSignIn.signIn();
      if (user != null) {
        onLogin(user);
      }
    } catch (e) {
      print('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          onPressed: _handleLogin,
          icon: const Icon(Icons.g_mobiledata),
          label: const Text('Sign in with Google'),
        ),
      ),
    );
  }
}
