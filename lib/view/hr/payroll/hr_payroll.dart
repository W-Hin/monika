import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/buttons.dart';
import '../../../model/models.dart';
import '../../../controller/payroll_controller.dart';
import '../../../core/theme/app_colors_extension.dart';

class HrPayrollScreen extends StatefulWidget {
  const HrPayrollScreen({super.key});

  @override
  State<HrPayrollScreen> createState() => _HrPayrollScreenState();
}

class _HrPayrollScreenState extends State<HrPayrollScreen> {
  static final _monthLabel = DateFormat('MMMM yyyy');

  @override
  void initState() {
    super.initState();
    payrollController.loadAllForHr();
  }

  void _changeMonth(int deltaMonths) {
    final current = payrollController.hrSelectedMonth;
    final next = DateTime(current.year, current.month + deltaMonths, 1);
    payrollController.loadAllForHr(month: next);
  }

  Future<void> _confirmGenerate() async {
    final month = payrollController.hrSelectedMonth;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Generate Payroll', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Text(
          'This computes and saves a payroll summary for every active employee for ${_monthLabel.format(month)}, based on their base salary and late-arrival deductions. Running it again for the same month replaces the previous result.',
          style: TextStyle(fontSize: 12.5, color: dialogContext.colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Generate')),
        ],
      ),
    );
    if (confirmed != true) return;

    final success = await payrollController.generateForMonth(month);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✓ Payroll generated for ${_monthLabel.format(month)}' : payrollController.errorMessage ?? 'Could not generate payroll'),
        backgroundColor: success ? context.colors.primary : context.colors.riskHigh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Payroll Summaries')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: payrollController,
          builder: (context, _) {
            final summaries = payrollController.allForMonth;
            final totalNet = summaries.fold<double>(0, (sum, p) => sum + p.netPay);
            final totalDeductions = summaries.fold<double>(0, (sum, p) => sum + p.deductions);

            return RefreshIndicator(
              onRefresh: payrollController.loadAllForHr,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(onPressed: () => _changeMonth(-1), icon: const Icon(Icons.chevron_left_rounded)),
                    Text(_monthLabel.format(payrollController.hrSelectedMonth), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    IconButton(onPressed: () => _changeMonth(1), icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: 'Generate Payroll for This Month',
                  icon: Icons.calculate_outlined,
                  isLoading: payrollController.generating,
                  onPressed: _confirmGenerate,
                ),
                const SizedBox(height: 20),

                if (payrollController.loading && summaries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (summaries.isEmpty)
                  const EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'Not generated yet',
                    subtitle: 'Tap "Generate Payroll" above to compute this month\'s summaries.',
                  )
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Total Net Pay',
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
              ],
              ),
            );
          },
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
