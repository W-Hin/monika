import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../controller/payroll_controller.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  @override
  void initState() {
    super.initState();
    payrollController.loadMy();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Payroll Summary'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: payrollController,
          builder: (context, _) {
            if (payrollController.loading && payrollController.myHistory.isEmpty && payrollController.myCurrentMonth == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final payroll = payrollController.myCurrentMonth;
            final history = payrollController.myHistory.where((h) => h.dbId != payroll?.dbId).toList();

            return RefreshIndicator(
              onRefresh: payrollController.loadMy,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (payroll == null)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Not generated yet',
                    subtitle: 'HR hasn\'t generated this month\'s payroll summary yet. Check back later.',
                  )
                else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: c.kpiGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [c.shadowTinted()],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(payroll.month, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        const Text('Net Pay', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          'RM ${payroll.netPay.toStringAsFixed(2)}',
                          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, fontFeatures: [FontFeature.tabularFigures()]),
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
                          iconColor: c.primary,
                          iconBg: c.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Total Deductions',
                          value: 'RM ${payroll.deductions.toStringAsFixed(0)}',
                          icon: Icons.remove_circle_outline_rounded,
                          iconColor: c.riskHigh,
                          iconBg: c.riskHighBg,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const SectionHeader(title: 'Deduction Breakdown'),
                  if (payroll.items.isEmpty)
                    AppCard(
                      child: Text('No deductions this month.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                    )
                  else
                    AppCard(
                      child: Column(
                        children: [
                          for (int i = 0; i < payroll.items.length; i++) ...[
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(color: c.riskHigh, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    payroll.items[i].label,
                                    style: TextStyle(fontSize: 12.5, color: c.textPrimary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                                Text(
                                  '- RM ${payroll.items[i].amount.toStringAsFixed(2)}',
                                  style: TextStyle(fontSize: 12.5, color: c.riskHigh, fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()]),
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
                ],
                const SectionHeader(title: 'Payment History'),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No previous payroll records.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  )
                else
                  ...history.map((h) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.receipt_long_outlined, size: 16, color: c.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(h.month, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                              Text('RM ${h.netPay.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary, fontFeatures: const [FontFeature.tabularFigures()])),
                            ],
                          ),
                        ),
                      )),
              ],
              ),
            );
          },
        ),
      ),
    );
  }
}
