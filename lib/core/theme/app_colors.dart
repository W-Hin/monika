import 'package:flutter/material.dart';

/// MONIKA Design System
/// Primary: Spotify-inspired green (#1DB954) — energetic, trustworthy, modern
/// Secondary: Soft off-white surfaces for a clean, minimal HR-tech feel
/// Accents: Status colors for risk levels, leave states, and KPI bands
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF1DB954);
  static const Color primaryDark = Color(0xFF169C46);
  static const Color primaryLight = Color(0xFFE6F9EE);

  // Neutrals / Surfaces
  static const Color background = Color(0xFFF7F9F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF1F4F2);
  static const Color border = Color(0xFFE3E8E5);

  // Text
  static const Color textPrimary = Color(0xFF15211B);
  static const Color textSecondary = Color(0xFF5B6B63);
  static const Color textMuted = Color(0xFF93A39B);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Status — Risk Classification
  static const Color riskLow = Color(0xFF1DB954);
  static const Color riskLowBg = Color(0xFFE6F9EE);
  static const Color riskMedium = Color(0xFFE6A23C);
  static const Color riskMediumBg = Color(0xFFFDF3E3);
  static const Color riskHigh = Color(0xFFE5484D);
  static const Color riskHighBg = Color(0xFFFCE8E8);

  // Status — Leave / Approval
  static const Color statusApproved = Color(0xFF1DB954);
  static const Color statusPending = Color(0xFFE6A23C);
  static const Color statusRejected = Color(0xFFE5484D);

  // Misc accents
  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBlueBg = Color(0xFFEAF2FE);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color purpleBg = Color(0xFFF1EBFD);
  static const Color amber = Color(0xFFE6A23C);
  static const Color amberBg = Color(0xFFFDF3E3);

  static const List<Color> kpiGradient = [Color(0xFF1DB954), Color(0xFF14834A)];
}

class AppRadius {
  AppRadius._();
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 100;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}