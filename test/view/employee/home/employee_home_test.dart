import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/home/employee_home.dart';

void main() {
  testWidgets('EmployeeHomeScreen builds in light and dark', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeHomeScreen()));
    expect(find.text('Quick Actions'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const EmployeeHomeScreen()));
    expect(find.text('Quick Actions'), findsOneWidget);
  });
}
