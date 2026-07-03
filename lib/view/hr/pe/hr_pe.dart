import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrPeScreen extends StatefulWidget {
  const HrPeScreen({super.key});

  @override
  State<HrPeScreen> createState() => _HrPeScreenState();
}

class _HrPeScreenState extends State<HrPeScreen> {
  final _selectedEmployee = DummyData.teamOverview[0];
  final _year = '2026';
  bool _isSubmitting = false;

  // KPI scores — editable sliders
  final List<Map<String, dynamic>> _kpis = [
    {'name': 'Attendance Rate', 'weightage': 20.0, 'score': 92.0, 'category': 'Operational'},
    {'name': 'Task Delivery Quality', 'weightage': 30.0, 'score': 88.0, 'category': 'Technical'},
    {'name': 'Project Output', 'weightage': 25.0, 'score': 81.0, 'category': 'Technical'},
    {'name': 'Teamwork & Communication', 'weightage': 15.0, 'score': 74.0, 'category': 'Behavioural'},
    {'name': 'Leadership Initiative', 'weightage': 10.0, 'score': 58.0, 'category': 'Leadership'},
  ];

  final _commentsController = TextEditingController(
    text: 'Strong technical delivery this cycle. Continue developing stakeholder communication skills.',
  );

  double get _weightedTotal {
    double total = 0;
    for (final k in _kpis) {
      total += (k['score'] as double) * (k['weightage'] as double) / 100;
    }
    return total;
  }

  Color _scoreColor(double score) {
    if (score >= 80) return AppColors.primary;
    if (score >= 60) return AppColors.amber;
    return AppColors.riskHigh;
  }

  void _submit() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 34),
              ),
              const SizedBox(height: 16),
              const Text('PE Submitted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Performance evaluation for $_year has been saved. Training recommendations have been updated.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Done', onPressed: () { Navigator.of(context).pop(); Navigator.of(context).pop(); }),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Evaluation')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [

            // Employee + Year selector
            AppCard(
              child: Row(
                children: [
                  InitialsAvatar(initials: _selectedEmployee.avatarInitials, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_selectedEmployee.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(_selectedEmployee.department, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(100)),
                    child: Text(_year, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primaryDark)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Weighted total preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.kpiGradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Weighted Total Score', style: TextStyle(color: Colors.white70, fontSize: 12.5)),
                      const SizedBox(height: 4),
                      Text(
                        _weightedTotal.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900, height: 1),
                      ),
                      const Text('/ 100', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 80, height: 80,
                    child: CircularProgressIndicator(
                      value: _weightedTotal / 100,
                      strokeWidth: 8,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'KPI Scoring'),
            ..._kpis.asMap().entries.map((e) {
              final i = e.key;
              final kpi = e.value;
              final score = kpi['score'] as double;
              final color = _scoreColor(score);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kpi['name'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 2),
                                Text('${(kpi['weightage'] as double).toInt()}% weight  ·  ${kpi['category']}',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                            child: Text('${score.toInt()} / 100', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: color)),
                          ),
                        ],
                      ),
                    ),
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: color,
                        thumbColor: color,
                        inactiveTrackColor: color.withOpacity(0.15),
                        overlayColor: color.withOpacity(0.1),
                        trackHeight: 4,
                      ),
                      child: Slider(
                        value: score,
                        min: 0,
                        max: 100,
                        divisions: 100,
                        onChanged: (v) => setState(() => _kpis[i]['score'] = v),
                      ),
                    ),
                    // Auto trigger badge
                    if (score < 65)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 13, color: AppColors.amber),
                              const SizedBox(width: 6),
                              Text(
                                'Training recommendation will be triggered for ${kpi['category']}',
                                style: const TextStyle(fontSize: 11, color: AppColors.amber, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 8),
            const SectionHeader(title: 'HR Comments'),
            TextField(
              controller: _commentsController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add overall comments, feedback, or development notes for this employee...',
              ),
            ),
            const SizedBox(height: 24),

            // PE history preview
            const SectionHeader(title: 'Previous PE Records'),
            ...DummyData.peHistory.map((pe) => Padding(
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
                    Expanded(child: Text('Evaluation ${pe.year}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700))),
                    Text(pe.weightedTotal.toStringAsFixed(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    const SizedBox(width: 4),
                    const Text('/ 100', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                  ],
                ),
              ),
            )),

            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Submit Evaluation',
              icon: Icons.assessment_rounded,
              onPressed: _submit,
              isLoading: _isSubmitting,
            ),
          ],
        ),
      ),
    );
  }
}