import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/view/employee/leave/employee_leave.dart';
import 'package:monika/view/employee/leave/leave_apply.dart';

void main() {
  testWidgets('EmployeeLeaveScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeLeaveScreen()));
    await tester.pumpAndSettle();
    expect(find.text('My Applications'), findsOneWidget);
  });

  group('LeaveApplicationTile', () {
    LeaveApplication app(LeaveStatus status) => LeaveApplication(
          dbId: 1,
          id: 'LV-1',
          employeeName: 'Test Employee',
          leaveType: 'Annual Leave',
          startDate: '1 Dec 2026',
          endDate: '1 Dec 2026',
          days: 1,
          reason: 'Personal matters',
          status: status,
        );

    Future<void> pump(WidgetTester tester, LeaveStatus status, VoidCallback onCancel) =>
        tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: LeaveApplicationTile(app: app(status), onCancel: onCancel)),
        ));

    testWidgets('a pending application can be cancelled', (tester) async {
      var cancelled = false;
      await pump(tester, LeaveStatus.pending, () => cancelled = true);
      await tester.tap(find.text('Cancel Application'));
      expect(cancelled, isTrue);
    });

    testWidgets('a decided application cannot be cancelled', (tester) async {
      await pump(tester, LeaveStatus.approved, () {});
      expect(find.text('Cancel Application'), findsNothing);
    });

    testWidgets('a cancelled application shows its status', (tester) async {
      await pump(tester, LeaveStatus.cancelled, () {});
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancel Application'), findsNothing);
    });
  });

  testWidgets('LeaveApplyScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const LeaveApplyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Leave Type'), findsOneWidget);
  });
}
