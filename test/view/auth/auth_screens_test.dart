import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/auth/login_screen.dart';
import 'package:monika/view/auth/forgot_password.dart';
import 'package:monika/view/auth/splash_screen.dart';

Widget _wrap(Widget child, {bool dark = false}) =>
    MaterialApp(theme: dark ? AppTheme.dark : AppTheme.light, home: child);

void main() {
  testWidgets('LoginScreen builds in light and dark', (tester) async {
    await tester.pumpWidget(_wrap(const LoginScreen()));
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.pumpWidget(_wrap(const LoginScreen(), dark: true));
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('ForgotPasswordScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const ForgotPasswordScreen()));
    expect(find.text('Reset your password'), findsOneWidget);
  });

  testWidgets('SplashScreen builds and shows MONIKA', (tester) async {
    await tester.pumpWidget(_wrap(const SplashScreen()));
    expect(find.text('MONIKA'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(milliseconds: 2000));
  });
}
