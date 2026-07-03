import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrApprovalsScreen extends StatefulWidget {
  const HrApprovalsScreen({super.key});

  @override
  State<HrApprovalsScreen> createState() => _HrApprovalsScreenState();
}

class _HrApprovalsScreenState extends State<HrApprovalsScreen> {
  late List<LeaveApplication> _applications;

  @override
  void initState() {
    super.initState();
    _applications = List.from(DummyData.pendingApprovalsForHr);
  }

  void _handleDecision(int index, bool approve) {
    showDialog(
      context: context,
      builder: (_) => _DecisionDialog(
        app: _applications[index],
        approve: approve,
        onConfirm: (reason) {
          setState(() {
            final updated = LeaveApplication(
              id: _applications[index].id,
              employeeName: _applications[index].employeeName,
              leaveType: _applications[index].leaveType,
              startDate: _applications[index].startDate,
              endDate: _applications[index].endDate,
              days: _applications[index].days,
              reason: _applications[index].reason,
              status: approve ? LeaveStatus.approved : LeaveStatus.rejected,
            );
            _applications[index] = updated;
          });
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                approve
                    ? '✓ Leave approved for ${_applications[index].employeeName}'
                    : '✗ Leave rejected for ${_applications[index].employeeName}',
              ),
              backgroundColor: approve ? AppColors.primary : AppColors.riskHigh,
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pending = _applications.where((a) => a.status == LeaveStatus.pending).toList();
    final processed = _applications.where((a) => a.status != LeaveStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Leave Approvals')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Pending',
                    value: '${pending.length}',
                    icon: Icons.pending_actions_rounded,
                    iconColor: AppColors.amber,
                    iconBg: AppColors.amberBg,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Approved Today',
                    value: '${processed.where((a) => a.status == LeaveStatus.approved).length}',
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Rejected',
                    value: '${processed.where((a) => a.status == LeaveStatus.rejected).length}',
                    icon: Icons.cancel_outlined,
                    iconColor: AppColors.riskHigh,
                    iconBg: AppColors.riskHighBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (pending.isNotEmpty) ...[
              SectionHeader(title: 'Pending Approval (${pending.length})'),
              ...pending.asMap().entries.map((e) {
                final i = _applications.indexOf(e.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ApprovalCard(
                    app: e.value,
                    onApprove: () => _handleDecision(i, true),
                    onReject: () => _handleDecision(i, false),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ] else
              const EmptyState(
                icon: Icons.check_circle_outline_rounded,
                title: 'All caught up!',
                subtitle: 'No pending leave applications at this time.',
              ),

            if (processed.isNotEmpty) ...[
              const SectionHeader(title: 'Recently Processed'),
              ...processed.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: a.employeeName.split(' ').map((w) => w[0]).take(2).join(),
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.employeeName, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            Text('${a.leaveType} · ${a.days} day(s)', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      StatusPill.leave(a.status),
                    ],
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final LeaveApplication app;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _ApprovalCard({required this.app, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final initials = app.employeeName.split(' ').map((w) => w[0]).take(2).join();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(initials: initials, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text(app.leaveType, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(100)),
                child: const Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.amber)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                _InfoRow(icon: Icons.date_range_rounded, label: '${app.startDate} – ${app.endDate}  (${app.days} day${app.days > 1 ? 's' : ''})'),
                const SizedBox(height: 6),
                _InfoRow(icon: Icons.notes_rounded, label: app.reason),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Reject',
                  onPressed: onReject,
                  icon: Icons.close_rounded,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: 'Approve',
                  onPressed: onApprove,
                  icon: Icons.check_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary))),
      ],
    );
  }
}

class _DecisionDialog extends StatefulWidget {
  final LeaveApplication app;
  final bool approve;
  final void Function(String reason) onConfirm;

  const _DecisionDialog({required this.app, required this.approve, required this.onConfirm});

  @override
  State<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends State<_DecisionDialog> {
  final _reasonController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.approve ? 'Approve Leave' : 'Reject Leave',
        style: TextStyle(
          color: widget.approve ? AppColors.primary : AppColors.riskHigh,
          fontWeight: FontWeight.w800,
          fontSize: 17,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.app.employeeName} · ${widget.app.leaveType} · ${widget.app.days} day(s)',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            widget.approve ? 'Add a note (optional)' : 'Rejection reason (required)',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: widget.approve
                  ? 'e.g. Approved. Enjoy your leave!'
                  : 'e.g. Insufficient leave balance for this period',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => widget.onConfirm(_reasonController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.approve ? AppColors.primary : AppColors.riskHigh,
          ),
          child: Text(widget.approve ? 'Confirm Approval' : 'Confirm Rejection'),
        ),
      ],
    );
  }
}