import 'package:flutter/material.dart';
import 'app_colors.dart';

enum AppHue { primary, infoBlue, amber, purple, riskMedium, riskHigh }

(Color, Color) resolveHue(AppColorsExtension c, AppHue hue) {
  switch (hue) {
    case AppHue.primary: return (c.primary, c.primaryLight);
    case AppHue.infoBlue: return (c.infoBlue, c.infoBlueBg);
    case AppHue.amber: return (c.amber, c.amberBg);
    case AppHue.purple: return (c.purple, c.purpleBg);
    case AppHue.riskMedium: return (c.riskMedium, c.riskMediumBg);
    case AppHue.riskHigh: return (c.riskHigh, c.riskHighBg);
  }
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final bool isDark;
  final Color primary;
  final Color primaryDark;
  final Color primaryLight;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceMuted;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color onPrimary;
  final Color riskLow;
  final Color riskLowBg;
  final Color riskMedium;
  final Color riskMediumBg;
  final Color riskHigh;
  final Color riskHighBg;
  final Color statusApproved;
  final Color statusPending;
  final Color statusRejected;
  final Color infoBlue;
  final Color infoBlueBg;
  final Color purple;
  final Color purpleBg;
  final Color amber;
  final Color amberBg;
  final List<Color> kpiGradient;

  const AppColorsExtension({
    required this.isDark,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceMuted,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.onPrimary,
    required this.riskLow,
    required this.riskLowBg,
    required this.riskMedium,
    required this.riskMediumBg,
    required this.riskHigh,
    required this.riskHighBg,
    required this.statusApproved,
    required this.statusPending,
    required this.statusRejected,
    required this.infoBlue,
    required this.infoBlueBg,
    required this.purple,
    required this.purpleBg,
    required this.amber,
    required this.amberBg,
    required this.kpiGradient,
  });

  /// Elevation for plain neutral cards/rows. On dark, opacity is 0 —
  /// elevation there comes from `surfaceElevated` fill instead (shadows
  /// barely read on near-black backgrounds).
  BoxShadow get shadowNeutral => BoxShadow(
        color: Colors.black.withValues(alpha: isDark ? 0 : 0.05),
        blurRadius: 14,
        offset: const Offset(0, 6),
      );

  /// Glow shadow for hero/emphasis surfaces (defaults to brand green).
  /// More opaque in dark mode, where glows read as intentional brand
  /// presence rather than muddiness (per spec: "this is exactly how
  /// Spotify does it").
  BoxShadow shadowTinted([Color? hue]) => BoxShadow(
        color: (hue ?? primary).withValues(alpha: isDark ? 0.34 : 0.14),
        blurRadius: 20,
        offset: const Offset(0, 10),
      );

  /// Subtle tinted wash of [hue] blended over the current surface — used
  /// for stat-tile backgrounds instead of flat white/dark fills.
  Color wash(Color hue) => Color.alphaBlend(
        hue.withValues(alpha: isDark ? 0.16 : 0.08),
        surface,
      );

  @override
  AppColorsExtension copyWith({bool? isDark}) => AppColorsExtension(
        isDark: isDark ?? this.isDark,
        primary: primary,
        primaryDark: primaryDark,
        primaryLight: primaryLight,
        background: background,
        surface: surface,
        surfaceElevated: surfaceElevated,
        surfaceMuted: surfaceMuted,
        border: border,
        textPrimary: textPrimary,
        textSecondary: textSecondary,
        textMuted: textMuted,
        onPrimary: onPrimary,
        riskLow: riskLow,
        riskLowBg: riskLowBg,
        riskMedium: riskMedium,
        riskMediumBg: riskMediumBg,
        riskHigh: riskHigh,
        riskHighBg: riskHighBg,
        statusApproved: statusApproved,
        statusPending: statusPending,
        statusRejected: statusRejected,
        infoBlue: infoBlue,
        infoBlueBg: infoBlueBg,
        purple: purple,
        purpleBg: purpleBg,
        amber: amber,
        amberBg: amberBg,
        kpiGradient: kpiGradient,
      );

  @override
  AppColorsExtension lerp(covariant AppColorsExtension? other, double t) {
    if (other == null) return this;
    // Discrete switch instead of Color.lerp — light/dark should snap, not
    // fade, when the user flips the Settings switch.
    return t < 0.5 ? this : other;
  }
}

const appColorsExtensionLight = AppColorsExtension(
  isDark: false,
  primary: AppColors.primary,
  primaryDark: AppColors.primaryDark,
  primaryLight: AppColors.primaryLight,
  background: AppColors.background,
  surface: AppColors.surface,
  surfaceElevated: AppColors.surfaceElevated,
  surfaceMuted: AppColors.surfaceMuted,
  border: AppColors.border,
  textPrimary: AppColors.textPrimary,
  textSecondary: AppColors.textSecondary,
  textMuted: AppColors.textMuted,
  onPrimary: AppColors.onPrimary,
  riskLow: AppColors.riskLow,
  riskLowBg: AppColors.riskLowBg,
  riskMedium: AppColors.riskMedium,
  riskMediumBg: AppColors.riskMediumBg,
  riskHigh: AppColors.riskHigh,
  riskHighBg: AppColors.riskHighBg,
  statusApproved: AppColors.statusApproved,
  statusPending: AppColors.statusPending,
  statusRejected: AppColors.statusRejected,
  infoBlue: AppColors.infoBlue,
  infoBlueBg: AppColors.infoBlueBg,
  purple: AppColors.purple,
  purpleBg: AppColors.purpleBg,
  amber: AppColors.amber,
  amberBg: AppColors.amberBg,
  kpiGradient: AppColors.kpiGradient,
);

const appColorsExtensionDark = AppColorsExtension(
  isDark: true,
  primary: AppColorsDark.primary,
  primaryDark: AppColorsDark.primaryDark,
  primaryLight: AppColorsDark.primaryLight,
  background: AppColorsDark.background,
  surface: AppColorsDark.surface,
  surfaceElevated: AppColorsDark.surfaceElevated,
  surfaceMuted: AppColorsDark.surfaceMuted,
  border: AppColorsDark.border,
  textPrimary: AppColorsDark.textPrimary,
  textSecondary: AppColorsDark.textSecondary,
  textMuted: AppColorsDark.textMuted,
  onPrimary: AppColorsDark.onPrimary,
  riskLow: AppColorsDark.riskLow,
  riskLowBg: AppColorsDark.riskLowBg,
  riskMedium: AppColorsDark.riskMedium,
  riskMediumBg: AppColorsDark.riskMediumBg,
  riskHigh: AppColorsDark.riskHigh,
  riskHighBg: AppColorsDark.riskHighBg,
  statusApproved: AppColorsDark.statusApproved,
  statusPending: AppColorsDark.statusPending,
  statusRejected: AppColorsDark.statusRejected,
  infoBlue: AppColorsDark.infoBlue,
  infoBlueBg: AppColorsDark.infoBlueBg,
  purple: AppColorsDark.purple,
  purpleBg: AppColorsDark.purpleBg,
  amber: AppColorsDark.amber,
  amberBg: AppColorsDark.amberBg,
  kpiGradient: AppColorsDark.kpiGradient,
);

extension AppColorsContext on BuildContext {
  AppColorsExtension get colors => Theme.of(this).extension<AppColorsExtension>()!;
}
