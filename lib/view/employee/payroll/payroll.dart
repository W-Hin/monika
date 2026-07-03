import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';

class PayrollScreen extends StatelessWidget {
  const PayrollScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final payroll = DummyData.currentPayroll;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Payroll Summary'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.kpiGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(payroll.month, style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Net Pay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  Text(
                    'RM ${payroll.netPay.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Base Salary',
                    value: 'RM ${payroll.baseSalary.toStringAsFixed(0)}',
                    icon: Icons.account_balance_wallet_outlined,
                    iconColor: AppColors.primary,
                    iconBg: AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Total Deductions',
                    value: 'RM ${payroll.deductions.toStringAsFixed(0)}',
                    icon: Icons.remove_circle_outline_rounded,
                    iconColor: AppColors.riskHigh,
                    iconBg: AppColors.riskHighBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Deduction Breakdown'),
            AppCard(
              child: Column(
                children: [
                  for (int i = 0; i < payroll.items.length; i++) ...[
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppColors.riskHigh, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            payroll.items[i].label,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '- RM ${payroll.items[i].amount.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12.5, color: AppColors.riskHigh, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (i != payroll.items.length - 1) const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Divider(height: 1),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'Payment History'),
            ...['May 2026', 'April 2026', 'March 2026'].map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(m, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    const Text('RM 4,420.00', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 18),
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