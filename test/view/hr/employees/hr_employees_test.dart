import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/core/data/dummy_data.dart';
import 'package:monika/view/hr/employees/hr_employees.dart';
import 'package:monika/view/hr/employees/add_employee.dart';
import 'package:monika/view/hr/employees/employee_detail.dart';
import 'package:monika/view/hr/employees/bulk_import_employees.dart';

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

  group('BulkImportEmployeesScreen', () {
    testWidgets('builds and shows the paste field', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const BulkImportEmployeesScreen()));
      await tester.pump();
      expect(find.text('Paste CSV'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('flags a row with a bad email format instead of importing it', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const BulkImportEmployeesScreen()));
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'name,email,department\nAhmad Faizi,not-an-email,Engineering',
      );
      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.textContaining('Invalid email format'), findsOneWidget);
      expect(find.text('No Valid Rows to Import'), findsOneWidget);
    });

    testWidgets('rejects every row sharing a duplicate email in the same paste', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const BulkImportEmployeesScreen()));
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'name,email,department\n'
        'Ahmad Faizi,dupe@company.com,Engineering\n'
        'Siti Aisyah,dupe@company.com,Engineering',
      );
      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.textContaining('Duplicate email'), findsNWidgets(2));
    });

    testWidgets('a mix of one valid and one invalid row only counts the valid one as ready', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const BulkImportEmployeesScreen()));
      await tester.pump();

      await tester.enterText(
        find.byType(TextField),
        'name,email,department\n'
        'Ahmad Faizi,ahmad@company.com,Engineering\n'
        ',missing-name@company.com,Engineering',
      );
      await tester.tap(find.text('Preview'));
      await tester.pump();

      expect(find.text('Preview — 1 ready, 1 with errors'), findsOneWidget);
      expect(find.text('Import 1 Employee'), findsOneWidget);
    });
  });
}
