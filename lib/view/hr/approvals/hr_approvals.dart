import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../model/models.dart';
import '../../../controller/leave_controller.dart';
import '../leave/leave_balances.dart';

class HrApprovalsScreen extends StatefulWidget {
  // Explicit, not derived from Navigator.canPop() — this screen is also
  // an IndexedStack tab root inside HrShell, which itself can be pushed
  // on top of EmployeeShell (via "Switch to Admin View"). In that state
  // canPop(context) is true for every tab (they all share HrShell's
  // position in the stack), so a canPop-based back arrow on the Approvals
  // *tab* would pop the whole HrShell and eject the admin to their
  // employee view instead of just leaving this screen. Only the instance
  // explicitly pushed from a shortcut (e.g. the Dashboard) sets this true.
  final bool showBackButton;
  const HrApprovalsScreen({super.key, this.showBackButton = false});

  @override
  State<HrApprovalsScreen> createState() => _HrApprovalsScreenState();
}

class _HrApprovalsScreenState extends State<HrApprovalsScreen> {
  @override
  void initState() {
    super.initState();
    leaveController.loadAllForHr();
  }

  Future<void> _handleDecision(LeaveApplication app, bool approve) async {
    showDialog(
      context: context,
      builder: (_) => _DecisionDialog(
        app: app,
        approve: approve,
        onConfirm: (reason) async {
          Navigator.of(context).pop();
          try {
            await leaveController.decide(app: app, approve: approve);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(approve ? '✓ Leave approved for ${app.employeeName}' : '✗ Leave rejected for ${app.employeeName}'),
                backgroundColor: approve ? context.colors.primary : context.colors.riskHigh,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Could not update this application: $e'), backgroundColor: context.colors.riskHigh),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final myUid = Supabase.instance.client.auth.currentUser?.id;
    // This screen is for reviewing OTHERS' requests - an HR admin's own
    // leave applications are handled the same way anyone else's are
    // (their own Employee view, decided by a different HR admin), so
    // they're excluded here entirely rather than shown with disabled
    // actions.
    final reviewable = leaveController.allApplications.where((a) => a.userUuid != myUid).toList();
    final pending = reviewable.where((a) => a.status == LeaveStatus.pending).toList();
    final processed = reviewable.where((a) => a.status != LeaveStatus.pending).toList();

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: const Text('Leave Approvals'),
        actions: [
          IconButton(
            tooltip: 'Leave Balances',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HrLeaveBalancesScreen())),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: leaveController,
          builder: (context, _) {
            if (leaveController.loading && leaveController.allApplications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (leaveController.errorMessage != null && leaveController.allApplications.isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load leave applications',
                  subtitle: leaveController.errorMessage!,
                  onRetry: leaveController.loadAllForHr,
                ),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Pending',
                        value: '${pending.length}',
                        icon: Icons.pending_actions_rounded,
                        iconColor: c.amber,
                        iconBg: c.amberBg,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Approved',
                        value: '${processed.where((a) => a.status == LeaveStatus.approved).length}',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: c.primary,
                        iconBg: c.primaryLight,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Rejected',
                        value: '${processed.where((a) => a.status == LeaveStatus.rejected).length}',
                        icon: Icons.cancel_outlined,
                        iconColor: c.riskHigh,
                        iconBg: c.riskHighBg,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                if (pending.isNotEmpty) ...[
                  SectionHeader(title: 'Pending Approval (${pending.length})'),
                  ...pending.map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ApprovalCard(
                          app: a,
                          onApprove: () => _handleDecision(a, true),
                          onReject: () => _handleDecision(a, false),
                        ),
                      )),
                  const SizedBox(height: 8),
                ] else
                  const EmptyState(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'All caught up!',
                    subtitle: 'No pending leave applications at this time.',
                  ),

                if (processed.isNotEmpty) ...[
                  const SectionHeader(title: 'Recently Processed'),
                  ListRow(children: processed.map((a) => _ProcessedRow(app: a)).toList()),
                ],
              ],
            );
          },
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
    final c = context.colors;
    final initials = app.employeeName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
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
                    Text(app.leaveType, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: c.amberBg, borderRadius: BorderRadius.circular(100)),
                child: Text('Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.amber)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
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
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: c.textMuted),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
      ],
    );
  }
}

// The optional note/reason text isn't persisted anywhere yet - the
// leave_applications table only tracks status/decided_by/decided_at, no
// note column. Kept as a courtesy field for the HR admin's own reference
// while deciding; a real audit-trail note is a natural next addition if
// ever needed.
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
    final c = context.colors;
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.approve ? 'Approve Leave' : 'Reject Leave',
        style: TextStyle(
          color: widget.approve ? c.primary : c.riskHigh,
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
            style: TextStyle(fontSize: 12.5, color: c.textSecondary),
          ),
          const SizedBox(height: 16),
          Text(
            widget.approve ? 'Add a note (optional)' : 'Rejection reason (optional)',
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
            backgroundColor: widget.approve ? c.primary : c.riskHigh,
          ),
          child: Text(widget.approve ? 'Confirm Approval' : 'Confirm Rejection'),
        ),
      ],
    );
  }
}

class _ProcessedRow extends StatelessWidget {
  final LeaveApplication app;
  const _ProcessedRow({required this.app});

  @override
  Widget build(BuildContext context) {
    final initials = app.employeeName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          InitialsAvatar(initials: initials, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(app.employeeName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text('${app.leaveType} · ${app.days} day(s)', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          StatusDot.leave(context, app.status),
        ],
      ),
    );
  }
}
