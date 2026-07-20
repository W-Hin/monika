import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/payroll/payroll.dart';
import 'package:monika/view/employee/pe/pe_detail.dart';

void main() {
  testWidgets('PayrollScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const PayrollScreen()));
    expect(find.text('Deduction Breakdown'), findsOneWidget);
  });

  testWidgets('PeDetailScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const PeDetailScreen()));
    expect(find.text('KPI Breakdown'), findsOneWidget);
  });
}
