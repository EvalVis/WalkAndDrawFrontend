import 'package:flutter/material.dart';
import 'package:auth0_flutter/auth0_flutter.dart';

class LoginScreen extends StatelessWidget {
  final Auth0 auth0;
  final Function(Credentials) onLogin;

  const LoginScreen({
    super.key,
    required this.auth0,
    required this.onLogin,
  });

  Future<void> _handleLogin() async {
    try {
      final credentials = await auth0
          .webAuthentication(scheme: 'com.programmersdiary.walkanddraw')
          .login();
      onLogin(credentials);
    } catch (e) {
      print('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: _handleLogin,
          child: const Text('Log in'),
        ),
      ),
    );
  }
}
