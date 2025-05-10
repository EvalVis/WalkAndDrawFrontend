import 'package:google_sign_in/google_sign_in.dart';

class FakeGoogleSignIn implements GoogleSignIn, GoogleSignInAccount {
  final GoogleSignInAccount? _currentUser;
  @override
  final String email;
  @override
  final String displayName;
  @override
  final String id;
  @override
  final String photoUrl;

  FakeGoogleSignIn({
    this.email = 'test@example.com',
    this.displayName = 'Test User',
    this.id = 'fake-id',
    this.photoUrl = 'https://example.com/photo.jpg',
    GoogleSignInAccount? currentUser,
  }) : _currentUser = currentUser;

  @override
  String? get clientId => null;

  @override
  String? get forceAccountName => null;

  @override
  bool get forceCodeForRefreshToken => false;

  @override
  String? get hostedDomain => null;

  @override
  List<String> get scopes => [];

  @override
  String? get serverClientId => null;

  @override
  Future<GoogleSignInAccount?> signIn() async => this;

  @override
  Future<GoogleSignInAccount?> signOut() async => null;

  @override
  GoogleSignInAccount? get currentUser => _currentUser;

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
  Stream<GoogleSignInAccount?> get onCurrentUserChanged =>
      throw UnimplementedError();

  @override
  SignInOption get signInOption => SignInOption.standard;

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
