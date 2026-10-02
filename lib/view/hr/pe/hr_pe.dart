import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/employee_controller.dart';
import '../../../controller/pe_controller.dart';
import '../../../connection/policy_service.dart';

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
  bool _savingDraft = false;
  bool _initialized = false;

  List<Map<String, dynamic>> _kpis = [];

  // Matches policy_settings' defaults until the real values load — kept in
  // sync with the actual thresholds Policy Config lets HR tune, so this
  // badge accurately reflects whether submitting will really trigger a
  // training recommendation (see PeController._triggerTrainingRecommendations).
  Map<String, double> _thresholds = {
    'Technical': 65,
    'Behavioural': 60,
    'Leadership': 60,
  };

  final _commentsController = TextEditingController();

  /// Auto-picks only when there's exactly one sensible match — multiple
  /// templates for the same department (e.g. an IC vs a Lead template) are
  /// deliberately allowed now, so if it's ambiguous HR must pick explicitly
  /// via the template picker rather than the app silently guessing.
  KpiTemplate? _templateFor(String department) {
    final deptMatches = peController.templates
        .where((t) => t.department == department)
        .toList();
    if (deptMatches.length == 1) return deptMatches.first;
    if (deptMatches.isEmpty) {
      final allDept = peController.templates
          .where((t) => t.department == 'All Departments')
          .toList();
      if (allDept.length == 1) return allDept.first;
    }
    return null;
  }

  void _loadTemplateDefaults(KpiTemplate? template) {
    _selectedTemplate = template;
    _kpis = template == null
        ? []
        : template.items
              .map(
                (i) => {
                  'name': i.name,
                  'weightage': i.weightage,
                  'score': 70.0,
                  'category': i.category,
                },
              )
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
    try {
      final policy = await PolicyService.fetch();
      _thresholds = {
        'Technical': (policy['technical_threshold'] as num).toDouble(),
        'Behavioural': (policy['behavioural_threshold'] as num).toDouble(),
        'Leadership': (policy['leadership_threshold'] as num).toDouble(),
      };
    } catch (_) {
      // Keep the defaults set above — badge stays reasonably accurate.
    }
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
      // Matched purely by id — the saved KPI scores below came from
      // whatever template was picked at the time, even if that template's
      // department no longer matches this employee's (bad data entry).
      // Hiding the KPI breakdown in that case would look like the saved
      // evaluation vanished, so instead _templateMismatch below surfaces
      // it as a visible warning HR can act on.
      final matchedTemplate = peController.templates.where(
        (t) => t.dbId == existing.templateId,
      );
      setState(() {
        _selectedTemplate = matchedTemplate.isNotEmpty
            ? matchedTemplate.first
            : _templateFor(emp.department);
        _kpis = existing.kpis
            .map(
              (k) => {
                'name': k.name,
                'weightage': k.weightage,
                'score': k.score,
                'category': k.category,
              },
            )
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

  // Only templates compatible with the selected employee's department
  // (their own department's template, or an "All Departments" one) —
  // otherwise HR could apply e.g. a Sales-authored template to a Design
  // employee, which never made sense as a choice.
  List<KpiTemplate> get _compatibleTemplates {
    final dept = _selectedEmployee?.department;
    return peController.templates
        .where((t) => t.department == dept || t.department == 'All Departments')
        .toList();
  }

  // True when the currently-shown template belongs to neither the
  // employee's department nor "All Departments" — a saved evaluation
  // pointing at a mismatched template (bad data entry) rather than a
  // fresh, correctly-filtered pick.
  bool get _templateMismatch {
    final t = _selectedTemplate;
    final dept = _selectedEmployee?.department;
    if (t == null || dept == null) return false;
    return t.department != dept && t.department != 'All Departments';
  }

  void _pickTemplate() {
    final compatible = _compatibleTemplates;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<KpiTemplate>(
        title: 'Select KPI Template',
        items: compatible,
        labelBuilder: (t) => t.name,
        subtitleBuilder: (t) => '${t.department} · ${t.items.length} KPIs',
        onSelected: (t) => setState(() => _loadTemplateDefaults(t)),
        onEdit: (t) {
          Navigator.of(context).pop();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CreateTemplateSheet(existing: t),
          );
        },
        onDelete: (t) async {
          final success = await peController.deleteTemplate(t);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? '✓ Template deleted'
                    : peController.errorMessage ?? 'Could not delete template',
              ),
            ),
          );
        },
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

  // Colour is driven by the same category threshold that decides whether
  // submitting will trigger a training recommendation (see the badge
  // below and PeController._triggerTrainingRecommendations) — a fixed
  // score-quality band (e.g. "60+ is amber") would tell HR something
  // different from what the score is actually about to do, which is the
  // exact ambiguity that made it hard to tell whether an employee had
  // genuinely hit their KPI target just by eyeballing the slider.
  Color _scoreColor(double score, double threshold, AppColorsExtension c) {
    if (score >= threshold) return c.primary;
    if (score >= threshold - 10) return c.amber;
    return c.riskHigh;
  }

  Future<void> _submit() async {
    final employee = _selectedEmployee;
    if (employee == null) return;
    setState(() => _isSubmitting = true);

    final kpiItems = _kpis
        .map(
          (k) => KpiItem(
            name: k['name'] as String,
            weightage: k['weightage'] as double,
            score: k['score'] as double,
            category: k['category'] as String,
          ),
        )
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
        SnackBar(
          content: Text(
            peController.errorMessage ?? 'Could not submit evaluation',
          ),
          backgroundColor: context.colors.riskHigh,
        ),
      );
      return;
    }

    final c = context.colors;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  Future<void> _saveDraft() async {
    final employee = _selectedEmployee;
    if (employee == null) return;
    setState(() => _savingDraft = true);

    final kpiItems = _kpis
        .map(
          (k) => KpiItem(
            name: k['name'] as String,
            weightage: k['weightage'] as double,
            score: k['score'] as double,
            category: k['category'] as String,
          ),
        )
        .toList();
    final success = await peController.saveDraft(
      userUuid: employee.uuid,
      templateId: _selectedTemplate?.dbId,
      kpis: kpiItems,
      comments: _commentsController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _savingDraft = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Draft saved for ${employee.name} — resume anytime before submitting'
              : peController.errorMessage ?? 'Could not save draft',
        ),
        backgroundColor: success ? null : context.colors.riskHigh,
      ),
    );
  }

  Future<void> _discardDraft() async {
    final draft = peController.selectedCurrent;
    final employee = _selectedEmployee;
    if (draft == null || employee == null || !draft.isDraft) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Discard This Draft?'),
        content: Text(
          'The in-progress $_year evaluation for ${employee.name} will be permanently deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Discard',
              style: TextStyle(color: context.colors.riskHigh),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await peController.discardDraft(draft);
    if (!mounted) return;
    if (success) {
      setState(() {
        _loadTemplateDefaults(_templateFor(employee.department));
        _commentsController.text = '';
      });
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '✓ Draft discarded'
              : peController.errorMessage ?? 'Could not discard draft',
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

  void _manageAllTemplates() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet<KpiTemplate>(
        title: 'All KPI Templates',
        items: peController.templates,
        labelBuilder: (t) => t.name,
        subtitleBuilder: (t) => '${t.department} · ${t.items.length} KPIs',
        onSelected: (t) => setState(() => _loadTemplateDefaults(t)),
        onEdit: (t) {
          Navigator.of(context).pop();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => _CreateTemplateSheet(existing: t),
          );
        },
        onDelete: (t) async {
          final success = await peController.deleteTemplate(t);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? '✓ Template deleted'
                    : peController.errorMessage ?? 'Could not delete template',
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Evaluation'),
        actions: [
          IconButton(
            tooltip: 'Manage All Templates',
            onPressed: _manageAllTemplates,
            icon: Icon(Icons.list_alt_rounded, color: c.textSecondary),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              tooltip: 'Create KPI Template',
              onPressed: _createTemplate,
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: c.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
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

            final history = peController.selectedHistory
                .where((h) => h.dbId != peController.selectedCurrent?.dbId)
                .toList();
            final isDraft = peController.selectedCurrent?.isDraft ?? false;
            // A submitted (non-draft) evaluation is final — every control
            // below goes read-only, matching the server-side guard in
            // migration 0035 (prevent_completed_pe_edit).
            final isCompleted =
                peController.selectedCurrent != null && !isDraft;

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
                      if (isCompleted) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.primaryLight,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 13,
                                color: c.primaryDark,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'PE Completed',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (isDraft) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: c.amberBg,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_note_rounded,
                                size: 13,
                                color: c.amber,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Draft',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: c.amber,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
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
                      Icon(
                        Icons.unfold_more_rounded,
                        size: 18,
                        color: c.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Builder(
                  builder: (context) {
                    final noneAvailable = _compatibleTemplates.isEmpty;
                    final mismatch = _templateMismatch;
                    return InkWell(
                      onTap: isCompleted
                          ? null
                          : (noneAvailable ? _createTemplate : _pickTemplate),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: mismatch ? c.riskHighBg : c.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              mismatch
                                  ? Icons.warning_amber_rounded
                                  : Icons.fact_check_outlined,
                              size: 16,
                              color: mismatch ? c.riskHigh : c.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'KPI Template: ${_selectedTemplate?.name ?? '—'}',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                ),
                              ),
                            ),
                            if (!isCompleted)
                              Text(
                                mismatch
                                    ? 'Fix'
                                    : (noneAvailable ? 'Create' : 'Change'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: mismatch ? c.riskHigh : c.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (_templateMismatch) ...[
                  const SizedBox(height: 6),
                  Text(
                    'This evaluation is linked to a ${_selectedTemplate!.department} template, not ${_selectedEmployee!.department}. Tap "Fix" to reassign the correct one.',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.riskHigh,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                if (_selectedTemplate == null) ...[
                  EmptyState(
                    icon: Icons.fact_check_outlined,
                    title: 'No KPI Template Created Yet',
                    subtitle:
                        '${_selectedEmployee!.department} has no KPI Template yet. Create one or pick from another department.',
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: _compatibleTemplates.isEmpty
                        ? 'Create KPI Template'
                        : 'Select KPI Template',
                    icon: _compatibleTemplates.isEmpty
                        ? Icons.add_rounded
                        : Icons.fact_check_rounded,
                    onPressed: _compatibleTemplates.isEmpty
                        ? _createTemplate
                        : _pickTemplate,
                  ),
                ] else ...[
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
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12.5,
                              ),
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
                              style: TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
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
                            valueColor: const AlwaysStoppedAnimation(
                              Colors.white,
                            ),
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
                      child: Text(
                        'This template has no KPI items to score.',
                        style: TextStyle(fontSize: 12.5, color: c.textMuted),
                      ),
                    ),
                  ..._kpis.asMap().entries.map((e) {
                    final i = e.key;
                    final kpi = e.value;
                    final score = kpi['score'] as double;
                    final threshold = _thresholds[kpi['category']] ?? 65;
                    final hitTarget = score >= threshold;
                    final color = _scoreColor(score, threshold, c);
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(
                                          100,
                                        ),
                                      ),
                                      child: Text(
                                        '${score.toInt()} / 100',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: color,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          hitTarget
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                          size: 12,
                                          color: color,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          hitTarget ? 'KPI Hit' : 'KPI Missed',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          SliderTheme(
                            data: SliderThemeData(
                              activeTrackColor: color,
                              thumbColor: color,
                              disabledActiveTrackColor: color,
                              disabledThumbColor: color,
                              disabledInactiveTrackColor: color.withValues(
                                alpha: 0.15,
                              ),
                              inactiveTrackColor: color.withValues(alpha: 0.15),
                              overlayColor: color.withValues(alpha: 0.1),
                              trackHeight: 4,
                            ),
                            child: Slider(
                              value: score,
                              min: 0,
                              max: 100,
                              divisions: 100,
                              onChanged: isCompleted
                                  ? null
                                  : (v) =>
                                        setState(() => _kpis[i]['score'] = v),
                            ),
                          ),
                          // Matches PeController._triggerTrainingRecommendations'
                          // real threshold check — this badge only shows when
                          // submitting will actually enrol the employee in a
                          // matching training programme (rule-based, per this
                          // project's scope), not just a cosmetic hint.
                          if (!isCompleted &&
                              score < (_thresholds[kpi['category']] ?? 65))
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_rounded,
                                      size: 13,
                                      color: c.amber,
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        'Training recommendation will be triggered for ${kpi['category']}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: c.amber,
                                          fontWeight: FontWeight.w600,
                                        ),
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
                    readOnly: isCompleted,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText:
                          'Add overall comments, feedback, or development notes for this employee...',
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // PE history preview
                const SectionHeader(title: 'Previous PE Records'),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No previous evaluations for this employee.',
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
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
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
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

                if (isCompleted) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: c.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 16,
                          color: c.primaryDark,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'This $_year evaluation has been submitted and is final — it can no longer be changed.',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.primaryDark,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_selectedTemplate != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting || _savingDraft
                              ? null
                              : _saveDraft,
                          icon: _savingDraft
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.textSecondary,
                                  ),
                                )
                              : const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Save as Draft'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Submit',
                          icon: Icons.assessment_rounded,
                          onPressed: _isSubmitting || _savingDraft
                              ? null
                              : _submit,
                          isLoading: _isSubmitting,
                        ),
                      ),
                    ],
                  ),
                  if (isDraft) ...[
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton.icon(
                        onPressed: _discardDraft,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: c.riskHigh,
                        ),
                        label: Text(
                          'Discard Draft',
                          style: TextStyle(color: c.riskHigh),
                        ),
                      ),
                    ),
                  ],
                ],
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
  final ValueChanged<T>? onEdit;
  final ValueChanged<T>? onDelete;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.onSelected,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
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
                  title: Text(
                    labelBuilder(item),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    subtitleBuilder(item),
                    style: TextStyle(fontSize: 12, color: c.textMuted),
                  ),
                  trailing: onEdit == null && onDelete == null
                      ? null
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (onEdit != null)
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 20,
                                  color: c.textSecondary,
                                ),
                                onPressed: () => onEdit!(item),
                              ),
                            if (onDelete != null)
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: c.riskHigh,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      title: const Text(
                                        'Delete this template?',
                                      ),
                                      content: Text(
                                        '"${labelBuilder(item)}" will be permanently removed.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Navigator.of(
                                            dialogContext,
                                          ).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: c.riskHigh,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmed != true) return;
                                  if (!context.mounted) return;
                                  Navigator.of(context).pop();
                                  onDelete!(item);
                                },
                              ),
                          ],
                        ),
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
  final KpiTemplate? existing;
  const _CreateTemplateSheet({this.existing});

  @override
  State<_CreateTemplateSheet> createState() => _CreateTemplateSheetState();
}

class _KpiItemDraft {
  final nameCtrl = TextEditingController();
  final weightCtrl = TextEditingController();
  String category = 'Technical';

  void dispose() {
    nameCtrl.dispose();
    weightCtrl.dispose();
  }
}

class _CreateTemplateSheetState extends State<_CreateTemplateSheet> {
  static const _departments = [
    'All Departments',
    'Engineering',
    'Sales',
    'Operations',
    'Marketing',
    'Design',
    'Human Resources',
    'Finance',
  ];
  static const _categories = ['Technical', 'Behavioural', 'Leadership'];

  late final _name = TextEditingController(text: widget.existing?.name);
  late String _department = widget.existing?.department ?? 'All Departments';
  final List<_KpiItemDraft> _items = [];
  bool _saving = false;
  String? _errorText;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existingItems = widget.existing?.items ?? const [];
    if (existingItems.isEmpty) {
      _addItem();
      _addItem();
    } else {
      for (final i in existingItems) {
        final draft = _KpiItemDraft()
          ..nameCtrl.text = i.name
          ..weightCtrl.text = i.weightage % 1 == 0
              ? i.weightage.toInt().toString()
              : i.weightage.toString()
          ..category = i.category;
        _items.add(draft);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() => _items.add(_KpiItemDraft()));
  }

  void _removeItem(int i) {
    setState(() {
      _items[i].dispose();
      _items.removeAt(i);
    });
  }

  double get _totalWeightage => _items.fold(
    0.0,
    (sum, item) => sum + (double.tryParse(item.weightCtrl.text) ?? 0),
  );

  Future<void> _save() async {
    final name = _name.text.trim();
    final total = _totalWeightage;
    if (name.isEmpty) {
      setState(() => _errorText = 'Enter a template name.');
      return;
    }
    if (_items.any((i) => i.nameCtrl.text.trim().isEmpty)) {
      setState(() => _errorText = 'Every KPI needs a name.');
      return;
    }
    if ((total - 100).abs() > 0.01) {
      setState(
        () => _errorText =
            'Weightages must total 100% (currently ${total.toStringAsFixed(0)}%).',
      );
      return;
    }

    setState(() {
      _errorText = null;
      _saving = true;
    });
    final items = _items
        .map(
          (i) => KpiTemplateItem(
            name: i.nameCtrl.text.trim(),
            weightage: double.tryParse(i.weightCtrl.text) ?? 0,
            category: i.category,
          ),
        )
        .toList();
    final success = _isEditing
        ? await peController.updateTemplate(
            existing: widget.existing!,
            name: name,
            departmentName: _department,
            items: items,
          )
        : await peController.createTemplate(
            name: name,
            departmentName: _department,
            items: items,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      setState(
        () => _errorText =
            peController.errorMessage ?? 'Could not save template.',
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? '✓ KPI template updated successfully'
              : '✓ KPI template created successfully',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = _totalWeightage;
    final totalOk = (total - 100).abs() < 0.01;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? 'Edit KPI Template' : 'Create KPI Template',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),

            const Text(
              'Template Name',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                hintText: 'e.g. Engineering Standard Template',
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Department',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
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
                  labelStyle: TextStyle(
                    color: sel ? c.primaryDark : c.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(color: sel ? c.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'KPI Items',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${total.toStringAsFixed(0)}% / 100%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: totalOk ? c.primary : c.riskHigh,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: item.nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'KPI name',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 1,
                          child: TextField(
                            controller: item.weightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: '%',
                              isDense: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        IconButton(
                          onPressed: _items.length > 1
                              ? () => _removeItem(i)
                              : null,
                          icon: Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 20,
                            color: c.riskHigh,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: _categories.map((cat) {
                        final sel = item.category == cat;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: sel,
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) =>
                              setState(() => item.category = cat),
                          selectedColor: c.primaryLight,
                          labelStyle: TextStyle(
                            color: sel ? c.primaryDark : c.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                          side: BorderSide(
                            color: sel ? c.primary : Colors.transparent,
                          ),
                        );
                      }).toList(),
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
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: c.riskHighBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _errorText!,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.riskHigh,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),

            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Create Template',
              icon: _isEditing ? Icons.save_rounded : Icons.fact_check_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
