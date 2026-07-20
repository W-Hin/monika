import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrTrainingScreen extends StatefulWidget {
  const HrTrainingScreen({super.key});

  @override
  State<HrTrainingScreen> createState() => _HrTrainingScreenState();
}

class _HrTrainingScreenState extends State<HrTrainingScreen> {
  int _tab = 0;
  final _tabs = ['All Programs', 'Mandatory', 'Completion'];

  late List<TrainingProgram> _available;
  late List<TrainingProgram> _mandatory;

  final _departments = ['Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];

  @override
  void initState() {
    super.initState();
    _available = List.from(DummyData.availableTrainings);
    _mandatory = List.from(DummyData.mandatoryTrainings);
  }

  void _replaceProgram(TrainingProgram original, TrainingProgram updated) {
    setState(() {
      for (final list in [_available, _mandatory]) {
        final i = list.indexWhere((t) => t.title == original.title);
        if (i != -1) list[i] = updated;
      }
    });
  }

  void _assignDepartment(TrainingProgram program) {
    showModalBottomSheet(
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
                  trailing: program.department == d ? const Icon(Icons.check_rounded, color: AppColors.primary) : null,
                  onTap: () {
                    _replaceProgram(program, program.copyWith(department: d));
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('✓ Assigned to $d department')),
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
      builder: (_) => _CreateProgramSheet(
        existing: program,
        onSaved: (updated) => _replaceProgram(program, updated),
      ),
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
                builder: (_) => _CreateProgramSheet(
                  onSaved: (created) => setState(() => _available = [..._available, created]),
                ),
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
        child: Column(
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
                          value: '${_available.length}',
                          icon: Icons.school_rounded,
                          iconColor: c.primary,
                          iconBg: c.primaryLight,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Mandatory',
                          value: '${_mandatory.length}',
                          icon: Icons.assignment_rounded,
                          iconColor: c.riskHigh,
                          iconBg: c.riskHighBg,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatCard(
                          label: 'Recommended',
                          value: '${DummyData.recommendedTrainings.length}',
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
                                          color: Colors.black.withOpacity(0.06),
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
                                  color: sel
                                      ? c.textPrimary
                                      : c.textMuted,
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
              child: _tab == 2
                  ? const _CompletionTab()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      children:
                          (_tab == 0 ? _available : _mandatory)
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
              if (program.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.amberBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'ML Recommended',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: c.amber,
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
                '12 enrolled',
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
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
                  value: 0.55,
                  minHeight: 10,
                  backgroundColor: c.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(c.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '55% across all active training programmes',
                style: TextStyle(fontSize: 12, color: c.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Employee Progress'),
        ...DummyData.trainingCompletionRecords.map((d) {
          final initials = d.employeeName.split(' ').map((w) => w[0]).take(2).join();
          final color = d.progress >= 1.0
              ? c.primary
              : d.progress >= 0.5
              ? c.amber
              : c.riskHigh;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
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
                        ),
                    ],
                  ),
                ],
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
  final ValueChanged<TrainingProgram> onSaved;

  const _CreateProgramSheet({this.existing, required this.onSaved});

  @override
  State<_CreateProgramSheet> createState() => _CreateProgramSheetState();
}

class _CreateProgramSheetState extends State<_CreateProgramSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _desc = TextEditingController(text: widget.existing?.description);
  late final _duration = TextEditingController(text: widget.existing?.duration);
  late String _category = widget.existing?.category ?? 'Technical';
  late bool _mandatory = widget.existing?.isMandatory ?? false;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

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
            Wrap(
              spacing: 8,
              children: ['Technical', 'Behavioural', 'Leadership'].map((cat) {
                final sel = _category == cat;
                return ChoiceChip(
                  label: Text(cat),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = cat),
                  selectedColor: c.primaryLight,
                  labelStyle: TextStyle(
                    color: sel
                        ? c.primaryDark
                        : c.textSecondary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: sel ? c.primary : Colors.transparent,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            const Text(
              'Description',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText:
                    'Brief description of the training content and goals...',
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Duration',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _duration,
              decoration: InputDecoration(
                hintText: 'e.g. 2 weeks · Self-paced',
                prefixIcon: Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: c.textMuted,
                ),
              ),
            ),
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
              onPressed: () {
                setState(() => _saving = true);
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (!mounted) return;
                  final result = TrainingProgram(
                    title: _title.text,
                    category: _category,
                    description: _desc.text,
                    isMandatory: _mandatory,
                    isRecommended: widget.existing?.isRecommended ?? false,
                    recommendationReason: widget.existing?.recommendationReason,
                    progress: widget.existing?.progress ?? 0,
                    duration: _duration.text,
                    isCompleted: widget.existing?.isCompleted ?? false,
                    performanceScore: widget.existing?.performanceScore,
                    department: widget.existing?.department,
                  );
                  widget.onSaved(result);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _isEditing ? '✓ Training programme updated successfully' : '✓ Training programme created successfully',
                      ),
                    ),
                  );
                });
              },
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
