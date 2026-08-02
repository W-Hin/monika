import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_colors_extension.dart';
import '../../controller/auth_controller.dart';
import '../shared/widgets/buttons.dart';
import '../employee/employee_shell.dart';

enum SetPasswordMode { mandatoryFirstLogin, voluntary, forgotPasswordRecovery }

class SetPasswordScreen extends StatefulWidget {
  final SetPasswordMode mode;

  const SetPasswordScreen({super.key, required this.mode});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _errorText;

  bool get _requiresCurrentPassword => widget.mode == SetPasswordMode.voluntary;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (_requiresCurrentPassword && currentPassword.isEmpty) {
      setState(() => _errorText = 'Enter your current password');
      return;
    }
    if (newPassword.length < 8) {
      setState(() => _errorText = 'Password must be at least 8 characters');
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorText = 'Passwords do not match');
      return;
    }

    setState(() {
      _errorText = null;
      _isLoading = true;
    });

    try {
      if (_requiresCurrentPassword) {
        final email = Supabase.instance.client.auth.currentUser?.email;
        if (email == null) {
          throw Exception('No active session');
        }
        try {
          await Supabase.instance.client.auth.signInWithPassword(email: email, password: currentPassword);
        } on AuthException {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _errorText = 'Current password is incorrect';
          });
          return;
        }
      }

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      if (!mounted) return;

      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'must_change_password': false})
            .eq('id', uid);
      }
      if (!mounted) return;

      switch (widget.mode) {
        case SetPasswordMode.mandatoryFirstLogin:
        case SetPasswordMode.forgotPasswordRecovery:
          if (widget.mode == SetPasswordMode.forgotPasswordRecovery) {
            await authController.restoreSession();
            if (!mounted) return;
          }
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const EmployeeShell()),
            (route) => false,
          );
          break;
        case SetPasswordMode.voluntary:
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✓ Password changed successfully')),
          );
          Navigator.of(context).pop();
          break;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorText = 'Could not update password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mandatory = widget.mode == SetPasswordMode.mandatoryFirstLogin;

    return Scaffold(
      backgroundColor: c.background,
      appBar: mandatory
          ? null
          : const SimpleAppBar(title: 'Set New Password'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(18)),
                child: Icon(Icons.lock_reset_rounded, color: c.primary, size: 30),
              ),
              const SizedBox(height: 24),
              Text(
                mandatory ? 'Set your password' : 'Set a new password',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                mandatory
                    ? 'For your security, you must set your own password before continuing.'
                    : 'Choose a new password for your account.',
                style: TextStyle(fontSize: 14.5, color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),

              if (_requiresCurrentPassword) ...[
                Text('Current Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrent,
                  onChanged: (_) {
                    if (_errorText != null) setState(() => _errorText = null);
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your current password',
                    prefixIcon: Icon(Icons.lock_person_outlined, size: 20, color: c.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.textMuted),
                      onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],

              Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _newPasswordController,
                obscureText: _obscureNew,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  hintText: 'At least 8 characters',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: c.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.textMuted),
                    onPressed: () => setState(() => _obscureNew = !_obscureNew),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  hintText: 'Re-enter your new password',
                  prefixIcon: Icon(Icons.lock_outline_rounded, size: 20, color: c.textMuted),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: c.textMuted),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  errorText: _errorText,
                ),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                label: mandatory ? 'Set Password & Continue' : 'Save New Password',
                onPressed: _submit,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
