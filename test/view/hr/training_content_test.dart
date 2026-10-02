import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/training/training_content_editor.dart';

void main() {
  testWidgets('TrainingContentEditorScreen lets HR add lessons and quiz questions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const TrainingContentEditorScreen(programId: 1, programTitle: 'Cybersecurity Essentials'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add Lesson'), findsOneWidget);
    // Below the fold: ListView only builds what is in the viewport.
    await tester.dragUntilVisible(find.text('Add Question'), find.byType(ListView), const Offset(0, -300));
    expect(find.text('Add Question'), findsOneWidget);
    expect(find.text('Pass mark'), findsOneWidget);
  });

  testWidgets('Add Question requires a question and filled options before saving', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const TrainingContentEditorScreen(programId: 1, programTitle: 'Cybersecurity Essentials'),
    ));
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(find.text('Add Question'), find.byType(ListView), const Offset(0, -300));
    await tester.tap(find.text('Add Question'));
    await tester.pumpAndSettle();
    // The sheet's primary button shares the label with the trigger.
    final save = find.widgetWithText(ElevatedButton, 'Add Question');
    await tester.ensureVisible(save); // the sheet scrolls; the button starts off-screen
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Enter the question.'), findsOneWidget);
  });
}
