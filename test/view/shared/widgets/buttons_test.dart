import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/shared/widgets/buttons.dart';

void main() {
  testWidgets('HomeAppBar renders in dark theme without throwing', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        appBar: const HomeAppBar(greeting: 'Good morning,', name: 'Sarah', initials: 'SL'),
        body: const SizedBox(),
      ),
    ));
    expect(find.text('Sarah'), findsOneWidget);
  });
}
