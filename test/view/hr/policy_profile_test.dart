import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/main.dart';
import 'package:monika/view/hr/policy/policy_config.dart';
import 'package:monika/view/hr/profile/hr_profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('PolicyConfigScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const PolicyConfigScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Attendance Policy'), findsOneWidget);
  });

  testWidgets('HrProfileScreen builds and shows a Dark Mode switch', (tester) async {
    await themeController.load();
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrProfileScreen()));
    await tester.pumpAndSettle();

    // Scroll until the Settings section is visible — a fixed-offset drag
    // gets thrown off whenever the page above it grows or shrinks.
    await tester.dragUntilVisible(
      find.text('Dark Mode'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Toggling the Dark Mode switch calls themeController.toggle()', (tester) async {
    await themeController.load();
    final before = themeController.value;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrProfileScreen()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('Dark Mode'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(themeController.value, isNot(before));
  });
}
