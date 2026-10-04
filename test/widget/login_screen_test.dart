import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nbro_mobile_application/presentation/screens/auth/login_screen.dart';

void main() {
  testWidgets('login screen displays its controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });

  testWidgets('empty login displays a validation message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Sign In'));
    await tester.pump();

    expect(find.text('Please fill in all fields'), findsOneWidget);
  });
}
