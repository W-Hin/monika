// test/core/app_colors_extension_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_colors_extension.dart';

void main() {
  test('light and dark extensions carry the correct isDark flag and primary color', () {
    expect(appColorsExtensionLight.isDark, false);
    expect(appColorsExtensionDark.isDark, true);
    expect(appColorsExtensionLight.primary, const Color(0xFF1DB954));
    expect(appColorsExtensionDark.primary, const Color(0xFF1DB954));
  });

  test('shadowTinted is more opaque in dark mode (glows read fine on dark; per spec)', () {
    final lightAlpha = appColorsExtensionLight.shadowTinted().color.a;
    final darkAlpha = appColorsExtensionDark.shadowTinted().color.a;
    expect(darkAlpha, greaterThan(lightAlpha));
  });

  test('shadowNeutral has zero opacity in dark mode (elevation via fill, not shadow)', () {
    expect(appColorsExtensionDark.shadowNeutral.color.a, 0);
    expect(appColorsExtensionLight.shadowNeutral.color.a, greaterThan(0));
  });

  testWidgets('context.colors resolves the registered extension', (tester) async {
    late BuildContext capturedContext;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(extensions: [appColorsExtensionLight]),
      home: Builder(builder: (context) {
        capturedContext = context;
        return const SizedBox();
      }),
    ));
    expect(capturedContext.colors.isDark, false);
  });
}
