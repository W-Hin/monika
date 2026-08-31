import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/device_request_controller.dart';
import '../../../controller/employee_controller.dart';
import '../../../connection/employee_service.dart';

class HrDeviceRequestsScreen extends StatefulWidget {
  const HrDeviceRequestsScreen({super.key});

  @override
  State<HrDeviceRequestsScreen> createState() => _HrDeviceRequestsScreenState();
}

class _HrDeviceRequestsScreenState extends State<HrDeviceRequestsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    deviceRequestController.loadAllForHr();
    if (employeeController.employees.isEmpty) {
      employeeController.loadEmployees();
    }
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _unpairDevice(TeamMemberSummary emp) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Unpair Device'),
          content: Text(
            'This will unbind "${emp.registeredDevice}" from ${emp.name}\'s account. They will need to register a new device on their next clock-in attempt.',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: c.riskHigh),
              onPressed: () async {
                try {
                  await EmployeeService.resetDeviceBinding(emp.uuid);
                  employeeController.updateLocal(
                    emp.copyWith(registeredDevice: 'Not yet registered'),
                  );
                  if (!mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✓ Device unpaired for ${emp.name}'),
                    ),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not unpair device: $e')),
                  );
                }
              },
              child: const Text('Unpair'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleCancel(DeviceChangeRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel This Request?'),
        content: Text(
          'This withdraws ${request.employeeName}\'s request without recording it as approved or rejected. They can submit a new one again after 24 hours.',
          style: TextStyle(fontSize: 12.5, color: context.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep Request')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Cancel Request', style: TextStyle(color: context.colors.riskHigh)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final success = await deviceRequestController.cancelForHr(request);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '✓ Request cancelled' : deviceRequestController.errorMessage ?? 'Could not cancel this request')),
    );
  }

  Future<void> _handleDecision(
    DeviceChangeRequest request,
    bool approve,
  ) async {
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
          style: TextStyle(
            fontSize: 12.5,
            color: context.colors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final success = await deviceRequestController.decide(
                request: request,
                approve: approve,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? (approve
                              ? '✓ Device unpaired for ${request.employeeName}'
                              : '✗ Request rejected for ${request.employeeName}')
                        : deviceRequestController.errorMessage ??
                              'Could not update this request',
                  ),
                  backgroundColor: success
                      ? (approve
                            ? context.colors.primary
                            : context.colors.riskHigh)
                      : context.colors.riskHigh,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve
                  ? context.colors.primary
                  : context.colors.riskHigh,
            ),
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
          listenable: Listenable.merge([
            deviceRequestController,
            employeeController,
          ]),
          builder: (context, _) {
            if (deviceRequestController.loading &&
                deviceRequestController.allRequests.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (deviceRequestController.errorMessage != null &&
                deviceRequestController.allRequests.isEmpty) {
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

            return RefreshIndicator(
              onRefresh: deviceRequestController.loadAllForHr,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
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
                    SectionHeader(
                      title: 'Pending Requests (${pending.length})',
                    ),
                    ...pending.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _RequestCard(
                          request: r,
                          // Same conflict-of-interest guard as leave decisions
                          // and self-employment edits — also enforced server-
                          // side (migration 0027) so a bypassed client can't
                          // approve/reject its own request either.
                          isSelf: r.userUuid == Supabase.instance.client.auth.currentUser?.id,
                          onApprove: () => _handleDecision(r, true),
                          onReject: () => _handleDecision(r, false),
                          onCancel: () => _handleCancel(r),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    const EmptyState(
                      icon: Icons.phone_android_rounded,
                      title: 'All caught up!',
                      subtitle: 'No pending device change requests.',
                    ),
                  if (processed.isNotEmpty) ...[
                    const SectionHeader(title: 'Recently Processed'),
                    ListRow(
                      children: processed
                          .map((r) => _ProcessedRow(request: r))
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],
                  const SectionHeader(title: 'Manual Device Unpair'),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by employee name…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _searchQuery.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => _searchController.clear(),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_searchQuery.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        final matches = employeeController.employees
                            .where(
                              (emp) =>
                                  emp.name.toLowerCase().contains(
                                    _searchQuery,
                                  ) &&
                                  emp.registeredDevice != 'Not yet registered',
                            )
                            .toList();
                        if (matches.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No employee with a registered device matches "$_searchQuery".',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textMuted,
                              ),
                            ),
                          );
                        }
                        return ListRow(
                          children: matches
                              .map(
                                (emp) => _UnpairRow(
                                  employee: emp,
                                  onUnpair: () => _unpairDevice(emp),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DeviceChangeRequest request;
  final bool isSelf;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onCancel;
  const _RequestCard({
    required this.request,
    required this.isSelf,
    required this.onApprove,
    required this.onReject,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = request.employeeName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join();
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
                    Text(
                      request.employeeName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Device change request',
                      style: TextStyle(
                        fontSize: 12,
                        color: c.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: c.amberBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'Pending',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.amber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notes_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    request.reason,
                    style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (isSelf)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This is your own request — another HR admin must approve or reject it.',
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ),
                ],
              ),
            )
          else ...[
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
            Center(
              child: TextButton(
                onPressed: onCancel,
                child: Text('Cancel Request Instead', style: TextStyle(color: c.textMuted, fontSize: 12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnpairRow extends StatelessWidget {
  final TeamMemberSummary employee;
  final VoidCallback onUnpair;
  const _UnpairRow({required this.employee, required this.onUnpair});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = employee.name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join();
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
                Text(
                  employee.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  employee.registeredDevice,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(onPressed: onUnpair, child: const Text('Unpair')),
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
    final initials = request.employeeName
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join();
    final approved = request.status == 'approved';
    final cancelled = request.status == 'cancelled';
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
                Text(
                  request.employeeName,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                Text(
                  cancelled ? 'Cancelled' : request.reason,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Icon(
            approved
                ? Icons.check_circle_rounded
                : cancelled
                    ? Icons.undo_rounded
                    : Icons.cancel_rounded,
            size: 18,
            color: approved
                ? c.primary
                : cancelled
                    ? c.textMuted
                    : c.riskHigh,
          ),
        ],
      ),
    );
  }
}
