import 'package:flutter/material.dart';
import '../../core/theme/app_colors_extension.dart';
import '../shared/widgets/buttons.dart';
import '../../controller/auth_controller.dart';
import '../employee/employee_shell.dart';
import 'forgot_password.dart';
import 'set_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    final success = await authController.signIn(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(authController.errorMessage ?? 'Login failed. Check your credentials.')),
      );
      return;
    }

    if (authController.mustChangePassword) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetPasswordScreen(mode: SetPasswordMode.mandatoryFirstLogin)),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const EmployeeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Image.asset('lib/img/monika_logo_mark.png', height: 64)),
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Log in to continue to MONIKA',
                style: TextStyle(fontSize: 14.5, color: c.textSecondary),
              ),
              const SizedBox(height: 28),

              Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: 'you@company.com',
                  prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: c.textMuted),
                ),
              ),
              const SizedBox(height: 18),

              Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: c.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 20,
                      color: c.textMuted,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                  ),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: 12),

              PrimaryButton(
                label: 'Log In',
                onPressed: _handleLogin,
                isLoading: _isLoading,
              ),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
