import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/pe_controller.dart';
import '../../../connection/policy_service.dart';

class PeDetailScreen extends StatefulWidget {
  const PeDetailScreen({super.key});

  @override
  State<PeDetailScreen> createState() => _PeDetailScreenState();
}

class _PeDetailScreenState extends State<PeDetailScreen> {
  // Matches policy_settings' defaults until the real values load — kept in
  // sync with the same thresholds hr_pe.dart's KPI Hit/Missed badge uses,
  // so an employee sees the identical verdict HR saw while scoring them.
  Map<String, double> _thresholds = {'Technical': 65, 'Behavioural': 60, 'Leadership': 60};

  @override
  void initState() {
    super.initState();
    peController.loadMy();
    _loadThresholds();
  }

  Future<void> _loadThresholds() async {
    try {
      final policy = await PolicyService.fetch();
      if (!mounted) return;
      setState(() {
        _thresholds = {
          'Technical': (policy['technical_threshold'] as num).toDouble(),
          'Behavioural': (policy['behavioural_threshold'] as num).toDouble(),
          'Leadership': (policy['leadership_threshold'] as num).toDouble(),
        };
      });
    } catch (_) {
      // Keep the defaults set above — badge stays reasonably accurate.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Performance Evaluation'),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: peController,
          builder: (context, _) {
            if (peController.loading && peController.myHistory.isEmpty && peController.myCurrent == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final pe = peController.myCurrent;
            final history = peController.myHistory.where((h) => h.dbId != pe?.dbId).toList();

            return RefreshIndicator(
              onRefresh: peController.loadMy,
              child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                if (pe == null)
                  const EmptyState(
                    icon: Icons.assessment_outlined,
                    title: 'No evaluation yet',
                    subtitle: 'HR hasn\'t submitted your performance evaluation for this year yet.',
                  )
                else ...[
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
                                  value: pe.weightedTotal / 100,
                                  strokeWidth: 12,
                                  backgroundColor: c.surfaceMuted,
                                  valueColor: AlwaysStoppedAnimation(c.primary),
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(pe.weightedTotal.toStringAsFixed(1), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: c.textPrimary, fontFeatures: const [FontFeature.tabularFigures()])),
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
                        child: _KpiBar(kpi: k, threshold: _thresholds[k.category] ?? 65),
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
                            pe.comments.isEmpty ? 'No comments left for this evaluation.' : pe.comments,
                            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.5, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const SectionHeader(title: 'PE History'),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No previous evaluations.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  )
                else
                  ...history.map((e) => Padding(
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

class _KpiBar extends StatelessWidget {
  final KpiItem kpi;
  final double threshold;
  const _KpiBar({required this.kpi, required this.threshold});

  // Matches hr_pe.dart's _scoreColor — same threshold-relative colour bands
  // HR sees while scoring, so the badge below reads consistently for both.
  Color _getColor(AppColorsExtension c) {
    if (kpi.score >= threshold) return c.primary;
    if (kpi.score >= threshold - 10) return c.amber;
    return c.riskHigh;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = _getColor(c);
    final hitTarget = kpi.score >= threshold;
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
          if (KpiMetricSource.isAuto(kpi.metricSource)) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.sensors_rounded, size: 12, color: c.infoBlue),
                const SizedBox(width: 4),
                Text(
                  'Measured automatically from your ${KpiMetricSource.label(kpi.metricSource).toLowerCase()} records',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.infoBlue),
                ),
              ],
            ),
          ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(hitTarget ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 13, color: color),
                  const SizedBox(width: 4),
                  Text(hitTarget ? 'KPI Hit' : 'KPI Missed', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
                ],
              ),
              Text(
                '${kpi.score.toStringAsFixed(0)} / 100',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
