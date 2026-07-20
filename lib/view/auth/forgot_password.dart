import 'package:flutter/material.dart';
import '../../core/theme/app_colors_extension.dart';
import '../shared/widgets/buttons.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _linkSent = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(value.trim());
  }

  void _handleSendLink() {
    final email = _emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _errorText = 'Enter a valid email address');
      return;
    }
    setState(() {
      _errorText = null;
      _isLoading = true;
    });
    // Phase 1 prototype — simulated request; Phase 2 will call auth_service.dart
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _linkSent = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: const SimpleAppBar(title: 'Forgot Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              _linkSent ? _buildSentState() : _buildFormState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormState() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: c.primaryLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.lock_reset_rounded, color: c.primary, size: 30),
        ),
        const SizedBox(height: 24),
        Text(
          'Reset your password',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'Enter the email address associated with your account and we\'ll send you a link to reset your password.',
          style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 28),
        Text('Email Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            if (_errorText != null) setState(() => _errorText = null);
          },
          decoration: InputDecoration(
            hintText: 'you@company.com',
            prefixIcon: Icon(Icons.mail_outline_rounded, size: 20, color: c.textMuted),
            errorText: _errorText,
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Send Reset Link',
          onPressed: _handleSendLink,
          isLoading: _isLoading,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.wash(c.primary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: c.primaryDark),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Phase 1 Prototype — no email is actually sent. This simulates the reset flow.',
                  style: TextStyle(fontSize: 12, color: c.primaryDark.withOpacity(0.9), height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSentState() {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: c.primaryLight,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.mark_email_read_rounded, color: c.primary, size: 30),
        ),
        const SizedBox(height: 24),
        Text(
          'Check your email',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary),
        ),
        const SizedBox(height: 6),
        Text(
          'If an account exists for ${_emailController.text.trim()}, a password reset link has been sent.',
          style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Back to Login',
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _linkSent = false),
            child: const Text('Didn\'t get it? Resend'),
          ),
        ),
      ],
    );
  }
}
