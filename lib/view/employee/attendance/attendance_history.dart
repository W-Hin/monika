import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final records = DummyData.attendanceHistory;
    final flagged = records.where((r) => r.status == AttendanceStatus.flagged).length;
    final late = records.where((r) => r.status == AttendanceStatus.late).length;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Attendance History'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'This Month',
                    value: '96%',
                    icon: Icons.event_available_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Late Arrivals',
                    value: '$late',
                    icon: Icons.schedule_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Flagged',
                    value: '$flagged',
                    icon: Icons.flag_outlined,
                    iconColor: AppColors.riskHigh,
                    iconBg: AppColors.riskHighBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'June 2026'),
            ...records.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _HistoryTile(record: r),
            )),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final AttendanceRecord record;
  const _HistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final flagged = record.status == AttendanceStatus.flagged;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(record.date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ),
              StatusPill.attendance(record.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.login_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('In: ${record.clockIn}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              const SizedBox(width: 16),
              const Icon(Icons.logout_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('Out: ${record.clockOut ?? "—"}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ),
          if (flagged && record.flagReason != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.riskHighBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.riskHigh),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      record.flagReason!,
                      style: const TextStyle(fontSize: 11.5, color: AppColors.riskHigh, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}