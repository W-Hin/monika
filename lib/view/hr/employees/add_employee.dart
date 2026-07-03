import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';

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

  void _submit() {
    if (_name.text.isEmpty || _email.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: AppColors.riskHigh,
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('Account Created', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'A setup invitation has been sent to the employee\'s email address. They can now register their device and set a password.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _Field(label: 'Phone Number', controller: _phone, hint: '+60 12-345 6789', icon: Icons.phone_outlined, type: TextInputType.phone),
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
                decoration: BoxDecoration(color: AppColors.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: AppColors.infoBlue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attendance-based deduction rules are applied automatically per the Policy Configuration settings.',
                        style: TextStyle(fontSize: 11.5, color: AppColors.infoBlue, height: 1.4),
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.link_rounded, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Automatic Device Binding', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'The employee\'s device will be bound automatically when they first log in on their mobile device. HR can reset the binding anytime from the Employee Management screen.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
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
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
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

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.type = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.textMuted),
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