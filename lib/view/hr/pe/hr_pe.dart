import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_extension.dart';
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
  late TeamMemberSummary _selectedEmployee;
  late KpiTemplate _selectedTemplate;
  final _year = '2026';
  bool _isSubmitting = false;

  late List<Map<String, dynamic>> _kpis;

  final _commentsController = TextEditingController();

  String _categoryFor(String kpiName) {
    if (kpiName.contains('Leadership')) return 'Leadership';
    if (kpiName.contains('Team') || kpiName.contains('Communication') || kpiName.contains('Customer')) return 'Behavioural';
    if (kpiName.contains('Attendance')) return 'Operational';
    return 'Technical';
  }

  KpiTemplate _templateFor(String department) {
    final match = DummyData.kpiTemplates.where((t) => t.department == department);
    if (match.isNotEmpty) return match.first;
    return DummyData.kpiTemplates.firstWhere((t) => t.department == 'All Departments', orElse: () => DummyData.kpiTemplates.last);
  }

  void _loadTemplate(KpiTemplate template) {
    _selectedTemplate = template;
    _kpis = template.items
        .map((i) => {
              'name': i.name,
              'weightage': i.weightage,
              'score': 70.0,
              'category': _categoryFor(i.name),
            })
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _selectedEmployee = DummyData.teamOverview[0];
    _loadTemplate(_templateFor(_selectedEmployee.department));
    _commentsController.text = 'Strong technical delivery this cycle. Continue developing stakeholder communication skills.';
  }

  void _pickEmployee() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<TeamMemberSummary>(
        title: 'Select Employee',
        items: DummyData.teamOverview,
        labelBuilder: (e) => e.name,
        subtitleBuilder: (e) => '${e.jobTitle} · ${e.department}',
        onSelected: (e) => setState(() {
          _selectedEmployee = e;
          _loadTemplate(_templateFor(e.department));
        }),
      ),
    );
  }

  void _pickTemplate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<KpiTemplate>(
        title: 'Select KPI Template',
        items: DummyData.kpiTemplates,
        labelBuilder: (t) => t.name,
        subtitleBuilder: (t) => '${t.department} · ${t.items.length} KPIs',
        onSelected: (t) => setState(() => _loadTemplate(t)),
      ),
    );
  }

  double get _weightedTotal {
    double total = 0;
    for (final k in _kpis) {
      total += (k['score'] as double) * (k['weightage'] as double) / 100;
    }
    return total;
  }

  Color _scoreColor(double score, AppColorsExtension c) {
    if (score >= 80) return c.primary;
    if (score >= 60) return c.amber;
    return c.riskHigh;
  }

  void _submit() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'PE Submitted',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Performance evaluation for $_year has been saved. Training recommendations have been updated.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Performance Evaluation')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Employee + Year selector
            AppCard(
              onTap: _pickEmployee,
              child: Row(
                children: [
                  InitialsAvatar(
                    initials: _selectedEmployee.avatarInitials,
                    size: 44,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedEmployee.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          _selectedEmployee.department,
                          style: TextStyle(
                            fontSize: 12,
                            color: c.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _year,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.unfold_more_rounded, size: 18, color: c.textMuted),
                ],
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              onTap: _pickTemplate,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined, size: 16, color: c.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('KPI Template: ${_selectedTemplate.name}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    ),
                    Text('Change', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Weighted total preview
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: c.kpiGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [c.shadowTinted()],
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weighted Total Score',
                        style: TextStyle(color: Colors.white70, fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _weightedTotal.toStringAsFixed(1),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          height: 1,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                      const Text(
                        '/ 100',
                        style: TextStyle(color: Colors.white60, fontSize: 13),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 80,
                    height: 80,
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
              final color = _scoreColor(score, c);
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [c.shadowNeutral],
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
                                Text(
                                  kpi['name'] as String,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${(kpi['weightage'] as double).toInt()}% weight  ·  ${kpi['category']}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: c.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              '${score.toInt()} / 100',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: color,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.amberBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: c.amber,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Training recommendation will be triggered for ${kpi['category']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: c.amber,
                                  fontWeight: FontWeight.w600,
                                ),
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
                hintText:
                    'Add overall comments, feedback, or development notes for this employee...',
              ),
            ),
            const SizedBox(height: 24),

            // PE history preview
            const SectionHeader(title: 'Previous PE Records'),
            ...DummyData.peHistory.map(
              (pe) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: c.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.calendar_month_rounded,
                          size: 16,
                          color: c.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Evaluation ${pe.year}',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        pe.weightedTotal.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: c.primary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '/ 100',
                        style: TextStyle(
                          fontSize: 11,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

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

class _PickerSheet<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelBuilder;
  final String Function(T) subtitleBuilder;
  final ValueChanged<T> onSelected;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(labelBuilder(item), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(subtitleBuilder(item), style: TextStyle(fontSize: 12, color: c.textMuted)),
                  onTap: () {
                    onSelected(item);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
