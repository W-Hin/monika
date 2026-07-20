import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/home/hr_home.dart';

Widget _wrap(Widget child, {bool dark = false}) =>
    MaterialApp(theme: dark ? AppTheme.dark : AppTheme.light, home: child);

void main() {
  testWidgets('HrHomeScreen builds in light and dark', (tester) async {
    await tester.pumpWidget(_wrap(const HrHomeScreen()));
    // Just verify the screen builds without errors
    expect(find.byType(HrHomeScreen), findsOneWidget);
    await tester.pumpWidget(_wrap(const HrHomeScreen(), dark: true));
    expect(find.byType(HrHomeScreen), findsOneWidget);
  });
}
