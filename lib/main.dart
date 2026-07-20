import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'view/auth/splash_screen.dart';

final themeController = ThemeController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await themeController.load();

  // Lock to portrait orientation — MONIKA is a mobile HR app
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar styling for the very first frame — matches the theme that
  // was just loaded from prefs (avoids a light-mode flash when launching
  // straight into dark mode). AnnotatedRegion in MonikaApp takes over for
  // every change after this.
  SystemChrome.setSystemUIOverlayStyle(_overlayStyleFor(themeController.value == ThemeMode.dark));

  runApp(const MonikaApp());
}

/// Status bar / nav bar icon+background style for the given theme.
/// Transparent status bar so our green gradients show through; nav bar
/// matches the scaffold background so it doesn't clash with the theme.
SystemUiOverlayStyle _overlayStyleFor(bool isDark) {
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
    systemNavigationBarColor: isDark ? AppColorsDark.background : Colors.white,
    systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
  );
}

class MonikaApp extends StatelessWidget {
  const MonikaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: _overlayStyleFor(mode == ThemeMode.dark),
        child: MaterialApp(
          title: 'MONIKA',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const SplashScreen(),
        ),
      ),
    );
  }
}