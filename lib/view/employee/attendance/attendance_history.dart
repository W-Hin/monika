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
  @override
  void initState() {
    super.initState();
    attendanceController.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Attendance History'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: attendanceController,
          builder: (context, _) {
            final now = DateTime.now();
            final records = attendanceController.history.where((r) => r.workDate.year == now.year && r.workDate.month == now.month).toList();
            final flagged = records.where((r) => r.status == AttendanceStatus.flagged).length;
            final late = records.where((r) => r.status == AttendanceStatus.late).length;
            // "Present" counts on-time and late alike — being late still
            // means they showed up. Only flagged clock-ins (or no record at
            // all) count against the rate.
            final present = records.where((r) => r.status == AttendanceStatus.onTime || r.status == AttendanceStatus.late).length;
            final rate = records.isEmpty ? 0 : ((present / records.length) * 100).round();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'This Month',
                        value: '$rate%',
                        icon: Icons.event_available_rounded,
                        iconColor: c.primary,
                        iconBg: c.primaryLight,
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
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionHeader(title: DateFormat('MMMM yyyy').format(DateTime.now())),
                if (records.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No attendance records yet',
                    subtitle: 'Clock in from the Home tab to start building your history.',
                  )
                else
                  ListRow(children: records.map((r) => _HistoryRow(record: r)).toList()),
              ],
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
