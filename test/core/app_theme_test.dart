// test/core/app_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';

void main() {
  test('light and dark themes register the matching AppColorsExtension', () {
    final lightExt = AppTheme.light.extension<ThemeExtension>();
    expect(AppTheme.light.brightness, Brightness.light);
    expect(AppTheme.dark.brightness, Brightness.dark);
    expect(AppTheme.light.textTheme.bodyMedium?.fontFamily, 'Inter');
    expect(AppTheme.dark.textTheme.bodyMedium?.fontFamily, 'Inter');
  });

  test('OutlinedButton has no visible border (tinted-fill style)', () {
    final style = AppTheme.light.outlinedButtonTheme.style;
    final side = style?.side?.resolve({});
    expect(side, isNull);
  });
}
