// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:monika/main.dart';

void main() {
  testWidgets('Monika App splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MonikaApp());

    // Verify that the splash screen shows 'MONIKA'.
    expect(find.text('MONIKA'), findsOneWidget);

    // Wait for the splash screen's 1400ms transition timer to complete so the test framework doesn't complain about pending timers.
    await tester.pumpAndSettle(const Duration(milliseconds: 2000));
  });
}

