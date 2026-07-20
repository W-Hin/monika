import 'package:flutter/material.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../../core/theme/app_colors_extension.dart';

class HrLeaveBalancesScreen extends StatefulWidget {
  const HrLeaveBalancesScreen({super.key});

  @override
  State<HrLeaveBalancesScreen> createState() => _HrLeaveBalancesScreenState();
}

class _HrLeaveBalancesScreenState extends State<HrLeaveBalancesScreen> {
  late List<LeaveBalance> _balances;

  @override
  void initState() {
    super.initState();
    _balances = List.from(DummyData.leaveBalances);
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
            onPressed: () {
              setState(() {
                final i = _balances.indexOf(balance);
                _balances[i] = LeaveBalance(
                  employeeName: balance.employeeName,
                  annualTotal: int.tryParse(annualController.text) ?? balance.annualTotal,
                  annualUsed: balance.annualUsed,
                  medicalTotal: int.tryParse(medicalController.text) ?? balance.medicalTotal,
                  medicalUsed: balance.medicalUsed,
                  emergencyTotal: int.tryParse(emergencyController.text) ?? balance.emergencyTotal,
                  emergencyUsed: balance.emergencyUsed,
                );
              });
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('✓ Leave entitlement updated for ${balance.employeeName}')),
              );
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const SectionHeader(title: 'Employee Leave Balances'),
            ListRow(children: _balances.map((b) => _BalanceRow(balance: b, onTap: () => _adjustBalance(b))).toList()),
          ],
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
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
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
