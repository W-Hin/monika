import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/view/employee/training/employee_training.dart';
import 'package:monika/view/employee/training/training_detail.dart';

void main() {
  testWidgets('EmployeeTrainingScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeTrainingScreen()));
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('TrainingDetailScreen builds', (tester) async {
    const program = TrainingProgram(
      title: 'Leadership Fundamentals',
      category: 'Leadership',
      description: 'desc',
      isMandatory: false,
      isRecommended: false,
      progress: 0,
      duration: '2 weeks',
      isCompleted: false,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: TrainingDetailScreen(program: program, onUpdate: (_) {}),
    ));
    expect(find.text('Leadership Fundamentals'), findsOneWidget);
  });
}
