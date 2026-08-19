import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/pe/hr_pe.dart';
import 'package:monika/view/hr/training/hr_training.dart';

void main() {
  testWidgets('HrPeScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrPeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('KPI Scoring'), findsOneWidget);
  });

  testWidgets('HrTrainingScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrTrainingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('All Programs'), findsOneWidget);
  });
}
