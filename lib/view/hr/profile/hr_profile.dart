import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../main.dart';
import '../../../controller/auth_controller.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../auth/login_screen.dart';
import '../policy/policy_config.dart';
import '../pe/hr_pe.dart';
import '../training/hr_training.dart';
import '../../shared/company_calendar.dart';
import '../../shared/settings_placeholder.dart';
import '../devices/hr_device_requests.dart';
import '../leave/leave_balances.dart';
import '../payroll/hr_payroll.dart';
import '../../auth/set_password_screen.dart';
import '../../employee/employee_shell.dart';
import '../../../controller/employee_controller.dart';

class HrProfileScreen extends StatefulWidget {
  const HrProfileScreen({super.key});

  @override
  State<HrProfileScreen> createState() => _HrProfileScreenState();
}

class _HrProfileScreenState extends State<HrProfileScreen> {
  @override
  void initState() {
    super.initState();
    if (employeeController.employees.isEmpty) {
      employeeController.loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = DummyData.hrUser;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Profile')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [

            // Avatar + info
            Center(
              child: Column(
                children: [
                  Container(
                    width: 80, height: 80,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: c.kpiGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      boxShadow: [c.shadowTinted()],
                    ),
                    child: Text(user.avatarInitials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(100)),
                    child: Text('HR Administrator', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.primaryDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Account info
            const SectionHeader(title: 'Account Information'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(icon: Icons.badge_outlined, label: 'Employee ID', value: user.id),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: user.email),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.apartment_rounded, label: 'Department', value: user.department),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.schedule_rounded, label: 'Employment Duration', value: user.employmentDuration),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'My Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _MenuRow(
                icon: Icons.badge_outlined,
                label: 'Switch to Employee View',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeeShell())),
              ),
            ),
            const SizedBox(height: 24),

            // Quick admin links
            const SectionHeader(title: 'Administration'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.tune_rounded,
                    label: 'Policy & Configuration',
                    color: c.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyConfigScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.assessment_rounded,
                    label: 'Performance Evaluation',
                    color: c.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrPeScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.school_rounded,
                    label: 'Training Management',
                    color: c.infoBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrTrainingScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Leave Balances',
                    color: c.infoBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrLeaveBalancesScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.receipt_long_rounded,
                    label: 'Payroll Summaries',
                    color: c.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrPayrollScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Company Calendar',
                    color: c.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyCalendarScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.phone_android_rounded,
                    label: 'Device Change Requests',
                    color: c.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrDeviceRequestsScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System summary
            const SectionHeader(title: 'System Overview'),
            ListenableBuilder(
              listenable: employeeController,
              builder: (context, _) => Row(
                children: [
                  Expanded(child: StatCard(label: 'Total Employees', value: '${employeeController.employees.length}', icon: Icons.groups_rounded, iconColor: c.primary, iconBg: c.primaryLight)),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(label: 'Active Modules', value: '10', icon: Icons.widgets_rounded, iconColor: c.infoBlue, iconBg: c.infoBlueBg)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings
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
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPlaceholderScreen(title: 'Notification Preferences', icon: Icons.notifications_none_rounded))),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change Password',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetPasswordScreen(mode: SetPasswordMode.voluntary))),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.help_outline_rounded,
                    label: 'Help & Support',
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
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
            child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary), overflow: TextOverflow.ellipsis),
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