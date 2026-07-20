import 'package:flutter/material.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../../core/theme/app_colors_extension.dart';

class HrPayrollScreen extends StatelessWidget {
  const HrPayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final summaries = DummyData.payrollByEmployee;
    final totalNet = summaries.fold<double>(0, (sum, p) => sum + p.netPay);
    final totalDeductions = summaries.fold<double>(0, (sum, p) => sum + p.deductions);
    final c = context.colors;

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
                    iconColor: c.primary,
                    iconBg: c.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Total Deductions',
                    value: 'RM ${totalDeductions.toStringAsFixed(0)}',
                    icon: Icons.remove_circle_outline_rounded,
                    iconColor: c.riskHigh,
                    iconBg: c.riskHighBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Per-Employee Summary'),
            ListRow(children: summaries.map((p) => _PayrollRow(summary: p)).toList()),
          ],
        ),
      ),
    );
  }
}

class _PayrollRow extends StatelessWidget {
  final PayrollSummary summary;
  const _PayrollRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(summary.employeeName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary))),
              Text('RM ${summary.netPay.toStringAsFixed(2)}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: c.primary, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('Base RM ${summary.baseSalary.toStringAsFixed(0)}',
                style: TextStyle(fontSize: 12, color: c.textSecondary, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              const SizedBox(width: 10),
              if (summary.deductions > 0)
                Text('− RM ${summary.deductions.toStringAsFixed(2)} deducted',
                  style: TextStyle(fontSize: 12, color: c.riskHigh, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
            ],
          ),
          if (summary.items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...summary.items.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: c.riskHigh, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i.label, style: TextStyle(fontSize: 11.5, color: c.textMuted))),
                      Text('RM ${i.amount.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 11.5, color: c.textMuted, fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()]),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
