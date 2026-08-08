import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../main.dart';
import '../../../controller/auth_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../auth/login_screen.dart';
import '../../auth/set_password_screen.dart';
import '../../hr/hr_shell.dart';
import '../../shared/company_calendar.dart';
import '../../shared/settings_placeholder.dart';
import '../pe/pe_detail.dart';

class EmployeeProfileScreen extends StatefulWidget {
  const EmployeeProfileScreen({super.key});

  @override
  State<EmployeeProfileScreen> createState() => _EmployeeProfileScreenState();
}

class _EmployeeProfileScreenState extends State<EmployeeProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: DummyData.employeeUser.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _saveEdits() {
    setState(() {
      DummyData.employeeUser = DummyData.employeeUser.copyWith(email: _emailController.text.trim());
      _isEditing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Profile updated successfully')),
    );
  }

  void _requestDeviceChange() {
    final reasonController = TextEditingController();
    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Request Device Change', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This request will be sent to HR for approval before your registered device is reset.',
              style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Reason, e.g. lost/replaced phone'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('✓ Device change request submitted to HR')),
              );
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Profile'),
        actions: [
          if (!_isEditing)
            IconButton(
              onPressed: () => setState(() => _isEditing = true),
              icon: const Icon(Icons.edit_outlined),
            )
          else
            TextButton(onPressed: _saveEdits, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: authController,
          builder: (context, _) {
          final user = DummyData.employeeUser;
          return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  InitialsAvatar(initials: user.avatarInitials, size: 76),
                  const SizedBox(height: 12),
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('${user.role} · ${user.department}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                  const SizedBox(height: 10),
                  StatusPill.risk(user.riskLevel),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const SectionHeader(title: 'Account Information'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(icon: Icons.badge_outlined, label: 'Employee ID', value: user.id),
                  const Divider(height: 1, indent: 56),
                  _isEditing
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(labelText: 'Email', isDense: true),
                          ),
                        )
                      : _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.apartment_rounded, label: 'Department', value: user.department),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.work_outline_rounded, label: 'Employment Duration', value: user.employmentDuration),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'My Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _MenuRow(
                icon: Icons.assessment_rounded,
                label: 'Performance Evaluation',
                color: c.amber,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeDetailScreen())),
              ),
            ),

            if (authController.role == UserRole.hrAdmin) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Administration'),
              AppCard(
                padding: EdgeInsets.zero,
                child: _MenuRow(
                  icon: Icons.admin_panel_settings_outlined,
                  label: 'Switch to Admin View',
                  color: c.primary,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrShell())),
                ),
              ),
            ],

            const SizedBox(height: 24),
            const SectionHeader(title: 'Registered Device'),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.phone_iphone_rounded, color: c.primaryDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.registeredDevice, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('Bound since ${user.deviceBoundSince}', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: user.registeredDevice == 'Not yet registered' ? null : _requestDeviceChange,
                    child: const Text('Request Change'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Settings'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _DarkModeRow(),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.notifications_none_rounded,
                    label: 'Notification Preferences',
                    color: c.infoBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPlaceholderScreen(title: 'Notification Preferences', icon: Icons.notifications_none_rounded))),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.calendar_month_outlined,
                    label: 'Company Calendar',
                    color: c.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyCalendarScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    color: c.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetPasswordScreen(mode: SetPasswordMode.voluntary))),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
                    color: c.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPlaceholderScreen(title: 'Help & Support', icon: Icons.help_outline_rounded))),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await authController.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                  );
                },
                icon: Icon(Icons.logout_rounded, size: 18, color: c.riskHigh),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.riskHigh,
                  side: BorderSide(color: c.riskHigh),
                ),
              ),
            ),
          ],
          );
          },
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color ?? c.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            Icon(Icons.chevron_right_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _DarkModeRow extends StatelessWidget {
  const _DarkModeRow();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.dark_mode_outlined, size: 18, color: c.textSecondary),
            const SizedBox(width: 14),
            Expanded(child: Text('Dark Mode', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: c.textPrimary))),
            Switch(
              value: mode == ThemeMode.dark,
              onChanged: (_) => themeController.toggle(),
              activeThumbColor: c.primary,
            ),
          ],
        ),
      ),
    );
  }
}