import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/leave/employee_leave.dart';
import 'package:monika/view/employee/leave/leave_apply.dart';

void main() {
  testWidgets('EmployeeLeaveScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeLeaveScreen()));
    expect(find.text('My Applications'), findsOneWidget);
  });

  testWidgets('LeaveApplyScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LeaveApplyScreen()));
    expect(find.text('Leave Type'), findsOneWidget);
  });
}
