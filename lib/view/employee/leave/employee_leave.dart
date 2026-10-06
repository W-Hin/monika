import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../model/models.dart';
import '../../../controller/leave_controller.dart';
import '../leave/leave_apply.dart';

class EmployeeLeaveScreen extends StatefulWidget {
  const EmployeeLeaveScreen({super.key});

  @override
  State<EmployeeLeaveScreen> createState() => _EmployeeLeaveScreenState();
}

class _EmployeeLeaveScreenState extends State<EmployeeLeaveScreen> {
  @override
  void initState() {
    super.initState();
    leaveController.loadMy();
  }

  Future<void> _confirmCancel(LeaveApplication app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel This Application?'),
        content: Text('Your ${app.leaveType.toLowerCase()} request for ${app.startDate} – ${app.endDate} will be withdrawn. You can apply again later.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep It')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Cancel Application')),
        ],
      ),
    );
    if (confirmed != true) return;
    final ok = await leaveController.cancel(app);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '✓ Application cancelled' : leaveController.myErrorMessage ?? 'Could not cancel the application')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Leave'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplyScreen()));
                leaveController.loadMy();
              },
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
        child: ListenableBuilder(
          listenable: leaveController,
          builder: (context, _) {
            if (leaveController.loadingMy && leaveController.myBalance == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final balance = leaveController.myBalance;
            final apps = leaveController.myApplications;

            return RefreshIndicator(
              onRefresh: leaveController.loadMy,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(child: _BalanceCard(label: 'Annual', value: '${balance?.annualRemaining ?? 0}', total: '${balance?.annualTotal ?? 0}', color: c.primary)),
                    const SizedBox(width: 10),
                    Expanded(child: _BalanceCard(label: 'Medical', value: '${balance?.medicalRemaining ?? 0}', total: '${balance?.medicalTotal ?? 0}', color: c.infoBlue)),
                    const SizedBox(width: 10),
                    Expanded(child: _BalanceCard(label: 'Emergency', value: '${balance?.emergencyRemaining ?? 0}', total: '${balance?.emergencyTotal ?? 0}', color: c.amber)),
                  ],
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: 'Apply for Leave',
                  icon: Icons.add_circle_outline_rounded,
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplyScreen()));
                    leaveController.loadMy();
                  },
                ),
                const SizedBox(height: 24),
                const SectionHeader(title: 'My Applications'),
                if (apps.isEmpty)
                  const EmptyState(
                    icon: Icons.event_note_outlined,
                    title: 'No applications yet',
                    subtitle: 'Applications you submit will show up here.',
                  )
                else
                  ...apps.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: LeaveApplicationTile(app: a, onCancel: () => _confirmCancel(a)),
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

/// One of the employee's own applications. A Pending one can be cancelled.
class LeaveApplicationTile extends StatelessWidget {
  final LeaveApplication app;
  final VoidCallback onCancel;
  const LeaveApplicationTile({super.key, required this.app, required this.onCancel});

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
          if (app.status == LeaveStatus.pending)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                icon: Icon(Icons.close_rounded, size: 16, color: c.riskHigh),
                label: Text('Cancel Application', style: TextStyle(fontSize: 12.5, color: c.riskHigh)),
              ),
            ),
        ],
      ),
    );
  }
}
