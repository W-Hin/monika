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

  testWidgets('HrPeScreen offers Save as Draft alongside Submit, with no Draft badge for a fresh evaluation', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrPeScreen()));
    await tester.pumpAndSettle();
    // The action buttons sit below the fold — ListView only inflates
    // elements within the viewport, so they aren't in the tree at all
    // until scrolled into view.
    await tester.dragUntilVisible(
      find.text('Save as Draft'),
      find.byType(ListView),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save as Draft'), findsOneWidget);
    expect(find.text('Submit'), findsOneWidget);
    // The fixture's employee has no saved evaluation yet, so this starts
    // from fresh template defaults — not a draft, and nothing to discard.
    expect(find.text('Draft'), findsNothing);
    expect(find.text('Discard Draft'), findsNothing);
  });

  testWidgets('HrTrainingScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrTrainingScreen()));
    await tester.pumpAndSettle();
    expect(find.text('All Programs'), findsOneWidget);
  });
}
