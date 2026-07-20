import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../analytics/anomaly_detail.dart';
import '../approvals/hr_approvals.dart';
import '../analytics/hr_analytics.dart';
import '../employees/add_employee.dart';
import '../policy/policy_config.dart';
import '../../shared/notification.dart';

class HrHomeScreen extends StatelessWidget {
  const HrHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = DummyData.hrUser;

    return Scaffold(
      appBar: HomeAppBar(
        greeting: 'Welcome back,',
        name: user.name,
        initials: user.avatarInitials,
        notificationCount: 3,
        onNotificationTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        ),
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
                  iconColor: c.primary,
                  iconBg: c.primaryLight,
                ),
                StatCard(
                  label: 'Attendance Rate',
                  value: '${(DummyData.overallAttendanceRate * 100).toInt()}%',
                  icon: Icons.event_available_rounded,
                  iconColor: c.infoBlue,
                  iconBg: c.infoBlueBg,
                  trend: '+1.2%',
                ),
                StatCard(
                  label: 'Pending Approvals',
                  value: '${DummyData.pendingLeaveCount}',
                  icon: Icons.pending_actions_rounded,
                  iconColor: c.amber,
                  iconBg: c.amberBg,
                ),
                StatCard(
                  label: 'Flagged Today',
                  value: '${DummyData.flaggedEventsToday}',
                  icon: Icons.flag_rounded,
                  iconColor: c.riskHigh,
                  iconBg: c.riskHighBg,
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
                        child: Container(height: 10, decoration: BoxDecoration(color: c.riskLow, borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)))),
                      ),
                      Expanded(
                        flex: DummyData.riskDistribution[RiskLevel.medium]!,
                        child: Container(height: 10, color: c.riskMedium),
                      ),
                      Expanded(
                        flex: DummyData.riskDistribution[RiskLevel.high]!,
                        child: Container(height: 10, decoration: BoxDecoration(color: c.riskHigh, borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _LegendDot(color: c.riskLow, label: 'Low', value: '${DummyData.riskDistribution[RiskLevel.low]}'),
                      _LegendDot(color: c.riskMedium, label: 'Medium', value: '${DummyData.riskDistribution[RiskLevel.medium]}'),
                      _LegendDot(color: c.riskHigh, label: 'High', value: '${DummyData.riskDistribution[RiskLevel.high]}'),
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
                    color: c.infoBlue,
                    bg: c.infoBlueBg,
                    badge: DummyData.pendingLeaveCount,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrApprovalsScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.person_add_alt_outlined,
                    label: 'Add Employee',
                    color: c.primary,
                    bg: c.primaryLight,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmployeeScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.tune_rounded,
                    label: 'Policies',
                    color: c.purple,
                    bg: c.purpleBg,
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
                            Text('${(v * 100).toInt()}', style: TextStyle(fontSize: 9, color: c.textMuted, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              height: 70 * v,
                              decoration: BoxDecoration(
                                color: i == 4 ? c.primary : c.primary.withValues(alpha: 0.35),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(DummyData.weekdayLabels[i], style: TextStyle(fontSize: 10, color: c.textMuted, fontWeight: FontWeight.w600)),
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
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label ', style: TextStyle(fontSize: 11.5, color: c.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: TextStyle(fontSize: 11.5, color: c.textPrimary, fontWeight: FontWeight.w800)),
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
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
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
                      decoration: BoxDecoration(color: c.riskHigh, shape: BoxShape.circle),
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
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: event.severity == RiskLevel.high ? c.riskHighBg : c.riskMediumBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_rounded,
              size: 18,
              color: event.severity == RiskLevel.high ? c.riskHigh : c.riskMedium,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${event.employeeName} · ${event.date}', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          StatusDot.risk(context, event.severity),
        ],
      ),
    );
  }
}