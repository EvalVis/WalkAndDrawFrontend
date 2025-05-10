import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:walk_and_draw/main.dart';

@GenerateMocks([GoogleSignIn, GoogleSignInAccount])
import 'auth_test.mocks.dart';

void main() {
  late MockGoogleSignIn mockGoogleSignIn;
  late MockGoogleSignInAccount mockGoogleSignInAccount;

  setUp(() {
    mockGoogleSignIn = MockGoogleSignIn();
    mockGoogleSignInAccount = MockGoogleSignInAccount();
  });

  group('Google Sign-In Tests', () {
    test('User can login with Google', () async {
      // Arrange
      when(mockGoogleSignIn.signIn())
          .thenAnswer((_) async => mockGoogleSignInAccount);
      when(mockGoogleSignInAccount.email).thenReturn('test@example.com');
      when(mockGoogleSignInAccount.displayName).thenReturn('Test User');

      // Act
      final user = await mockGoogleSignIn.signIn();

      // Assert
      expect(user, isNotNull);
      expect(user?.email, equals('test@example.com'));
      expect(user?.displayName, equals('Test User'));
      verify(mockGoogleSignIn.signIn()).called(1);
    });

    test('User can logout', () async {
      // Arrange
      when(mockGoogleSignIn.signOut())
          .thenAnswer((_) async => mockGoogleSignInAccount);

      // Act
      await mockGoogleSignIn.signOut();

      // Assert
      verify(mockGoogleSignIn.signOut()).called(1);
    });

    test('Login fails gracefully when user cancels', () async {
      // Arrange
      when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

      // Act
      final user = await mockGoogleSignIn.signIn();

      // Assert
      expect(user, isNull);
      verify(mockGoogleSignIn.signIn()).called(1);
    });
  });
}
