import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../controller/analytics_controller.dart';

class HrAnalyticsScreen extends StatefulWidget {
  // See the identical comment on HrApprovalsScreen — explicit flag instead
  // of Navigator.canPop(), which is ambiguous between "this is a pushed
  // shortcut" and "this is the IndexedStack tab root while HrShell itself
  // is pushed on top of EmployeeShell."
  final bool showBackButton;
  const HrAnalyticsScreen({super.key, this.showBackButton = false});

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

  Future<void> _downloadCsv(String title) async {
    final csv = analyticsController.csvFor(title);
    final fileName = '${title.replaceAll(' ', '_')}.csv';
    await Share.shareXFiles(
      [XFile.fromData(Uint8List.fromList(utf8.encode(csv)), name: fileName, mimeType: 'text/csv')],
      subject: title,
    );
  }

  Future<void> _downloadPdf(String title) async {
    final bytes = await analyticsController.pdfBytesFor(title);
    final fileName = '${title.replaceAll(' ', '_')}.pdf';
    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: 'application/pdf')],
      subject: title,
    );
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
                          'Summary above is based on live data for the currently selected period.',
                          style: TextStyle(fontSize: 11.5, color: c.primaryDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _downloadCsv(title);
                        },
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                        icon: const Icon(Icons.table_chart_outlined, size: 14),
                        label: const Text('Export as CSV', style: TextStyle(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await _downloadPdf(title);
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10)),
                        icon: const Icon(Icons.picture_as_pdf_outlined, size: 14),
                        label: const Text('Export as PDF', style: TextStyle(fontSize: 11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
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
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('Analytics & Reports'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: ListenableBuilder(
              listenable: analyticsController,
              builder: (context, _) => DropdownButtonHideUnderline(
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
            final lateEmployees = analyticsController.topLateEmployees;
            final maxLate = lateEmployees.isEmpty ? 1 : lateEmployees.first.count;

            return RefreshIndicator(
              onRefresh: analyticsController.load,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    children: [
                      Text('Month:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textSecondary)),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: analyticsController.exportMonth.month,
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem(
                                        value: m,
                                        child: Text(
                                          DateFormat('MMMM').format(DateTime(0, m)),
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                      ))
                                  .toList(),
                              onChanged: (m) {
                                if (m != null) analyticsController.setExportMonth(DateTime(analyticsController.exportMonth.year, m, 1));
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              isExpanded: true,
                              value: analyticsController.exportMonth.year,
                              items: [DateTime.now().year, DateTime.now().year - 1]
                                  .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))))
                                  .toList(),
                              onChanged: (y) {
                                if (y != null) analyticsController.setExportMonth(DateTime(y, analyticsController.exportMonth.month, 1));
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
            );
          },
        ),
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
