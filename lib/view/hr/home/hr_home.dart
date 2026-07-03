import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../analytics/anomaly_detail.dart';
import '../approvals/hr_approvals.dart';
import '../analytics/hr_analytics.dart';
import '../employees/hr_employees.dart';
import '../employees/add_employee.dart';
import '../policy/policy_config.dart';

class HrHomeScreen extends StatelessWidget {
  const HrHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = DummyData.hrUser;

    return Scaffold(
      appBar: HomeAppBar(
        greeting: 'Welcome back,',
        name: user.name,
        initials: user.avatarInitials,
        notificationCount: 3,
        onNotificationTap: () {},
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                StatCard(
                  label: 'Total Employees',
                  value: '${DummyData.totalEmployees}',
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.primary,
                  iconBg: AppColors.primaryLight,
                ),
                StatCard(
                  label: 'Attendance Rate',
                  value: '${(DummyData.overallAttendanceRate * 100).toInt()}%',
                  icon: Icons.event_available_rounded,
                  iconColor: AppColors.infoBlue,
                  iconBg: AppColors.infoBlueBg,
                  trend: '+1.2%',
                ),
                StatCard(
                  label: 'Pending Approvals',
                  value: '${DummyData.pendingLeaveCount}',
                  icon: Icons.pending_actions_rounded,
                  iconColor: AppColors.amber,
                  iconBg: AppColors.amberBg,
                ),
                StatCard(
                  label: 'Flagged Today',
                  value: '${DummyData.flaggedEventsToday}',
                  icon: Icons.flag_rounded,
                  iconColor: AppColors.riskHigh,
                  iconBg: AppColors.riskHighBg,
                ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Risk Classification Overview'),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: DummyData.riskDistribution[RiskLevel.low]!,
                        child: Container(height: 10, decoration: const BoxDecoration(color: AppColors.riskLow, borderRadius: BorderRadius.horizontal(left: Radius.circular(6)))),
                      ),
                      Expanded(
                        flex: DummyData.riskDistribution[RiskLevel.medium]!,
                        child: Container(height: 10, color: AppColors.riskMedium),
                      ),
                      Expanded(
                        flex: DummyData.riskDistribution[RiskLevel.high]!,
                        child: Container(height: 10, decoration: const BoxDecoration(color: AppColors.riskHigh, borderRadius: BorderRadius.horizontal(right: Radius.circular(6)))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LegendDot(color: AppColors.riskLow, label: 'Low', value: '${DummyData.riskDistribution[RiskLevel.low]}'),
                      _LegendDot(color: AppColors.riskMedium, label: 'Medium', value: '${DummyData.riskDistribution[RiskLevel.medium]}'),
                      _LegendDot(color: AppColors.riskHigh, label: 'High', value: '${DummyData.riskDistribution[RiskLevel.high]}'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Quick Actions'),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.fact_check_outlined,
                    label: 'Approvals',
                    color: AppColors.infoBlue,
                    bg: AppColors.infoBlueBg,
                    badge: DummyData.pendingLeaveCount,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrApprovalsScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_outlined,
                    label: 'Add Employee',
                    color: AppColors.primary,
                    bg: AppColors.primaryLight,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmployeeScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.tune_rounded,
                    label: 'Policies',
                    color: AppColors.purple,
                    bg: AppColors.purpleBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PolicyConfigScreen())),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            SectionHeader(
              title: 'Anomaly Feed',
              actionLabel: 'See all',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AnomalyDetailScreen())),
            ),
            ...DummyData.anomalyFeed.take(3).map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AnomalyTile(event: a),
            )),

            const SizedBox(height: 12),
            SectionHeader(
              title: 'Weekly Attendance Trend',
              actionLabel: 'Full report',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrAnalyticsScreen())),
            ),
            AppCard(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
              child: SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(DummyData.weeklyAttendanceTrend.length, (i) {
                    final v = DummyData.weeklyAttendanceTrend[i];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${(v * 100).toInt()}', style: const TextStyle(fontSize: 9, color: AppColors.textMuted, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 70 * v,
                              decoration: BoxDecoration(
                                color: i == 4 ? AppColors.primary : AppColors.primary.withOpacity(0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(DummyData.weekdayLabels[i], style: const TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final String value;
  const _LegendDot({required this.color, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary, fontWeight: FontWeight.w800)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final int? badge;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null && badge! > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: AppColors.riskHigh, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      child: Text(
                        '$badge',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _AnomalyTile extends StatelessWidget {
  final AnomalyEvent event;
  const _AnomalyTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: event.severity == RiskLevel.high ? AppColors.riskHighBg : AppColors.riskMediumBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_rounded,
              size: 18,
              color: event.severity == RiskLevel.high ? AppColors.riskHigh : AppColors.riskMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${event.employeeName} · ${event.date}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          StatusPill.risk(event.severity),
        ],
      ),
    );
  }
}