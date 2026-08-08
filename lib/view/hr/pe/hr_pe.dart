import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/employee_controller.dart';
import '../../../controller/pe_controller.dart';

class HrPeScreen extends StatefulWidget {
  const HrPeScreen({super.key});

  @override
  State<HrPeScreen> createState() => _HrPeScreenState();
}

class _HrPeScreenState extends State<HrPeScreen> {
  TeamMemberSummary? _selectedEmployee;
  KpiTemplate? _selectedTemplate;
  final _year = DateTime.now().year.toString();
  bool _isSubmitting = false;
  bool _initialized = false;

  List<Map<String, dynamic>> _kpis = [];

  final _commentsController = TextEditingController();

  String _categoryFor(String kpiName) {
    if (kpiName.contains('Leadership')) return 'Leadership';
    if (kpiName.contains('Team') || kpiName.contains('Communication') || kpiName.contains('Customer')) return 'Behavioural';
    if (kpiName.contains('Attendance')) return 'Operational';
    return 'Technical';
  }

  KpiTemplate _templateFor(String department) {
    final templates = peController.templates;
    final match = templates.where((t) => t.department == department);
    if (match.isNotEmpty) return match.first;
    final allDept = templates.where((t) => t.department == 'All Departments');
    if (allDept.isNotEmpty) return allDept.first;
    return templates.isNotEmpty ? templates.last : const KpiTemplate(name: 'No Template Available', department: 'All Departments', items: []);
  }

  void _loadTemplateDefaults(KpiTemplate template) {
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
    _bootstrap();
  }

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    if (employeeController.employees.isEmpty) {
      await employeeController.loadEmployees();
    }
    await peController.loadTemplates();
    if (!mounted) return;
    if (employeeController.employees.isNotEmpty) {
      await _selectEmployee(employeeController.employees.first);
    }
    if (!mounted) return;
    setState(() => _initialized = true);
  }

  /// Loads the employee's real evaluation for this year, if one already
  /// exists, and prefills the form from it (so re-opening an already-
  /// scored employee shows what was actually saved, not fresh defaults).
  /// Otherwise starts from the department's suggested template at
  /// default scores, same as before this was wired to real data.
  Future<void> _selectEmployee(TeamMemberSummary emp) async {
    setState(() => _selectedEmployee = emp);
    await peController.loadForEmployee(emp.uuid);
    if (!mounted) return;

    final existing = peController.selectedCurrent;
    if (existing != null && existing.kpis.isNotEmpty) {
      final matchedTemplate = peController.templates.where((t) => t.dbId == existing.templateId);
      setState(() {
        _selectedTemplate = matchedTemplate.isNotEmpty ? matchedTemplate.first : _templateFor(emp.department);
        _kpis = existing.kpis
            .map((k) => {
                  'name': k.name,
                  'weightage': k.weightage,
                  'score': k.score,
                  'category': _categoryFor(k.name),
                })
            .toList();
        _commentsController.text = existing.comments;
      });
    } else {
      setState(() {
        _loadTemplateDefaults(_templateFor(emp.department));
        _commentsController.text = '';
      });
    }
  }

  void _pickEmployee() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<TeamMemberSummary>(
        title: 'Select Employee',
        items: employeeController.employees,
        labelBuilder: (e) => e.name,
        subtitleBuilder: (e) => '${e.jobTitle} · ${e.department}',
        onSelected: (e) => _selectEmployee(e),
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
        items: peController.templates,
        labelBuilder: (t) => t.name,
        subtitleBuilder: (t) => '${t.department} · ${t.items.length} KPIs',
        onSelected: (t) => setState(() => _loadTemplateDefaults(t)),
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

  Future<void> _submit() async {
    final employee = _selectedEmployee;
    if (employee == null) return;
    setState(() => _isSubmitting = true);

    final kpiItems = _kpis
        .map((k) => KpiItem(name: k['name'] as String, weightage: k['weightage'] as double, score: k['score'] as double))
        .toList();
    final success = await peController.submit(
      userUuid: employee.uuid,
      templateId: _selectedTemplate?.dbId,
      kpis: kpiItems,
      comments: _commentsController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(peController.errorMessage ?? 'Could not submit evaluation'), backgroundColor: context.colors.riskHigh),
      );
      return;
    }

    final c = context.colors;
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
              decoration: BoxDecoration(
                color: c.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: c.primary,
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
              'Performance evaluation for $_year has been saved for ${employee.name}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: c.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  void _createTemplate() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTemplateSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Evaluation'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Create KPI Template',
              onPressed: _createTemplate,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([employeeController, peController]),
          builder: (context, _) {
            if (!_initialized) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_selectedEmployee == null) {
              return const EmptyState(
                icon: Icons.groups_outlined,
                title: 'No employees found',
                subtitle: 'Add an employee first from Employee Management.',
              );
            }

            final history = peController.selectedHistory.where((h) => h.dbId != peController.selectedCurrent?.dbId).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                // Employee + Year selector
                AppCard(
                  onTap: _pickEmployee,
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: _selectedEmployee!.avatarInitials,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedEmployee!.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _selectedEmployee!.department,
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
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c.primaryDark,
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
                          child: Text('KPI Template: ${_selectedTemplate?.name ?? '—'}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
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
                if (_kpis.isEmpty)
                  AppCard(
                    child: Text('This template has no KPI items to score.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  ),
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
                                  color: color.withValues(alpha: 0.12),
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
                            inactiveTrackColor: color.withValues(alpha: 0.15),
                            overlayColor: color.withValues(alpha: 0.1),
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
                        // Auto trigger badge - informational only for now;
                        // Training isn't wired to real data yet, so this
                        // doesn't actually create a training_enrollments
                        // row (same as before this screen was wired).
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
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('No previous evaluations for this employee.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  )
                else
                  ...history.map(
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
            );
          },
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

class _CreateTemplateSheet extends StatefulWidget {
  const _CreateTemplateSheet();

  @override
  State<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _CreateTemplateSheetState extends State<_CreateTemplateSheet> {
  static const _departments = ['All Departments', 'Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];

  final _name = TextEditingController();
  String _department = 'All Departments';
  final List<(TextEditingController, TextEditingController)> _items = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _addItem();
    _addItem();
  }

  @override
  void dispose() {
    _name.dispose();
    for (final (n, w) in _items) {
      n.dispose();
      w.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add((TextEditingController(), TextEditingController())));
  }

  void _removeItem(int i) {
    setState(() {
      _items[i].$1.dispose();
      _items[i].$2.dispose();
      _items.removeAt(i);
    });
  }

  double get _totalWeightage => _items.fold(0.0, (sum, item) => sum + (double.tryParse(item.$2.text) ?? 0));

  Future<void> _save() async {
    final name = _name.text.trim();
    final total = _totalWeightage;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a template name')));
      return;
    }
    if (_items.any((i) => i.$1.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Every KPI needs a name')));
      return;
    }
    if ((total - 100).abs() > 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Weightages must total 100% (currently ${total.toStringAsFixed(0)}%)')));
      return;
    }

    setState(() => _saving = true);
    final success = await peController.createTemplate(
      name: name,
      departmentName: _department,
      items: _items.map((i) => KpiTemplateItem(name: i.$1.text.trim(), weightage: double.tryParse(i.$2.text) ?? 0)).toList(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(peController.errorMessage ?? 'Could not create template')),
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✓ KPI template created successfully')));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = _totalWeightage;
    final totalOk = (total - 100).abs() < 0.01;
    return Container(
      decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(100))),
            ),
            const SizedBox(height: 20),
            const Text('Create KPI Template', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            const Text('Template Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Engineering Standard Template')),
            const SizedBox(height: 14),

            const Text('Department', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _departments.map((d) {
                final sel = _department == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: sel,
                  onSelected: (_) => setState(() => _department = d),
                  selectedColor: c.primaryLight,
                  labelStyle: TextStyle(color: sel ? c.primaryDark : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  side: BorderSide(color: sel ? c.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('KPI Items', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(
                  '${total.toStringAsFixed(0)}% / 100%',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: totalOk ? c.primary : c.riskHigh),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_items.length, (i) {
              final (nameCtrl, weightCtrl) = _items[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(hintText: 'KPI name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(hintText: '%', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      onPressed: _items.length > 1 ? () => _removeItem(i) : null,
                      icon: Icon(Icons.remove_circle_outline_rounded, size: 20, color: c.riskHigh),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add KPI'),
            ),
            const SizedBox(height: 12),

            PrimaryButton(
              label: 'Create Template',
              icon: Icons.fact_check_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
