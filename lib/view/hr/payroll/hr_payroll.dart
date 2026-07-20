import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrPayrollScreen extends StatelessWidget {
  const HrPayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = DummyData.payrollByEmployee;
    final totalNet = summaries.fold<double>(0, (sum, p) => sum + p.netPay);
    final totalDeductions = summaries.fold<double>(0, (sum, p) => sum + p.deductions);

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll Summaries')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Total Net Pay (${summaries.first.month})',
                    value: 'RM ${totalNet.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Total Deductions',
                    value: 'RM ${totalDeductions.toStringAsFixed(0)}',
                    icon: Icons.remove_circle_outline_rounded,
                    iconColor: AppColors.riskHigh,
                    iconBg: AppColors.riskHighBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Per-Employee Summary'),
            ...summaries.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PayrollTile(summary: p),
                )),
          ],
        ),
      ),
    );
  }
}

class _PayrollTile extends StatelessWidget {
  final PayrollSummary summary;
  const _PayrollTile({required this.summary});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(summary.employeeName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
              Text('RM ${summary.netPay.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Base RM ${summary.baseSalary.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(width: 10),
              if (summary.deductions > 0)
                Text('− RM ${summary.deductions.toStringAsFixed(2)} deducted', style: const TextStyle(fontSize: 12, color: AppColors.riskHigh, fontWeight: FontWeight.w600)),
            ],
          ),
          if (summary.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...summary.items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.riskHigh, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted))),
                      Text('RM ${i.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
