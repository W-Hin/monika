import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/shared/company_calendar.dart';
import 'package:monika/view/shared/notification.dart';
import 'package:monika/view/shared/settings_placeholder.dart';

void main() {
  testWidgets('CompanyCalendarScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const CompanyCalendarScreen()));
    expect(find.text('Public Holidays'), findsOneWidget);
  });

  testWidgets('NotificationScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const NotificationScreen()));
    expect(find.text('Notifications'), findsOneWidget);
  });

  testWidgets('SettingsPlaceholderScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const SettingsPlaceholderScreen(title: 'Help & Support', icon: Icons.help_outline_rounded),
    ));
    expect(find.text('Help & Support coming soon'), findsOneWidget);
  });
}
