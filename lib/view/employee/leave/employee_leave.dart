import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
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
    final c = context.colors;
    final apps = DummyData.employeeLeaveApplications;
    final balance = DummyData.myLeaveBalance;

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
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
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
                Expanded(child: _BalanceCard(label: 'Annual', value: '${balance.annualRemaining}', total: '${balance.annualTotal}', color: c.primary)),
                const SizedBox(width: 10),
                Expanded(child: _BalanceCard(label: 'Medical', value: '${balance.medicalRemaining}', total: '${balance.medicalTotal}', color: c.infoBlue)),
                const SizedBox(width: 10),
                Expanded(child: _BalanceCard(label: 'Emergency', value: '${balance.emergencyRemaining}', total: '${balance.emergencyTotal}', color: c.amber)),
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
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
                TextSpan(text: '/$total', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 11, color: c.textSecondary, fontWeight: FontWeight.w600)),
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
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(app.leaveType, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              ),
              StatusDot.leave(context, app.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.date_range_rounded, size: 14, color: c.textMuted),
              const SizedBox(width: 6),
              Text('${app.startDate} – ${app.endDate} · ${app.days} day(s)', style: TextStyle(fontSize: 12, color: c.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(app.reason, style: TextStyle(fontSize: 12.5, color: c.textMuted, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}