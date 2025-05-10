import 'package:google_sign_in/google_sign_in.dart';

class FakeGoogleSignInAccount implements GoogleSignInAccount {
  @override
  final String email;
  @override
  final String displayName;
  @override
  final String id;
  @override
  final String photoUrl;

  FakeGoogleSignInAccount({
    required this.email,
    required this.displayName,
    this.id = 'fake-id',
    this.photoUrl = 'https://example.com/photo.jpg',
  });

  @override
  Future<Map<String, String>> get authHeaders => throw UnimplementedError();

  @override
  Future<void> clearAuthCache() => throw UnimplementedError();

  @override
  Future<GoogleSignInAuthentication> get authentication =>
      throw UnimplementedError();

  @override
  String? get serverAuthCode => null;
}

class FakeGoogleSignIn implements GoogleSignIn {
  GoogleSignInAccount? _currentUser;

  @override
  Future<GoogleSignInAccount?> signIn() async {
    _currentUser = FakeGoogleSignInAccount(
      email: 'test@example.com',
      displayName: 'Test User',
    );
    return _currentUser;
  }

  @override
  Future<GoogleSignInAccount?> signOut() async {
    final user = _currentUser;
    _currentUser = null;
    return user;
  }

  @override
  Future<GoogleSignInAccount?> getCurrentUser() async => _currentUser;

  // Unimplemented methods
  @override
  Future<GoogleSignInAccount?> signInSilently(
          {bool reAuthenticate = false, bool suppressErrors = false}) =>
      throw UnimplementedError();

  @override
  Future<bool> isSignedIn() => throw UnimplementedError();

  @override
  Future<bool> canAccessScopes(List<String> scopes, {String? accessToken}) =>
      throw UnimplementedError();

  @override
  Future<GoogleSignInAccount?> disconnect() => throw UnimplementedError();

  @override
  Future<bool> requestScopes(List<String> scopes) => throw UnimplementedError();

  @override
  List<String> get scopes => throw UnimplementedError();

  @override
  set scopes(List<String> scopes) => throw UnimplementedError();

  @override
  String get clientId => throw UnimplementedError();

  @override
  set clientId(String clientId) => throw UnimplementedError();

  @override
  String get serverClientId => throw UnimplementedError();

  @override
  set serverClientId(String serverClientId) => throw UnimplementedError();

  @override
  String get hostedDomain => throw UnimplementedError();

  @override
  set hostedDomain(String hostedDomain) => throw UnimplementedError();

  @override
  GoogleSignInAccount? get currentUser => _currentUser;

  @override
  String? get forceAccountName => null;

  @override
  set forceAccountName(String? value) => throw UnimplementedError();

  @override
  bool get forceCodeForRefreshToken => false;

  @override
  set forceCodeForRefreshToken(bool value) => throw UnimplementedError();

  @override
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      throw UnimplementedError();

  @override
  SignInOption get signInOption => SignInOption.standard;
}
