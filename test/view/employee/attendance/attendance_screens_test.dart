import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/employee/attendance/employee_attendance.dart';
import 'package:monika/view/employee/attendance/attendance_history.dart';
import 'package:monika/view/employee/attendance/clock_in.dart';
import 'package:monika/view/employee/attendance/clock_out.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: child);

void main() {
  testWidgets('EmployeeAttendanceScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const EmployeeAttendanceScreen()));
    // Not pumpAndSettle: this screen's live GPS/WiFi/device checks call real
    // geolocator/network_info_plus/device_info_plus platform channels, which
    // never resolve in a plain `flutter test` VM (no platform side attached)
    // — pumpAndSettle would wait for that forever. A bounded pump is enough
    // to let the Supabase-backed policy/history loads settle, which is all
    // this static header text depends on.
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('IoT Verification Layers'), findsOneWidget);
  });

  testWidgets('AttendanceHistoryScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const AttendanceHistoryScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Records — ${DateFormat('MMMM yyyy').format(DateTime.now())}'), findsOneWidget);
  });

  testWidgets('ClockInScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const ClockInScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Triple-Layer Verification'), findsOneWidget);
  });

  testWidgets('ClockOutScreen builds', (tester) async {
    await tester.pumpWidget(_wrap(const ClockOutScreen()));
    await tester.pumpAndSettle();
    expect(find.text('End of Day Clock-Out'), findsOneWidget);
  });
}
