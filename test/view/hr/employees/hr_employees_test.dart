import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/core/data/dummy_data.dart';
import 'package:monika/view/hr/employees/hr_employees.dart';
import 'package:monika/view/hr/employees/add_employee.dart';
import 'package:monika/view/hr/employees/employee_detail.dart';

void main() {
  testWidgets('HrEmployeesScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrEmployeesScreen()));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('AddEmployeeScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AddEmployeeScreen()));
    expect(find.text('Personal Information'), findsOneWidget);
  });

  testWidgets('EmployeeDetailScreen builds', (tester) async {
    final employee = DummyData.teamOverview.first;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: EmployeeDetailScreen(employee: employee, onUpdate: (_) {}),
    ));
    expect(find.text('Account Information'), findsOneWidget);
  });
}
