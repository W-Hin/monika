import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: StatCard(label: 'Attendance Rate', value: '91%', icon: Icons.event_available_rounded, iconColor: AppColors.primary, iconBg: AppColors.primaryLight, trend: '+1.2%')),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'Late Arrivals', value: '9', icon: Icons.schedule_rounded, iconColor: AppColors.amber, iconBg: AppColors.amberBg)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: StatCard(label: 'Flagged Events', value: '4', icon: Icons.flag_rounded, iconColor: AppColors.riskHigh, iconBg: AppColors.riskHighBg)),
                const SizedBox(width: 12),
                Expanded(child: StatCard(label: 'On Leave Today', value: '7', icon: Icons.beach_access_rounded, iconColor: AppColors.infoBlue, iconBg: AppColors.infoBlueBg)),
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
                                Text('${(v * 100).toInt()}%', style: TextStyle(fontSize: 9, color: isToday ? AppColors.primaryDark : AppColors.textMuted, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Container(
                                  height: 100 * v,
                                  decoration: BoxDecoration(
                                    color: isToday ? AppColors.primary : AppColors.primary.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(DummyData.weekdayLabels[i], style: TextStyle(fontSize: 10, color: isToday ? AppColors.primaryDark : AppColors.textMuted, fontWeight: isToday ? FontWeight.w800 : FontWeight.w500)),
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
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      const Text('Today', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.3), borderRadius: BorderRadius.circular(3))),
                      const SizedBox(width: 6),
                      const Text('Other days', style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
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
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.low]!, child: Container(height: 12, decoration: const BoxDecoration(color: AppColors.riskLow, borderRadius: BorderRadius.horizontal(left: Radius.circular(8))))),
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.medium]!, child: Container(height: 12, color: AppColors.riskMedium)),
                      Expanded(flex: DummyData.riskDistribution[RiskLevel.high]!, child: Container(height: 12, decoration: const BoxDecoration(color: AppColors.riskHigh, borderRadius: BorderRadius.horizontal(right: Radius.circular(8))))),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: _RiskLegendTile(label: 'Low Risk', count: DummyData.riskDistribution[RiskLevel.low]!, total: DummyData.totalEmployees, color: AppColors.riskLow, bg: AppColors.riskLowBg)),
                      const SizedBox(width: 10),
                      Expanded(child: _RiskLegendTile(label: 'Medium Risk', count: DummyData.riskDistribution[RiskLevel.medium]!, total: DummyData.totalEmployees, color: AppColors.riskMedium, bg: AppColors.riskMediumBg)),
                      const SizedBox(width: 10),
                      Expanded(child: _RiskLegendTile(label: 'High Risk', count: DummyData.riskDistribution[RiskLevel.high]!, total: DummyData.totalEmployees, color: AppColors.riskHigh, bg: AppColors.riskHighBg)),
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
              ('Monthly Attendance Summary', Icons.calendar_month_rounded, AppColors.primary, AppColors.primaryLight),
              ('Leave Utilisation Report', Icons.beach_access_rounded, AppColors.infoBlue, AppColors.infoBlueBg),
              ('Payroll Deduction Report', Icons.receipt_long_rounded, AppColors.purple, AppColors.purpleBg),
              ('Suspicious Activity Report', Icons.security_rounded, AppColors.riskHigh, AppColors.riskHighBg),
              ('Annual PE Summary', Icons.assessment_rounded, AppColors.amber, AppColors.amberBg),
            ].map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                onTap: () {},
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: t.$4, borderRadius: BorderRadius.circular(12)), child: Icon(t.$2, color: t.$3, size: 18)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(t.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    const Icon(Icons.download_rounded, color: AppColors.textMuted, size: 18),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text('${((count / total) * 100).toInt()}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color.withOpacity(0.7))),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
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
    final ratio = count / max;
    final color = count >= 4 ? AppColors.riskHigh : count >= 2 ? AppColors.riskMedium : AppColors.primary;
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              Text(dept, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(value: ratio, minHeight: 8, backgroundColor: AppColors.surfaceMuted, valueColor: AlwaysStoppedAnimation(color)),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 28, child: Text('$count', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color))),
      ],
    );
  }
}