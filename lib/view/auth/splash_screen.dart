import 'package:flutter/material.dart';
import '../../core/theme/app_colors_extension.dart';
import '../../controller/auth_controller.dart';
import '../employee/employee_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final minSplash = Future.delayed(const Duration(milliseconds: 1400));
    await authController.restoreSession();
    await minSplash;
    if (!mounted) return;

    // Always land on the Employee shell on a fresh app open, even for HR
    // admin accounts — "Switch to Admin View" (Profile menu) re-enters
    // HrShell as a fresh push, which reliably loads its own data. Routing
    // straight into a "resumed" HrShell here was the actual bug: on some
    // devices Android keeps the process alive across a backgrounding but
    // the widget tree's cached controller data goes stale, so admin
    // screens showed 0 records until manually navigated away and back.
    // Starting fresh from Employee every time sidesteps that entirely.
    final Widget destination = authController.status == AuthStatus.signedIn ? const EmployeeShell() : const LoginScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, anim, __) => destination,
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Image.asset('lib/img/monika_logo_mark.png', width: 56, height: 56),
            ),
            const SizedBox(height: 24),
            const Text(
              'MONIKA',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Intelligent Mobile HR Management',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}