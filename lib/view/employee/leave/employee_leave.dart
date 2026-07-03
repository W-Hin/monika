import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../leave/leave_apply.dart';

class EmployeeLeaveScreen extends StatelessWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final apps = DummyData.employeeLeaveApplications;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplyScreen())),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
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
            Row(
              children: [
                Expanded(child: _BalanceCard(label: 'Annual', value: '9', total: '14', color: AppColors.primary)),
                const SizedBox(width: 10),
                Expanded(child: _BalanceCard(label: 'Medical', value: '11', total: '14', color: AppColors.infoBlue)),
                const SizedBox(width: 10),
                Expanded(child: _BalanceCard(label: 'Emergency', value: '3', total: '3', color: AppColors.amber)),
              ],
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Apply for Leave',
              icon: Icons.add_circle_outline_rounded,
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplyScreen())),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'My Applications'),
            ...apps.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaveTile(app: a),
            )),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final String label;
  final String value;
  final String total;
  final Color color;
  const _BalanceCard({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                TextSpan(text: '/$total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _LeaveTile extends StatelessWidget {
  final LeaveApplication app;
  const _LeaveTile({required this.app});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(app.leaveType, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              StatusPill.leave(app.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.date_range_rounded, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text('${app.startDate} – ${app.endDate} · ${app.days} day(s)', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(app.reason, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}