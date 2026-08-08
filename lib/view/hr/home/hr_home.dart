import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../../controller/anomaly_controller.dart';
import '../../../controller/analytics_controller.dart';
import '../../../controller/notification_controller.dart';
import '../../../controller/device_request_controller.dart';
import '../../../controller/calendar_controller.dart';
import '../analytics/anomaly_detail.dart';
import '../approvals/hr_approvals.dart';
import '../employees/add_employee.dart';
import '../policy/policy_config.dart';
import '../devices/hr_device_requests.dart';
import '../announcements/post_announcement_screen.dart';
import '../training/hr_training.dart';
import '../pe/hr_pe.dart';
import '../leave/leave_balances.dart';
import '../payroll/hr_payroll.dart';
import '../../shared/company_calendar.dart';
import '../../shared/notification.dart';

class HrHomeScreen extends StatefulWidget {
  const HrHomeScreen({super.key});

  @override
  State<HrHomeScreen> createState() => _HrHomeScreenState();
}

class _HrHomeScreenState extends State<HrHomeScreen> {
  @override
  void initState() {
    super.initState();
    anomalyController.loadFeed();
    analyticsController.load();
    deviceRequestController.loadAllForHr();
    calendarController.load();
  }

  void _showMoreMenu(BuildContext context) {
    final c = context.colors;
    showDialog(
      context: context,
      builder: (dialogContext) {
        void go(Widget page) {
          Navigator.of(dialogContext).pop();
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        }

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('More Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: [
                    _MoreMenuItem(
                      icon: Icons.tune_rounded,
                      label: 'Policies',
                      color: c.purple,
                      bg: c.purpleBg,
                      onTap: () => go(const PolicyConfigScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'Calendar',
                      color: c.primary,
                      bg: c.primaryLight,
                      onTap: () => go(const CompanyCalendarScreen(isAdminView: true)),
                    ),
                    _MoreMenuItem(
                      icon: Icons.phone_android_rounded,
                      label: 'Device Requests',
                      color: c.amber,
                      bg: c.amberBg,
                      onTap: () => go(const HrDeviceRequestsScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.campaign_rounded,
                      label: 'Announcement',
                      color: c.purple,
                      bg: c.purpleBg,
                      onTap: () => go(const PostAnnouncementScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.school_rounded,
                      label: 'Training',
                      color: c.infoBlue,
                      bg: c.infoBlueBg,
                      onTap: () => go(const HrTrainingScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.assessment_rounded,
                      label: 'Performance',
                      color: c.amber,
                      bg: c.amberBg,
                      onTap: () => go(const HrPeScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'Leave Balances',
                      color: c.infoBlue,
                      bg: c.infoBlueBg,
                      onTap: () => go(const HrLeaveBalancesScreen()),
                    ),
                    _MoreMenuItem(
                      icon: Icons.receipt_long_rounded,
                      label: 'Payroll',
                      color: c.purple,
                      bg: c.purpleBg,
                      onTap: () => go(const HrPayrollScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = DummyData.hrUser;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ListenableBuilder(
          listenable: notificationController,
          builder: (context, _) => HomeAppBar(
            greeting: 'Welcome back,',
            name: user.name,
            initials: user.avatarInitials,
            notificationCount: notificationController.unreadCount,
            onNotificationTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([anomalyController, analyticsController, deviceRequestController, calendarController]),
          builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Employees',
                    value: '${analyticsController.totalEmployees}',
                    icon: Icons.groups_rounded,
                    iconColor: c.primary,
                    iconBg: c.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Pending Approvals',
                    value: '${analyticsController.pendingLeaveCount}',
                    icon: Icons.pending_actions_rounded,
                    iconColor: c.amber,
                    iconBg: c.amberBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Device Requests',
                    value: '${deviceRequestController.allRequests.where((r) => r.status == 'pending').length}',
                    icon: Icons.phone_android_rounded,
                    iconColor: c.infoBlue,
                    iconBg: c.infoBlueBg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Flagged Today',
                    value: '${analyticsController.flaggedToday}',
                    icon: Icons.flag_rounded,
                    iconColor: c.riskHigh,
                    iconBg: c.riskHighBg,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Risk Classification Overview'),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RiskDonutChart(
                      low: analyticsController.riskDistribution[RiskLevel.low] ?? 0,
                      medium: analyticsController.riskDistribution[RiskLevel.medium] ?? 0,
                      high: analyticsController.riskDistribution[RiskLevel.high] ?? 0,
                    ),
                    const SizedBox(width: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _LegendDot(color: c.riskLow, label: 'Low', value: '${analyticsController.riskDistribution[RiskLevel.low] ?? 0}'),
                        const SizedBox(height: 10),
                        _LegendDot(color: c.riskMedium, label: 'Medium', value: '${analyticsController.riskDistribution[RiskLevel.medium] ?? 0}'),
                        const SizedBox(height: 10),
                        _LegendDot(color: c.riskHigh, label: 'High', value: '${analyticsController.riskDistribution[RiskLevel.high] ?? 0}'),
                      ],
                    ),
                  ],
                ),
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
                    badge: analyticsController.pendingLeaveCount,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrApprovalsScreen(showBackButton: true))),
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
                    icon: Icons.apps_rounded,
                    label: 'More',
                    color: c.purple,
                    bg: c.purpleBg,
                    onTap: () => _showMoreMenu(context),
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
            if (anomalyController.feed.isEmpty)
              AppCard(
                child: Text('No anomalies logged yet', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
              )
            else
              ...anomalyController.feed.take(3).map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AnomalyTile(event: a),
              )),

            const SizedBox(height: 12),
            SectionHeader(
              title: 'Upcoming Events',
              actionLabel: 'View calendar',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CompanyCalendarScreen(isAdminView: true))),
            ),
            Builder(builder: (context) {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final upcoming = calendarController.events.where((e) {
                final end = e.endDate ?? e.eventDate;
                return !end.isBefore(today);
              }).take(3).toList();
              if (upcoming.isEmpty) {
                return AppCard(
                  child: Text('No upcoming events', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                );
              }
              return Column(
                children: upcoming.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(10)),
                              child: Icon(Icons.event_rounded, size: 18, color: c.primaryDark),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(DateFormat('d MMM yyyy').format(e.eventDate), style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )).toList(),
              );
            }),
          ],
          ),
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

/// Donut chart for the 3-category (Low/Medium/High) risk breakdown. Colour
/// alone never carries the meaning here — every segment's value is also
/// shown as text in the adjacent legend, since pie/donut charts otherwise
/// fail accessibility for colourblind users relying on hue to distinguish
/// slices.
class RiskDonutChart extends StatelessWidget {
  final int low;
  final int medium;
  final int high;
  final double size;

  const RiskDonutChart({super.key, required this.low, required this.medium, required this.high, this.size = 108});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = low + medium + high;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          total == 0 ? [(1.0, c.border)] : [(low / total, c.riskLow), (medium / total, c.riskMedium), (high / total, c.riskHigh)],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$total', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: c.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
              Text('Employees', style: TextStyle(fontSize: 9.5, color: c.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> segments; // (fraction, color), fractions sum to 1.0
  const _DonutPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 16.0;
    const gapRadians = 0.04;
    // Gaps only make sense between two *visible* slices — segments.length
    // is always 3 (low/medium/high) even when only one category actually
    // has anyone in it, so gating on that left a stray gap notched into an
    // otherwise-full circle whenever everyone fell into a single category.
    final visibleCount = segments.where((s) => s.$1 > 0).length;

    var startAngle = -3.14159265 / 2;
    for (final (fraction, color) in segments) {
      if (fraction <= 0) continue;
      final sweep = fraction * 2 * 3.14159265;
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = visibleCount > 1 ? StrokeCap.butt : StrokeCap.round;
      final adjustedSweep = visibleCount > 1 ? (sweep - gapRadians).clamp(0.0, sweep) : sweep;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        adjustedSweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.segments != segments;
}

class _MoreMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _MoreMenuItem({required this.icon, required this.label, required this.color, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
        ],
      ),
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