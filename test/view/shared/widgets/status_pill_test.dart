import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/view/shared/widgets/status_pill.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('StatusDot.attendance(context, onTime) renders a 6px dot and "On Time" label', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => StatusDot.attendance(context, AttendanceStatus.onTime),
    )));
    expect(find.text('On Time'), findsOneWidget);
    final dotFinder = find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 6);
    expect(dotFinder, findsOneWidget);
  });

  testWidgets('StatusDot.risk(context, high) renders "High Risk"', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => StatusDot.risk(context, RiskLevel.high),
    )));
    expect(find.text('High Risk'), findsOneWidget);
  });
}
