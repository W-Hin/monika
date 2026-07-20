import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class PeDetailScreen extends StatelessWidget {
  const PeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                color: c.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [c.shadowTinted()],
              ),
              child: Column(
                children: [
                  Text('Evaluation Year ${pe.year}', style: TextStyle(fontSize: 12.5, color: c.textMuted, fontWeight: FontWeight.w600)),
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
                            backgroundColor: c.surfaceMuted,
                            valueColor: AlwaysStoppedAnimation(c.primary),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(total.toStringAsFixed(1), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
                            Text('/ 100', style: TextStyle(fontSize: 12, color: c.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(100)),
                    child: Text('Weighted Total Score', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.primaryDark)),
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
                  Icon(Icons.format_quote_rounded, color: c.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pe.comments,
                      style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5, fontStyle: FontStyle.italic),
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
                      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.calendar_month_rounded, size: 16, color: c.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Evaluation ${e.year}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Text(
                      e.weightedTotal.toStringAsFixed(1),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.primary, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded, color: c.textMuted, size: 18),
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

  Color _getColor(AppColorsExtension c) {
    if (kpi.score >= 80) return c.primary;
    if (kpi.score >= 60) return c.amber;
    return c.riskHigh;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _getColor(c);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(kpi.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              ),
              Text('${kpi.weightage.toStringAsFixed(0)}% weight', style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: kpi.score / 100,
              minHeight: 8,
              backgroundColor: c.surfaceMuted,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${kpi.score.toStringAsFixed(0)} / 100',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
            ),
          ),
        ],
      ),
    );
  }
}