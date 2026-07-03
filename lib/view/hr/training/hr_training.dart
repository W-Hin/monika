import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
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
                      Expanded(child: StatCard(label: 'Total Programs', value: '${DummyData.availableTrainings.length}', icon: Icons.school_rounded, iconColor: AppColors.primary, iconBg: AppColors.primaryLight)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Mandatory', value: '${DummyData.mandatoryTrainings.length}', icon: Icons.assignment_rounded, iconColor: AppColors.riskHigh, iconBg: AppColors.riskHighBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Recommended', value: '${DummyData.recommendedTrainings.length}', icon: Icons.auto_awesome_rounded, iconColor: AppColors.amber, iconBg: AppColors.amberBg)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
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
                                color: sel ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: sel ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)] : null,
                              ),
                              child: Text(_tabs[i], textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? AppColors.textPrimary : AppColors.textMuted)),
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
                  ? _CompletionTab()
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: (_tab == 0 ? DummyData.availableTrainings : DummyData.mandatoryTrainings)
                    .map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _HrTrainingCard(program: t),
                ))
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
  const _HrTrainingCard({required this.program});

  Color get _catColor {
    switch (program.category) {
      case 'Leadership': return AppColors.purple;
      case 'Behavioural': return AppColors.amber;
      default: return AppColors.infoBlue;
    }
  }

  Color get _catBg {
    switch (program.category) {
      case 'Leadership': return AppColors.purpleBg;
      case 'Behavioural': return AppColors.amberBg;
      default: return AppColors.infoBlueBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: _catBg, borderRadius: BorderRadius.circular(100)),
                child: Text(program.category, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _catColor)),
              ),
              const Spacer(),
              if (program.isMandatory)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.riskHighBg, borderRadius: BorderRadius.circular(100)),
                  child: const Text('Mandatory', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.riskHigh)),
                ),
              if (program.isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(100)),
                  child: const Text('ML Recommended', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.amber)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(program.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(program.description, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(program.duration, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Icon(Icons.people_outline_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              const Text('12 enrolled', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('Edit', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                  child: const Text('Assign Dept', style: TextStyle(fontSize: 12.5)),
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
  final _data = const [
    ('Hin Chen Wei', 'Engineering', 0.6, 'Workplace Data Privacy'),
    ('Nur Aina Zulkifli', 'Design', 1.0, 'Leadership Fundamentals'),
    ('Ramesh Kumar', 'Sales', 0.3, 'Effective Stakeholder Comm.'),
    ('Tan Wei Ming', 'Engineering', 0.0, 'Advanced Flutter Architecture'),
    ('Faiz Hidayat', 'Operations', 0.85, 'Time Management Essentials'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Overall Completion Rate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(value: 0.55, minHeight: 10, backgroundColor: AppColors.surfaceMuted, valueColor: const AlwaysStoppedAnimation(AppColors.primary)),
              ),
              const SizedBox(height: 6),
              const Text('55% across all active training programmes', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const SectionHeader(title: 'Employee Progress'),
        ..._data.map((d) {
          final initials = d.$1.split(' ').map((w) => w[0]).take(2).join();
          final color = d.$3 >= 1.0 ? AppColors.primary : d.$3 >= 0.5 ? AppColors.amber : AppColors.riskHigh;
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
                        Text(d.$1, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(d.$4, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: LinearProgressIndicator(value: d.$3, minHeight: 6, backgroundColor: AppColors.surfaceMuted, valueColor: AlwaysStoppedAnimation(color)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${(d.$3 * 100).toInt()}%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
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
  const _CreateProgramSheet();

  @override
  State<_CreateProgramSheet> createState() => _CreateProgramSheetState();
}

class _CreateProgramSheetState extends State<_CreateProgramSheet> {
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _duration = TextEditingController();
  String _category = 'Technical';
  bool _mandatory = false;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(100)))),
            const SizedBox(height: 20),
            const Text('Create Training Program', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            const Text('Program Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'e.g. Advanced Leadership Workshop')),
            const SizedBox(height: 14),

            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Technical', 'Behavioural', 'Leadership'].map((c) {
                final sel = _category == c;
                return ChoiceChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setState(() => _category = c),
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(color: sel ? AppColors.primaryDark : AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  side: BorderSide(color: sel ? AppColors.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            const Text('Description', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: _desc, maxLines: 3, decoration: const InputDecoration(hintText: 'Brief description of the training content and goals...')),
            const SizedBox(height: 14),

            const Text('Duration', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(controller: _duration, decoration: const InputDecoration(hintText: 'e.g. 2 weeks · Self-paced', prefixIcon: Icon(Icons.schedule_rounded, size: 18, color: AppColors.textMuted))),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mark as Mandatory', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Switch(value: _mandatory, onChanged: (v) => setState(() => _mandatory = v), activeColor: AppColors.primary),
              ],
            ),
            const SizedBox(height: 20),

            PrimaryButton(
              label: 'Create Program',
              icon: Icons.school_rounded,
              onPressed: () {
                setState(() => _saving = true);
                Future.delayed(const Duration(milliseconds: 700), () {
                  if (!mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Training programme created successfully')),
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