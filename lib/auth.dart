import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';

class Auth extends StatefulWidget {
  const Auth({Key? key}) : super(key: key);

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auth0 Demo'),
        actions: [
          if (_credentials != null)
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                await auth0
                    .webAuthentication(
                        scheme: 'com.programmersdiary.walkanddraw')
                    .logout();

                setState(() {
                  _credentials = null;
                });
              },
            ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_credentials == null)
              ElevatedButton(
                onPressed: () async {
                  try {
                    final credentials = await auth0
                        .webAuthentication(
                            scheme: 'com.programmersdiary.walkanddraw')
                        .login();

                    setState(() {
                      _credentials = credentials;
                    });
                  } catch (e) {
                    print('Login error: $e');
                  }
                },
                child: const Text('Log in'),
              )
            else
              ProfileView(user: _credentials!.user),
          ],
        ),
      ),
    );
  }
}

class ProfileView extends StatelessWidget {
  const ProfileView({Key? key, required this.user}) : super(key: key);

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (user.name != null) Text(user.name!),
        if (user.email != null) Text(user.email!),
      ],
    );
  }
}
