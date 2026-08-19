import 'package:flutter/material.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/leave_controller.dart';
import '../../../core/theme/app_colors_extension.dart';

class HrLeaveBalancesScreen extends StatefulWidget {
  const HrLeaveBalancesScreen({super.key});

  @override
  State<HrLeaveBalancesScreen> createState() => _HrLeaveBalancesScreenState();
}

class _HrLeaveBalancesScreenState extends State<HrLeaveBalancesScreen> {
  String _departmentFilter = 'All Departments';

  @override
  void initState() {
    super.initState();
    leaveController.loadAllBalancesForHr();
  }

  void _adjustBalance(LeaveBalance balance) {
    final annualController = TextEditingController(text: '${balance.annualTotal}');
    final medicalController = TextEditingController(text: '${balance.medicalTotal}');
    final emergencyController = TextEditingController(text: '${balance.emergencyTotal}');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Adjust Entitlement — ${balance.employeeName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: annualController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Annual Leave (days)')),
            const SizedBox(height: 10),
            TextField(controller: medicalController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Medical Leave (days)')),
            const SizedBox(height: 10),
            TextField(controller: emergencyController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Emergency Leave (days)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await leaveController.updateEntitlement(
                  balance: balance,
                  annualTotal: int.tryParse(annualController.text) ?? balance.annualTotal,
                  medicalTotal: int.tryParse(medicalController.text) ?? balance.medicalTotal,
                  emergencyTotal: int.tryParse(emergencyController.text) ?? balance.emergencyTotal,
                );
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('✓ Leave entitlement updated for ${balance.employeeName}')),
                );
              } catch (e) {
                navigator.pop();
                messenger.showSnackBar(
                  SnackBar(content: Text('Could not update entitlement: $e')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Balances')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: leaveController,
          builder: (context, _) {
            if (leaveController.loadingBalances && leaveController.allBalances.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final allBalances = leaveController.allBalances;
            if (allBalances.isEmpty) {
              return const EmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'No leave balances found',
                subtitle: 'Balances are provisioned automatically when an employee account is created.',
              );
            }
            final departments = ['All Departments', ...allBalances.map((b) => b.department).toSet().toList()..sort()];
            final balances = _departmentFilter == 'All Departments'
                ? allBalances
                : allBalances.where((b) => b.department == _departmentFilter).toList();
            return RefreshIndicator(
              onRefresh: leaveController.loadAllBalancesForHr,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Builder(
                  builder: (context) {
                    final c = context.colors;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _departmentFilter,
                          isExpanded: true,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c.textMuted),
                          borderRadius: BorderRadius.circular(12),
                          items: departments
                              .map((d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(d, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _departmentFilter = v);
                          },
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                SectionHeader(title: 'Employee Leave Balances (${balances.length})'),
                if (balances.isEmpty)
                  const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No employees in this department',
                    subtitle: 'Try a different department filter.',
                  )
                else
                  ListRow(children: balances.map((b) => _BalanceRow(balance: b, onTap: () => _adjustBalance(b))).toList()),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final LeaveBalance balance;
  final VoidCallback onTap;
  const _BalanceRow({required this.balance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(balance.employeeName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary))),
                Icon(Icons.tune_rounded, size: 16, color: c.textMuted),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _BalancePill(label: 'Annual', remaining: balance.annualRemaining, total: balance.annualTotal, color: c.primary)),
                const SizedBox(width: 8),
                Expanded(child: _BalancePill(label: 'Medical', remaining: balance.medicalRemaining, total: balance.medicalTotal, color: c.infoBlue)),
                const SizedBox(width: 8),
                Expanded(child: _BalancePill(label: 'Emergency', remaining: balance.emergencyRemaining, total: balance.emergencyTotal, color: c.amber)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancePill extends StatelessWidget {
  final String label;
  final int remaining;
  final int total;
  final Color color;
  const _BalancePill({required this.label, required this.remaining, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$remaining/$total',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 10.5, color: c.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
