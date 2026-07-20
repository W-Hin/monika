import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

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
            ..._balances.map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => _adjustBalance(b),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(b.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
                            const Icon(Icons.tune_rounded, size: 16, color: AppColors.textMuted),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _BalancePill(label: 'Annual', remaining: b.annualRemaining, total: b.annualTotal, color: AppColors.primary)),
                            const SizedBox(width: 8),
                            Expanded(child: _BalancePill(label: 'Medical', remaining: b.medicalRemaining, total: b.medicalTotal, color: AppColors.infoBlue)),
                            const SizedBox(width: 8),
                            Expanded(child: _BalancePill(label: 'Emergency', remaining: b.emergencyRemaining, total: b.emergencyTotal, color: AppColors.amber)),
                          ],
                        ),
                      ],
                    ),
                  ),
                )),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$remaining/$total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
