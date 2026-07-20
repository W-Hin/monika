import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/view/shared/widgets/common_widgets.dart';

Widget _wrap(Widget child) => MaterialApp(theme: AppTheme.light, home: Scaffold(body: child));

void main() {
  testWidgets('AppCard has no Border and a non-null BoxShadow', (tester) async {
    await tester.pumpWidget(_wrap(const AppCard(child: Text('hi'))));
    final container = tester.widget<Container>(find.byType(Container).first);
    final decoration = container.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.boxShadow, isNotNull);
    expect(decoration.boxShadow, isNotEmpty);
  });

  testWidgets('StatCard renders value with tabular figures', (tester) async {
    await tester.pumpWidget(_wrap(const StatCard(
      label: 'Attendance',
      value: '96%',
      icon: Icons.check,
      iconColor: Colors.green,
      iconBg: Colors.white,
    )));
    final text = tester.widget<Text>(find.text('96%'));
    expect(text.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
  });

  testWidgets('ListRow separates children with hairline dividers, no per-child border', (tester) async {
    await tester.pumpWidget(_wrap(const ListRow(children: [
      Text('Row A'),
      Text('Row B'),
      Text('Row C'),
    ])));
    expect(find.text('Row A'), findsOneWidget);
    expect(find.text('Row C'), findsOneWidget);
    // 2 dividers between 3 rows
    expect(find.byType(Divider), findsNWidgets(2));
  });
}
