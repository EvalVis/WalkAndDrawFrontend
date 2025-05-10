import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:walk_and_draw/main.dart';
import 'fakes/fake_google_sign_in_account.dart';

void main() {
  late FakeGoogleSignIn fakeGoogleSignIn;
  late App app;

  setUp(() {
    fakeGoogleSignIn = FakeGoogleSignIn();
    app = App(googleSignIn: fakeGoogleSignIn);
  });

  group('App Authentication Tests', () {
    testWidgets('Shows login screen when user is not signed in',
        (WidgetTester tester) async {
      await tester.pumpWidget(app);

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
    });

    testWidgets('Shows main app after successful login',
        (WidgetTester tester) async {
      await tester.pumpWidget(app);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      expect(find.text('Walk and Draw'), findsOneWidget);
      expect(find.text('test@example.com'), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);
    });

    testWidgets('Shows login screen after logout', (WidgetTester tester) async {
      await tester.pumpWidget(app);
      await tester.tap(find.text('Sign in with Google'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.logout));
      await tester.pumpAndSettle();

      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.byIcon(Icons.g_mobiledata), findsOneWidget);
    });
  });
}
