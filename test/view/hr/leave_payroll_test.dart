import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/leave/leave_balances.dart';
import 'package:monika/view/hr/payroll/hr_payroll.dart';

void main() {
  testWidgets('HrLeaveBalancesScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrLeaveBalancesScreen()));
    await tester.pumpAndSettle();
    // The header includes a live count suffix, e.g. "(3)" — not fixed text.
    expect(find.textContaining('Employee Leave Balances'), findsOneWidget);
  });

  testWidgets('HrPayrollScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrPayrollScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Per-Employee Summary'), findsOneWidget);
  });
}
