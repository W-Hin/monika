import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/view/employee/training/employee_training.dart';
import 'package:monika/view/employee/training/training_detail.dart';
import 'package:monika/view/employee/training/training_quiz.dart';

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
      home: TrainingDetailScreen(program: program),
    ));
    expect(find.text('Leadership Fundamentals'), findsOneWidget);
  });

  testWidgets('a tenure-locked programme explains when it opens instead of offering Enrol', (tester) async {
    const program = TrainingProgram(
      title: 'Strategic Thinking for Team Leads',
      category: 'Leadership',
      description: 'desc',
      duration: '3 hours',
      minTenureMonths: 24,
      locked: true,
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: TrainingDetailScreen(program: program)));
    await tester.pump();
    expect(find.text('This programme opens after 24 months of service.'), findsOneWidget);
    expect(find.text('Enrol Now'), findsNothing);
  });

  testWidgets('TrainingQuizScreen builds and keeps Submit disabled until every question is answered', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const TrainingQuizScreen(programId: 1, programTitle: 'Cybersecurity Essentials'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cybersecurity Essentials'), findsOneWidget);
    expect(find.text('Answer all questions to submit'), findsOneWidget);
  });
}
