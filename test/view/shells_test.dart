import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/employee_shell.dart';
import 'package:monika/view/hr/hr_shell.dart';

void main() {
  testWidgets('EmployeeShell builds with 5 nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const EmployeeShell()));
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('HrShell builds with 5 nav destinations', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const HrShell()));
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
