import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../controller/attendance_controller.dart';
import '../../../model/models.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  @override
  void initState() {
    super.initState();
    attendanceController.loadForMonth(_selectedMonth);
  }

  void _changeMonth(DateTime month) {
    setState(() => _selectedMonth = month);
    attendanceController.loadForMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = DateTime.now();
    // A long-tenured account could have years of history — offer this year
    // and last year, not an unbounded picker.
    final years = [now.year, now.year - 1];

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Attendance History'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: attendanceController,
          builder: (context, _) {
            final records = attendanceController.monthRecords;
            final flagged = records.where((r) => r.status == AttendanceStatus.flagged).length;
            final late = records.where((r) => r.status == AttendanceStatus.late).length;
            // "Present" counts on-time and late alike — being late still
            // means they showed up. Only flagged clock-ins (or no record at
            // all) count against the rate.
            final present = records.where((r) => r.status == AttendanceStatus.onTime || r.status == AttendanceStatus.late).length;
            final rate = records.isEmpty ? 0 : ((present / records.length) * 100).round();

            return RefreshIndicator(
              onRefresh: () => attendanceController.loadForMonth(_selectedMonth),
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedMonth.month,
                            items: List.generate(12, (i) => i + 1)
                                .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(DateFormat('MMMM').format(DateTime(0, m)), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    ))
                                .toList(),
                            onChanged: (m) {
                              if (m != null) _changeMonth(DateTime(_selectedMonth.year, m, 1));
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selectedMonth.year,
                            items: years
                                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700))))
                                .toList(),
                            onChanged: (y) {
                              if (y != null) _changeMonth(DateTime(y, _selectedMonth.month, 1));
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Attendance Rate',
                          value: '$rate%',
                          icon: Icons.event_available_rounded,
                          iconColor: c.primary,
                          iconBg: c.primaryLight,
                          labelFontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Late Arrivals',
                          value: '$late',
                          icon: Icons.schedule_rounded,
                          iconColor: c.amber,
                          iconBg: c.amberBg,
                          labelFontSize: 11.5,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Flagged',
                          value: '$flagged',
                          icon: Icons.flag_outlined,
                          iconColor: c.riskHigh,
                          iconBg: c.riskHighBg,
                          labelFontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionHeader(title: 'Records — ${DateFormat('MMMM yyyy').format(_selectedMonth)}'),
                if (attendanceController.loadingMonth)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (records.isEmpty)
                  EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No records this month',
                    subtitle: 'No attendance records for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
                  )
                else
                  ListRow(children: records.map((r) => _HistoryRow(record: r)).toList()),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final AttendanceRecord record;
  const _HistoryRow({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final flagged = record.status == AttendanceStatus.flagged;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(record.date, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary))),
              StatusDot.attendance(context, record.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.login_rounded, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              Text('In: ${record.clockIn}', style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(width: 16),
              Icon(Icons.logout_rounded, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              Text('Out: ${record.clockOut ?? "—"}', style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
            ],
          ),
          if (flagged && record.flagReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 14, color: c.riskHigh),
                  const SizedBox(width: 8),
                  Expanded(child: Text(record.flagReason!, style: TextStyle(fontSize: 11.5, color: c.riskHigh, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
