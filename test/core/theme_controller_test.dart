import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:monika/core/theme/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to light mode when nothing persisted', () async {
    final controller = ThemeController();
    await controller.load();
    expect(controller.value, ThemeMode.light);
  });

  test('toggle flips mode and persists it', () async {
    final controller = ThemeController();
    await controller.load();
    await controller.toggle();
    expect(controller.value, ThemeMode.dark);

    // A fresh controller reading the same persisted prefs picks up dark mode.
    final reloaded = ThemeController();
    await reloaded.load();
    expect(reloaded.value, ThemeMode.dark);
  });

  test('toggling twice returns to light and persists that too', () async {
    final controller = ThemeController();
    await controller.load();
    await controller.toggle();
    await controller.toggle();
    expect(controller.value, ThemeMode.light);

    final reloaded = ThemeController();
    await reloaded.load();
    expect(reloaded.value, ThemeMode.light);
  });
}
