import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/main.dart';
import 'package:monika/view/employee/profile/employee_profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('EmployeeProfileScreen builds and shows a Dark Mode switch', (tester) async {
    await themeController.load();
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const EmployeeProfileScreen()),
    );
    await tester.pumpAndSettle();

    // Scroll to bring Settings section into view
    final listViewFinder = find.byType(ListView);
    await tester.drag(listViewFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Dark Mode'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Toggling the Dark Mode switch calls themeController.toggle()', (tester) async {
    await themeController.load();
    final before = themeController.value;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeProfileScreen()));
    await tester.pumpAndSettle();

    // Scroll to bring Settings section into view
    final listViewFinder = find.byType(ListView);
    await tester.drag(listViewFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(themeController.value, isNot(before));
  });
}
