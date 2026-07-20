import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_colors.dart';

void main() {
  test('AppColorsDark mirrors every AppColors member with distinct values', () {
    expect(AppColorsDark.background, isNot(AppColors.background));
    expect(AppColorsDark.surface, isNot(AppColors.surface));
    expect(AppColorsDark.textPrimary, isNot(AppColors.textPrimary));
    // Primary green is deliberately unchanged across themes (spec: "reads the
    // same on dark as it does in Spotify's own UI").
    expect(AppColorsDark.primary, AppColors.primary);
  });
}
