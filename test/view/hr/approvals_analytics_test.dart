import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/hr/approvals/hr_approvals.dart';
import 'package:monika/view/hr/analytics/hr_analytics.dart';
import 'package:monika/view/hr/analytics/anomaly_detail.dart';

void main() {
  testWidgets('HrApprovalsScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrApprovalsScreen()));
    expect(find.textContaining('Pending'), findsWidgets);
  });

  testWidgets('HrAnalyticsScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const HrAnalyticsScreen()));
    expect(find.text('Weekly Attendance Trend'), findsOneWidget);
  });

  testWidgets('AnomalyDetailScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const AnomalyDetailScreen()));
    expect(find.text('Anomaly & Violation Feed'), findsOneWidget);
  });
}
