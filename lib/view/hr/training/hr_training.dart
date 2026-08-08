import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/training_controller.dart';

class HrTrainingScreen extends StatefulWidget {
  const HrTrainingScreen({super.key});

  @override
  State<HrTrainingScreen> createState() => _HrTrainingScreenState();
}

class _HrTrainingScreenState extends State<HrTrainingScreen> {
  int _tab = 0;
  final _tabs = ['All Programs', 'Mandatory', 'Completion'];

  final _departments = ['Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];

  @override
  void initState() {
    super.initState();
    trainingController.loadForHr();
  }

  Future<void> _assignDepartment(TrainingProgram program) async {
    final c = context.colors;
    await showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign "${program.title}" to Department', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
            ..._departments.map((d) => ListTile(
                  title: Text(d),
                  trailing: program.department == d ? Icon(Icons.check_rounded, color: c.primary) : null,
                  onTap: () async {
                    Navigator.of(context).pop();
                    final success = await trainingController.assignDepartment(program, d);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? '✓ Assigned to $d department' : trainingController.errorMessage ?? 'Could not assign department')),
                    );
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _editProgram(TrainingProgram program) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateProgramSheet(existing: program),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Training Management'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const _CreateProgramSheet(),
              ),
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
          listenable: trainingController,
          builder: (context, _) {
            final available = trainingController.hrPrograms;
            final mandatory = available.where((p) => p.isMandatory).toList();
            final inProgressCount = trainingController.completionRecords.where((r) => r.performanceScore == null && r.progress < 1.0).length;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Total Programs',
                              value: '${available.length}',
                              icon: Icons.school_rounded,
                              iconColor: c.primary,
                              iconBg: c.primaryLight,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              label: 'Mandatory',
                              value: '${mandatory.length}',
                              icon: Icons.assignment_rounded,
                              iconColor: c.riskHigh,
                              iconBg: c.riskHighBg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              label: 'In Progress',
                              value: '$inProgressCount',
                              icon: Icons.auto_awesome_rounded,
                              iconColor: c.amber,
                              iconBg: c.amberBg,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: c.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: List.generate(_tabs.length, (i) {
                            final sel = _tab == i;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() => _tab = i),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: sel ? c.surface : Colors.transparent,
                                    borderRadius: BorderRadius.circular(11),
                                    boxShadow: sel
                                        ? [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.06),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Text(
                                    _tabs[i],
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: sel ? c.textPrimary : c.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Expanded(
                  child: trainingController.loading && available.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : _tab == 2
                          ? _CompletionTab()
                          : (_tab == 0 ? available : mandatory).isEmpty
                              ? EmptyState(
                                  icon: Icons.school_outlined,
                                  title: 'No Training Created Yet',
                                  subtitle: _tab == 0
                                      ? 'Tap the + button above to create your first training programme.'
                                      : 'No mandatory training programmes have been created yet.',
                                )
                              : ListView(
                                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                                  children: (_tab == 0 ? available : mandatory)
                                      .map(
                                        (t) => Padding(
                                          padding: const EdgeInsets.only(bottom: 12),
                                          child: _HrTrainingCard(
                                            program: t,
                                            onEdit: () => _editProgram(t),
                                            onAssignDept: () => _assignDepartment(t),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HrTrainingCard extends StatelessWidget {
  final TrainingProgram program;
  final VoidCallback onEdit;
  final VoidCallback onAssignDept;
  const _HrTrainingCard({required this.program, required this.onEdit, required this.onAssignDept});

  Color _catColor(AppColorsExtension c) {
    switch (program.category) {
      case 'Leadership':
        return c.purple;
      case 'Behavioural':
        return c.amber;
      default:
        return c.infoBlue;
    }
  }

  Color _catBg(AppColorsExtension c) {
    switch (program.category) {
      case 'Leadership':
        return c.purpleBg;
      case 'Behavioural':
        return c.amberBg;
      default:
        return c.infoBlueBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _catBg(c),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  program.category,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _catColor(c),
                  ),
                ),
              ),
              const Spacer(),
              if (program.isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.riskHighBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Mandatory',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: c.riskHigh,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            program.title,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            program.description,
            style: TextStyle(
              fontSize: 12.5,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 13,
                color: c.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                program.duration,
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.people_outline_rounded,
                size: 13,
                color: c.textMuted,
              ),
              const SizedBox(width: 5),
              Text(
                '${program.enrolledCount} enrolled',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (program.department != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.apartment_rounded, size: 13, color: c.primaryDark),
                const SizedBox(width: 5),
                Text('Assigned to ${program.department}', style: TextStyle(fontSize: 11.5, color: c.primaryDark, fontWeight: FontWeight.w700)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Edit', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onAssignDept,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'Assign Dept',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompletionTab extends StatelessWidget {
  const _CompletionTab();

  Future<void> _setScore(BuildContext context, TrainingCompletionRecord record) async {
    final controller = TextEditingController();
    final score = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Score — ${record.employeeName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.programTitle, style: TextStyle(fontSize: 12.5, color: dialogContext.colors.textSecondary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Performance Score (0-100)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              Navigator.of(dialogContext).pop(value?.clamp(0, 100));
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (score == null) return;
    final success = await trainingController.setScore(record, score);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? '✓ Score saved for ${record.employeeName}' : trainingController.errorMessage ?? 'Could not save score')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final records = trainingController.completionRecords;
    final rate = trainingController.overallCompletionRate;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Overall Completion Rate',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: rate,
                  minHeight: 10,
                  backgroundColor: c.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(c.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(rate * 100).toInt()}% across all active enrollments',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Employee Progress'),
        if (records.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('No enrollments yet.', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
          ),
        ...records.map((d) {
          final initials = d.employeeName.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
          final color = d.progress >= 1.0
              ? c.primary
              : d.progress >= 0.5
                  ? c.amber
                  : c.riskHigh;
          final needsScore = d.progress >= 1.0 && d.performanceScore == null;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              onTap: needsScore ? () => _setScore(context, d) : null,
              borderRadius: BorderRadius.circular(16),
              child: AppCard(
                child: Row(
                  children: [
                    InitialsAvatar(initials: initials, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.employeeName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            d.programTitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: c.textMuted,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(100),
                            child: LinearProgressIndicator(
                              value: d.progress,
                              minHeight: 6,
                              backgroundColor: c.surfaceMuted,
                              valueColor: AlwaysStoppedAnimation(color),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${(d.progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        if (d.performanceScore != null)
                          Text(
                            'Score: ${d.performanceScore!.toInt()}',
                            style: TextStyle(fontSize: 10.5, color: c.textMuted, fontWeight: FontWeight.w600),
                          )
                        else if (needsScore)
                          Text(
                            'Tap to score',
                            style: TextStyle(fontSize: 10.5, color: c.primary, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _CreateProgramSheet extends StatefulWidget {
  final TrainingProgram? existing;

  const _CreateProgramSheet({this.existing});

  @override
  State<_CreateProgramSheet> createState() => _CreateProgramSheetState();
}

class _CreateProgramSheetState extends State<_CreateProgramSheet> {
  static const _categories = [
    (name: 'Technical', icon: Icons.code_rounded),
    (name: 'Behavioural', icon: Icons.groups_rounded),
    (name: 'Leadership', icon: Icons.trending_up_rounded),
  ];
  static const _units = ['Hours', 'Days', 'Weeks', 'Months'];
  static const _formats = ['Self-paced', 'Instructor-led', 'Workshop'];

  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _duration = TextEditingController(text: widget.existing?.duration);
  late final _durationValue = TextEditingController(text: '2');
  String _durationUnit = 'Weeks';
  String _format = 'Self-paced';
  late String _category = widget.existing?.category ?? 'Technical';
  late bool _mandatory = widget.existing?.isMandatory ?? false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  Color _catColor(AppColorsExtension c, String cat) {
    switch (cat) {
      case 'Leadership':
        return c.purple;
      case 'Behavioural':
        return c.amber;
      default:
        return c.infoBlue;
    }
  }

  Color _catBg(AppColorsExtension c, String cat) {
    switch (cat) {
      case 'Leadership':
        return c.purpleBg;
      case 'Behavioural':
        return c.amberBg;
      default:
        return c.infoBlueBg;
    }
  }

  Future<void> _save() async {
    final duration = _isEditing ? _duration.text.trim() : '${_durationValue.text.trim()} $_durationUnit · $_format';
    setState(() => _saving = true);
    final success = await trainingController.saveProgram(
      existingId: widget.existing?.dbId,
      title: _title.text.trim(),
      category: _category,
      description: _desc.text.trim(),
      isMandatory: _mandatory,
      duration: duration,
      departmentName: widget.existing?.department,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trainingController.errorMessage ?? 'Could not save training programme')),
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing ? '✓ Training programme updated successfully' : '✓ Training programme created successfully',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
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
              _isEditing ? 'Edit Training Program' : 'Create Training Program',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 20),

            const Text(
              'Program Title',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _title,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: 'e.g. Advanced Leadership Workshop',
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Category',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: _categories.map((cat) {
                final sel = _category == cat.name;
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: cat.name != _categories.last.name ? 8 : 0),
                    child: InkWell(
                      onTap: () => setState(() => _category = cat.name),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? _catBg(c, cat.name) : c.surfaceMuted,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sel ? _catColor(c, cat.name) : Colors.transparent, width: 1.5),
                        ),
                        child: Column(
                          children: [
                            Icon(cat.icon, size: 20, color: sel ? _catColor(c, cat.name) : c.textMuted),
                            const SizedBox(height: 6),
                            Text(
                              cat.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: sel ? _catColor(c, cat.name) : c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // Live preview — shows HR exactly what employees will see on
            // the training list before they commit to creating it.
            Text('Preview', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted, letterSpacing: 0.5)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _catBg(c, _category), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_categories.firstWhere((cat) => cat.name == _category).icon, color: _catColor(c, _category), size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _title.text.trim().isEmpty ? 'Untitled Programme' : _title.text.trim(),
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _title.text.trim().isEmpty ? c.textMuted : c.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _catBg(c, _category), borderRadius: BorderRadius.circular(100)),
                              child: Text(_category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _catColor(c, _category))),
                            ),
                            if (_mandatory)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(100)),
                                child: Text('Mandatory', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c.riskHigh)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 12, color: c.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              _isEditing ? (_duration.text.trim().isEmpty ? '—' : _duration.text.trim()) : '${_durationValue.text.trim().isEmpty ? '0' : _durationValue.text.trim()} $_durationUnit · $_format',
                              style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            const Text(
              'Description',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Brief description of the training content and goals...',
              ),
            ),
            const SizedBox(height: 14),

            if (_isEditing) ...[
              const Text(
                'Duration',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _duration,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'e.g. 2 weeks · Self-paced',
                  prefixIcon: Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: c.textMuted,
                  ),
                ),
              ),
            ] else ...[
              const Text(
                'Duration',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _durationValue,
                      keyboardType: TextInputType.number,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _durationUnit,
                      isExpanded: true,
                      decoration: const InputDecoration(isDense: true),
                      items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _durationUnit = v ?? _durationUnit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: _formats.map((f) {
                  final sel = _format == f;
                  return ChoiceChip(
                    label: Text(f),
                    selected: sel,
                    onSelected: (_) => setState(() => _format = f),
                    selectedColor: c.primaryLight,
                    labelStyle: TextStyle(color: sel ? c.primaryDark : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                    side: BorderSide(color: sel ? c.primary : Colors.transparent),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Mark as Mandatory',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                Switch(
                  value: _mandatory,
                  onChanged: (v) => setState(() => _mandatory = v),
                  activeThumbColor: c.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Create Program',
              icon: _isEditing ? Icons.save_rounded : Icons.school_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
