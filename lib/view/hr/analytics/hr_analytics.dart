import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrAnalyticsScreen extends StatefulWidget {
  const HrAnalyticsScreen({super.key});

  @override
  State<HrAnalyticsScreen> createState() => _HrAnalyticsScreenState();
}

class _HrAnalyticsScreenState extends State<HrAnalyticsScreen> {
  String _period = 'This Week';
  final _periods = ['This Week', 'This Month', 'This Quarter'];

  String _summaryFor(String reportTitle) {
    switch (reportTitle) {
      case 'Monthly Attendance Summary':
        final avg = DummyData.weeklyAttendanceTrend.reduce((a, b) => a + b) / DummyData.weeklyAttendanceTrend.length;
        return 'Average attendance rate this week: ${(avg * 100).toInt()}% across ${DummyData.totalEmployees} employees.';
      case 'Leave Utilisation Report':
        final pending = DummyData.pendingApprovalsForHr.length;
        return '$pending leave application(s) currently pending across all departments.';
      case 'Payroll Deduction Report':
        final total = DummyData.payrollByEmployee.fold<double>(0, (sum, p) => sum + p.deductions);
        return 'Total deductions this cycle: RM ${total.toStringAsFixed(2)} across ${DummyData.payrollByEmployee.length} employees.';
      case 'Suspicious Activity Report':
        return '${DummyData.anomalyFeed.length} anomaly event(s) logged, ${DummyData.anomalyFeed.where((e) => e.severity == RiskLevel.high).length} high severity.';
      case 'Annual PE Summary':
        final avg = DummyData.peHistory.map((p) => p.weightedTotal).reduce((a, b) => a + b) / DummyData.peHistory.length;
        return 'Average weighted PE score across recorded evaluations: ${avg.toStringAsFixed(1)}/100.';
      default:
        return 'Report generated successfully.';
    }
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
                Text(_summaryFor(title), style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4)),
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
                          'Phase 1 Prototype — this simulates report generation. PDF/CSV export will be wired to the backend in Phase 2.',
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
        title: const Text('Analytics & Reports'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _period,
                borderRadius: BorderRadius.circular(12),
                items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                onChanged: (v) => setState(() => _period = v!),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // KPI Row
            Row(
              children: [
                Expanded(child: StatCard(label: 'Attendance Rate', value: '91%', icon: Icons.event_available_rounded, iconColor: c.primary, iconBg: c.primaryLight, trend: '+1.2%')),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Late Arrivals', value: '9', icon: Icons.schedule_rounded, iconColor: c.amber, iconBg: c.amberBg)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatCard(label: 'Flagged Events', value: '4', icon: Icons.flag_rounded, iconColor: c.riskHigh, iconBg: c.riskHighBg)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'On Leave Today', value: '7', icon: Icons.beach_access_rounded, iconColor: c.infoBlue, iconBg: c.infoBlueBg)),
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
                      children: List.generate(DummyData.weeklyAttendanceTrend.length, (i) {
                        final v = DummyData.weeklyAttendanceTrend[i];
                        final isToday = i == 4;
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
                                    color: isToday ? c.primary : c.primary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(DummyData.weekdayLabels[i], style: TextStyle(fontSize: 10, color: isToday ? c.primaryDark : c.textMuted, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
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
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: c.primary.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
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
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.low]!, child: Container(height: 12, decoration: BoxDecoration(color: c.riskLow, borderRadius: const BorderRadius.horizontal(left: Radius.circular(8))))),
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.medium]!, child: Container(height: 12, color: c.riskMedium)),
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.high]!, child: Container(height: 12, decoration: BoxDecoration(color: c.riskHigh, borderRadius: const BorderRadius.horizontal(right: Radius.circular(8))))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _RiskLegendTile(label: 'Low Risk', count: DummyData.riskDistribution[RiskLevel.low]!, total: DummyData.totalEmployees, color: c.riskLow, bg: c.riskLowBg)),
                      const SizedBox(width: 10),
                      Expanded(child: _RiskLegendTile(label: 'Medium Risk', count: DummyData.riskDistribution[RiskLevel.medium]!, total: DummyData.totalEmployees, color: c.riskMedium, bg: c.riskMediumBg)),
                      const SizedBox(width: 10),
                      Expanded(child: _RiskLegendTile(label: 'High Risk', count: DummyData.riskDistribution[RiskLevel.high]!, total: DummyData.totalEmployees, color: c.riskHigh, bg: c.riskHighBg)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Late Arrival Frequency'),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _LateBar(name: 'Ramesh Kumar', dept: 'Sales', count: 4, max: 5),
                  const SizedBox(height: 12),
                  _LateBar(name: 'Tan Wei Ming', dept: 'Engineering', count: 3, max: 5),
                  const SizedBox(height: 12),
                  _LateBar(name: 'Faiz Hidayat', dept: 'Operations', count: 3, max: 5),
                  const SizedBox(height: 12),
                  _LateBar(name: 'Lim Jia Hui', dept: 'Marketing', count: 2, max: 5),
                  const SizedBox(height: 12),
                  _LateBar(name: 'Hin Chen Wei', dept: 'Engineering', count: 1, max: 5),
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
          Text('${((count / total) * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.7), fontFeatures: const [FontFeature.tabularFigures()])),
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
    final ratio = count / max;
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