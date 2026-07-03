import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../auth/login_screen.dart';
import '../policy/policy_config.dart';
import '../pe/hr_pe.dart';
import '../training/hr_training.dart';
import '../../shared/company_calendar.dart';

class HrProfileScreen extends StatelessWidget {
  const HrProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = DummyData.hrUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
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
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: AppColors.kpiGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                    ),
                    child: Text(user.avatarInitials, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                    child: const Text('HR Administrator', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
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

            // Quick admin links
            const SectionHeader(title: 'Administration'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(
                    icon: Icons.tune_rounded,
                    label: 'Policy & Configuration',
                    color: AppColors.purple,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyConfigScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.assessment_rounded,
                    label: 'Performance Evaluation',
                    color: AppColors.amber,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrPeScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.school_rounded,
                    label: 'Training Management',
                    color: AppColors.infoBlue,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrTrainingScreen())),
                  ),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(
                    icon: Icons.calendar_month_rounded,
                    label: 'Company Calendar',
                    color: AppColors.primary,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyCalendarScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // System summary
            const SectionHeader(title: 'System Overview'),
            Row(
              children: [
                Expanded(child: StatCard(label: 'Total Employees', value: '${DummyData.totalEmployees}', icon: Icons.groups_rounded, iconColor: AppColors.primary, iconBg: AppColors.primaryLight)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Active Modules', value: '10', icon: Icons.widgets_rounded, iconColor: AppColors.infoBlue, iconBg: AppColors.infoBlueBg)),
              ],
            ),
            const SizedBox(height: 24),

            // Settings
            const SectionHeader(title: 'Settings'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _MenuRow(icon: Icons.notifications_none_rounded, label: 'Notification Preferences', color: AppColors.textSecondary, onTap: () {}),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(icon: Icons.lock_outline_rounded, label: 'Change Password', color: AppColors.textSecondary, onTap: () {}),
                  const Divider(height: 1, indent: 56),
                  _MenuRow(icon: Icons.help_outline_rounded, label: 'Help & Support', color: AppColors.textSecondary, onTap: () {}),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                ),
                icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.riskHigh),
                label: const Text('Log Out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.riskHigh,
                  side: const BorderSide(color: AppColors.riskHigh),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuRow({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}