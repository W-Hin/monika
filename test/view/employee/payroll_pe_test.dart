import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/payroll/payroll.dart';
import 'package:monika/view/employee/pe/pe_detail.dart';

void main() {
  testWidgets('PayrollScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const PayrollScreen()));
    await tester.pumpAndSettle();
    // No auth session in tests, so there's no "current user" payroll row —
    // this is the correct not-signed-in/no-data empty state, not a stale
    // dummy-data assertion.
    expect(find.text('Not generated yet'), findsOneWidget);
  });

  testWidgets('PeDetailScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const PeDetailScreen()));
    await tester.pumpAndSettle();
    expect(find.text('No evaluation yet'), findsOneWidget);
  });
}
