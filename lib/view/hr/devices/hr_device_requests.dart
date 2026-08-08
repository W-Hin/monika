import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/device_request_controller.dart';

class HrDeviceRequestsScreen extends StatefulWidget {
  const HrDeviceRequestsScreen({super.key});

  @override
  State<HrDeviceRequestsScreen> createState() => _HrDeviceRequestsScreenState();
}

class _HrDeviceRequestsScreenState extends State<HrDeviceRequestsScreen> {
  @override
  void initState() {
    super.initState();
    deviceRequestController.loadAllForHr();
  }

  Future<void> _handleDecision(DeviceChangeRequest request, bool approve) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          approve ? 'Approve Device Change' : 'Reject Request',
          style: TextStyle(
            color: approve ? context.colors.primary : context.colors.riskHigh,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        content: Text(
          approve
              ? '${request.employeeName}\'s current device will be unpaired. Their next successful clock-in will register the new one.'
              : 'This request from ${request.employeeName} will be marked rejected.',
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await deviceRequestController.decide(request: request, approve: approve);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success
                      ? (approve ? '✓ Device unpaired for ${request.employeeName}' : '✗ Request rejected for ${request.employeeName}')
                      : deviceRequestController.errorMessage ?? 'Could not update this request'),
                  backgroundColor: success ? (approve ? context.colors.primary : context.colors.riskHigh) : context.colors.riskHigh,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: approve ? context.colors.primary : context.colors.riskHigh),
            child: Text(approve ? 'Confirm' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: Navigator.canPop(context),
        title: const Text('Device Change Requests'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: deviceRequestController,
          builder: (context, _) {
            if (deviceRequestController.loading && deviceRequestController.allRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (deviceRequestController.errorMessage != null && deviceRequestController.allRequests.isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load device requests',
                  subtitle: deviceRequestController.errorMessage!,
                  onRetry: deviceRequestController.loadAllForHr,
                ),
              );
            }
            final all = deviceRequestController.allRequests;
            final pending = all.where((r) => r.status == 'pending').toList();
            final processed = all.where((r) => r.status != 'pending').toList();

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
                        label: 'Processed',
                        value: '${processed.length}',
                        icon: Icons.check_circle_outline_rounded,
                        iconColor: c.primary,
                        iconBg: c.primaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (pending.isNotEmpty) ...[
                  SectionHeader(title: 'Pending Requests (${pending.length})'),
                  ...pending.map((r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(
                          request: r,
                          onApprove: () => _handleDecision(r, true),
                          onReject: () => _handleDecision(r, false),
                        ),
                      )),
                  const SizedBox(height: 8),
                ] else
                  const EmptyState(
                    icon: Icons.phone_android_rounded,
                    title: 'All caught up!',
                    subtitle: 'No pending device change requests.',
                  ),
                if (processed.isNotEmpty) ...[
                  const SectionHeader(title: 'Recently Processed'),
                  ListRow(children: processed.map((r) => _ProcessedRow(request: r)).toList()),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DeviceChangeRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _RequestCard({required this.request, required this.onApprove, required this.onReject});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = request.employeeName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
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
                    Text(request.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    Text('Device change request', style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w600)),
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
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(request.reason, style: TextStyle(fontSize: 12.5, color: c.textSecondary))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Reject', onPressed: onReject, icon: Icons.close_rounded)),
              const SizedBox(width: 10),
              Expanded(child: PrimaryButton(label: 'Approve', onPressed: onApprove, icon: Icons.check_rounded)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProcessedRow extends StatelessWidget {
  final DeviceChangeRequest request;
  const _ProcessedRow({required this.request});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = request.employeeName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
    final approved = request.status == 'approved';
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
                Text(request.employeeName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                Text(request.reason, style: TextStyle(fontSize: 11.5, color: c.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Icon(approved ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 18, color: approved ? c.primary : c.riskHigh),
        ],
      ),
    );
  }
}
