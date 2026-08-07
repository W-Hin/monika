import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/analytics_controller.dart';

class HrAnalyticsScreen extends StatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  State<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends State<HrAnalyticsScreen> {
  final _periods = ['This Week', 'This Month', 'This Quarter'];

  @override
  void initState() {
    super.initState();
    analyticsController.load();
  }

  void _generateReport(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Builder(
          builder: (context) {
            final c = context.colors;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(analyticsController.summaryFor(title), style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: c.primaryDark),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Summary above is based on live data. Downloading as a PDF/CSV file isn\'t implemented yet.',
                          style: TextStyle(fontSize: 11.5, color: c.primaryDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
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
        title: const Text('Analytics & Reports'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: analyticsController.period,
                borderRadius: BorderRadius.circular(12),
                items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) {
                  if (v != null) analyticsController.load(period: v);
                },
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: analyticsController,
          builder: (context, _) {
            if (analyticsController.loading && analyticsController.totalEmployees == 0) {
              return const Center(child: CircularProgressIndicator());
            }
            final risk = analyticsController.riskDistribution;
            final lateEmployees = analyticsController.topLateEmployees;
            final maxLate = lateEmployees.isEmpty ? 1 : lateEmployees.first.count;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // KPI Row
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Attendance Rate', value: '${(analyticsController.attendanceRate * 100).toInt()}%', icon: Icons.event_available_rounded, iconColor: c.primary, iconBg: c.primaryLight)),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'Late Arrivals', value: '${analyticsController.lateArrivals}', icon: Icons.schedule_rounded, iconColor: c.amber, iconBg: c.amberBg)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: StatCard(label: 'Flagged Events', value: '${analyticsController.flaggedEvents}', icon: Icons.flag_rounded, iconColor: c.riskHigh, iconBg: c.riskHighBg)),
                    const SizedBox(width: 12),
                    Expanded(child: StatCard(label: 'On Leave Today', value: '${analyticsController.onLeaveToday}', icon: Icons.beach_access_rounded, iconColor: c.infoBlue, iconBg: c.infoBlueBg)),
                  ],
                ),

                const SizedBox(height: 24),
                const SectionHeader(title: 'Weekly Attendance Trend'),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 140,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(analyticsController.weeklyTrend.length, (i) {
                            final v = analyticsController.weeklyTrend[i];
                            final isToday = i == analyticsController.weeklyTrend.length - 1;
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(v * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: isToday ? c.primaryDark : c.textMuted,
                                        fontWeight: FontWeight.w700,
                                        fontFeatures: const [FontFeature.tabularFigures()],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 100 * v,
                                      decoration: BoxDecoration(
                                        color: isToday ? c.primary : c.primary.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(analyticsController.weekdayLabels[i], style: TextStyle(fontSize: 10, color: isToday ? c.primaryDark : c.textMuted, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 6),
                          Text('Today', style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 16),
                          Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
                          const SizedBox(width: 6),
                          Text('Other days', style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const SectionHeader(title: 'Risk Classification Distribution'),
                AppCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(flex: (risk[RiskLevel.low] ?? 0) + 1, child: Container(height: 12, decoration: BoxDecoration(color: c.riskLow, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))))),
                          Expanded(flex: (risk[RiskLevel.medium] ?? 0) + 1, child: Container(height: 12, color: c.riskMedium)),
                          Expanded(flex: (risk[RiskLevel.high] ?? 0) + 1, child: Container(height: 12, decoration: BoxDecoration(color: c.riskHigh, borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))))),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(child: _RiskLegendTile(label: 'Low Risk', count: risk[RiskLevel.low] ?? 0, total: analyticsController.totalEmployees, color: c.riskLow, bg: c.riskLowBg)),
                          const SizedBox(width: 10),
                          Expanded(child: _RiskLegendTile(label: 'Medium Risk', count: risk[RiskLevel.medium] ?? 0, total: analyticsController.totalEmployees, color: c.riskMedium, bg: c.riskMediumBg)),
                          const SizedBox(width: 10),
                          Expanded(child: _RiskLegendTile(label: 'High Risk', count: risk[RiskLevel.high] ?? 0, total: analyticsController.totalEmployees, color: c.riskHigh, bg: c.riskHighBg)),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const SectionHeader(title: 'Late Arrival Frequency'),
                AppCard(
                  padding: const EdgeInsets.all(16),
                  child: lateEmployees.isEmpty
                      ? Text('No late arrivals in this period.', style: TextStyle(fontSize: 12.5, color: c.textMuted))
                      : Column(
                          children: [
                            for (int i = 0; i < lateEmployees.length; i++) ...[
                              if (i > 0) const SizedBox(height: 12),
                              _LateBar(name: lateEmployees[i].name, dept: lateEmployees[i].department, count: lateEmployees[i].count, max: maxLate),
                            ],
                          ],
                        ),
                ),

                const SizedBox(height: 24),
                const SectionHeader(title: 'Export Reports'),
                ...[
                  ('Monthly Attendance Summary', Icons.calendar_month_rounded, c.primary, c.primaryLight),
                  ('Leave Utilisation Report', Icons.beach_access_rounded, c.infoBlue, c.infoBlueBg),
                  ('Payroll Deduction Report', Icons.receipt_long_rounded, c.purple, c.purpleBg),
                  ('Suspicious Activity Report', Icons.security_rounded, c.riskHigh, c.riskHighBg),
                  ('Annual PE Summary', Icons.assessment_rounded, c.amber, c.amberBg),
                ].map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _generateReport(t.$1),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: t.$4, borderRadius: BorderRadius.circular(12)), child: Icon(t.$2, color: t.$3, size: 18)),
                        const SizedBox(width: 14),
                        Expanded(child: Text(t.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                        Icon(Icons.download_rounded, color: c.textMuted, size: 18),
                      ],
                    ),
                  ),
                )),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RiskLegendTile extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final Color bg;
  const _RiskLegendTile({required this.label, required this.count, required this.total, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color, fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 2),
          Text(total == 0 ? '0%' : '${((count / total) * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.7), fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: c.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _LateBar extends StatelessWidget {
  final String name;
  final String dept;
  final int count;
  final int max;
  const _LateBar({required this.name, required this.dept, required this.count, required this.max});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ratio = max == 0 ? 0.0 : count / max;
    final color = count >= 4 ? c.riskHigh : count >= 2 ? c.riskMedium : c.primary;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text(dept, style: TextStyle(fontSize: 10.5, color: c.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: c.surfaceMuted, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color, fontFeatures: const [FontFeature.tabularFigures()]))),
      ],
    );
  }
}
