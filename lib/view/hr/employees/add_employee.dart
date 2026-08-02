import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';

/// Formats input as a Malaysian mobile number: max 10 digits, dash after
/// the 3rd (e.g. 012-3456789). Strips anything non-numeric as you type.
class MalaysianPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10) digits = digits.substring(0, 10);

    final formatted = digits.length <= 3 ? digits : '${digits.substring(0, 3)}-${digits.substring(3)}';

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _salary = TextEditingController(text: '3500.00');
  String _department = 'Engineering';
  String _jobTitle = 'Employee';
  bool _isSubmitting = false;

  final _departments = ['Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];
  final _jobTitles = ['Employee', 'Senior Engineer', 'Team Lead', 'Manager', 'Designer', 'Analyst', 'Consultant'];

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _initialsFrom(String name) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .take(2)
        .join();
    return initials.isEmpty ? '??' : initials;
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _email.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fill in all required fields'),
          backgroundColor: context.colors.riskHigh,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);

    final tempPassword = _generateTempPassword();
    final employeeCode = 'EMP-${DateTime.now().millisecondsSinceEpoch % 100000}';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-employee',
        body: {
          'email': _email.text.trim(),
          'password': tempPassword,
          'name': _name.text.trim(),
          'employeeCode': employeeCode,
          'userRole': 'employee',
          'jobTitle': _jobTitle,
          'departmentName': _department,
          'avatarInitials': _initialsFrom(_name.text),
          'hireDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
          'baseSalary': double.tryParse(_salary.text.trim()),
        },
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      final data = response.data;
      if (data is Map && data['error'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create account: ${data['error']}'), backgroundColor: context.colors.riskHigh),
        );
        return;
      }

      final emailSent = data is Map && data['emailSent'] == true;
      final emailError = data is Map ? data['emailError'] as String? : null;
      _showSuccessDialog(tempPassword, emailSent, emailError);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create account: $e'), backgroundColor: context.colors.riskHigh),
      );
    }
  }

  void _showSuccessDialog(String tempPassword, bool emailSent, String? emailError) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: BoxDecoration(color: c.primaryLight, shape: BoxShape.circle),
                child: Icon(Icons.check_circle_rounded, color: c.primary, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('Account Created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                emailSent
                    ? 'A welcome email with these login details has been sent to the employee. They can change their password after logging in.'
                    : 'The account was created, but the welcome email could not be sent — share this temporary password with the employee securely instead.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
              ),
              if (!emailSent) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    emailError != null
                        ? 'Email error: $emailError'
                        : 'Email delivery is not configured — set GMAIL_SENDER_EMAIL and GMAIL_APP_PASSWORD as Edge Function secrets.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: c.riskHigh),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: SelectableText(
                  tempPassword,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1),
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Employee')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Personal Info
              _SectionHeader(icon: Icons.person_outline_rounded, title: 'Personal Information'),
              const SizedBox(height: 12),
              _Field(label: 'Full Name *', controller: _name, hint: 'e.g. Ahmad Faizi bin Ismail', icon: Icons.badge_outlined),
              const SizedBox(height: 14),
              _Field(label: 'Email Address *', controller: _email, hint: 'employee@company.com', icon: Icons.mail_outline_rounded, type: TextInputType.emailAddress),
              const SizedBox(height: 14),
              _Field(
                label: 'Phone Number',
                controller: _phone,
                hint: '012-3456789',
                icon: Icons.phone_outlined,
                type: TextInputType.phone,
                inputFormatters: [MalaysianPhoneFormatter()],
              ),
              const SizedBox(height: 24),

              // Role & Department
              _SectionHeader(icon: Icons.work_outline_rounded, title: 'Role & Department'),
              const SizedBox(height: 12),
              _DropdownField(
                label: 'Department',
                value: _department,
                items: _departments,
                icon: Icons.apartment_rounded,
                onChanged: (v) => setState(() => _department = v!),
              ),
              const SizedBox(height: 14),
              _DropdownField(
                label: 'Job Title',
                value: _jobTitle,
                items: _jobTitles,
                icon: Icons.work_history_outlined,
                onChanged: (v) => setState(() => _jobTitle = v!),
              ),
              const SizedBox(height: 24),

              // Payroll
              _SectionHeader(icon: Icons.account_balance_wallet_outlined, title: 'Payroll'),
              const SizedBox(height: 12),
              _Field(
                label: 'Basic Monthly Salary (RM)',
                controller: _salary,
                hint: '3500.00',
                icon: Icons.payments_outlined,
                type: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: c.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: c.infoBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attendance-based deduction rules are applied automatically per the Policy Configuration settings.',
                        style: TextStyle(fontSize: 11.5, color: c.infoBlue, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Device Binding notice
              _SectionHeader(icon: Icons.phone_android_rounded, title: 'Device Binding'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [c.shadowNeutral],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18, color: c.primary),
                        const SizedBox(width: 8),
                        Text('Automatic Device Binding', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The employee\'s device will be bound automatically when they first log in on their mobile device. HR can reset the binding anytime from the Employee Management screen.',
                      style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              PrimaryButton(
                label: 'Create Employee Account',
                icon: Icons.person_add_rounded,
                onPressed: _submit,
                isLoading: _isSubmitting,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.primary),
        const SizedBox(width: 8),
        Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary)),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType type;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: c.textMuted),
          ),
        ),
      ],
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final IconData icon;
  final ValueChanged<String?> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: c.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13.5)))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}