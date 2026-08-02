import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors_extension.dart';
import '../shared/widgets/buttons.dart';
import 'set_password_screen.dart';

class VerifyResetCodeScreen extends StatefulWidget {
  final String email;

  const VerifyResetCodeScreen({super.key, required this.email});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorText = 'Enter the 6-digit code from your email');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: widget.email,
        token: code,
        type: OtpType.recovery,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const SetPasswordScreen(mode: SetPasswordMode.forgotPasswordRecovery)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Invalid or expired code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      appBar: const SimpleAppBar(title: 'Enter Reset Code'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.pin_outlined, color: c.primary, size: 30),
              ),
              const SizedBox(height: 24),
              Text('Enter your code', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary)),
              const SizedBox(height: 6),
              Text(
                'We sent a 6-digit code to ${widget.email}. Enter it below.',
                style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),
              Text('Reset Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  hintText: '123456',
                  prefixIcon: Icon(Icons.pin_outlined, size: 20, color: c.textMuted),
                  errorText: _errorText,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Verify Code',
                onPressed: _verify,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
