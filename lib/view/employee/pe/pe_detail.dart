import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class PeDetailScreen extends StatelessWidget {
  const PeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pe = DummyData.currentPE;
    final total = pe.weightedTotal;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Performance Evaluation'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text('Evaluation Year ${pe.year}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 140,
                          height: 140,
                          child: CircularProgressIndicator(
                            value: total / 100,
                            strokeWidth: 12,
                            backgroundColor: AppColors.surfaceMuted,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(total.toStringAsFixed(1), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                            const Text('/ 100', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                    child: const Text('Weighted Total Score', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'KPI Breakdown'),
            ...pe.kpis.map((k) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _KpiBar(kpi: k),
            )),
            const SizedBox(height: 12),
            const SectionHeader(title: 'HR Comments'),
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pe.comments,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const SectionHeader(title: 'PE History'),
            ...DummyData.peHistory.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.calendar_month_rounded, size: 16, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Evaluation ${e.year}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Text(
                      e.weightedTotal.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
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

class _KpiBar extends StatelessWidget {
  final KpiItem kpi;
  const _KpiBar({required this.kpi});

  Color get _color {
    if (kpi.score >= 80) return AppColors.primary;
    if (kpi.score >= 60) return AppColors.amber;
    return AppColors.riskHigh;
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kpi.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              Text('${kpi.weightage.toStringAsFixed(0)}% weight', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: kpi.score / 100,
              minHeight: 8,
              backgroundColor: AppColors.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(_color),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${kpi.score.toStringAsFixed(0)} / 100',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _color),
            ),
          ),
        ],
      ),
    );
  }
}