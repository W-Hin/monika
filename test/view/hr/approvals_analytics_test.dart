import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/approvals/hr_approvals.dart';
import 'package:monika/view/hr/analytics/hr_analytics.dart';
import 'package:monika/view/hr/analytics/anomaly_detail.dart';

void main() {
  testWidgets('HrApprovalsScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrApprovalsScreen()));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pending'), findsWidgets);
  });

  testWidgets('HrAnalyticsScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrAnalyticsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Weekly Attendance Trend'), findsOneWidget);
  });

  testWidgets('AnomalyDetailScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AnomalyDetailScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Anomaly & Violation Feed'), findsOneWidget);
  });

  testWidgets('a flagged clock-in can be reverted, with a confirmation step first', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AnomalyDetailScreen()));
    await tester.pumpAndSettle();

    final revert = find.text('Revert (Dispute Investigation Found Invalid)');
    await tester.dragUntilVisible(revert, find.byType(ListView), const Offset(0, -200));
    await tester.tap(revert);
    await tester.pumpAndSettle();
    expect(find.text('Revert This Violation?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Revert This Violation?'), findsNothing);
  });

  testWidgets('a violation that was already reverted cannot be reverted again', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AnomalyDetailScreen()));
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(find.text('Reverted'), find.byType(ListView), const Offset(0, -200));
    // Two flagged clock-ins in the feed, only the unreverted one offers Revert.
    expect(find.text('Revert (Dispute Investigation Found Invalid)', skipOffstage: false), findsOneWidget);
  });
}
