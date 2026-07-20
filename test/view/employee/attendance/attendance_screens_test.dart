import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/attendance/employee_attendance.dart';
import 'package:monika/view/employee/attendance/attendance_history.dart';
import 'package:monika/view/employee/attendance/clock_in.dart';
import 'package:monika/view/employee/attendance/clock_out.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('EmployeeAttendanceScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const EmployeeAttendanceScreen()));
    expect(find.text('IoT Verification Layers'), findsOneWidget);
  });

  testWidgets('AttendanceHistoryScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const AttendanceHistoryScreen()));
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('ClockInScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const ClockInScreen()));
    expect(find.text('Triple-Layer Verification'), findsOneWidget);
  });

  testWidgets('ClockOutScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const ClockOutScreen()));
    expect(find.text('End of Day Clock-Out'), findsOneWidget);
  });
}
