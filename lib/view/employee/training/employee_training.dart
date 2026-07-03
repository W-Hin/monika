import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class EmployeeTrainingScreen extends StatefulWidget {
  const EmployeeTrainingScreen({super.key});

  @override
  State<EmployeeTrainingScreen> createState() => _EmployeeTrainingScreenState();
}

class _EmployeeTrainingScreenState extends State<EmployeeTrainingScreen> {
  int _tab = 0;
  final _tabs = const ['Recommended', 'Mandatory', 'All Programs'];

  @override
  Widget build(BuildContext context) {
    List<TrainingProgram> list;
    switch (_tab) {
      case 1:
        list = DummyData.mandatoryTrainings;
        break;
      case 2:
        list = DummyData.availableTrainings;
        break;
      default:
        list = DummyData.recommendedTrainings;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Training & Development')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    final selected = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _tab = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: selected ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                            boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 6)] : null,
                          ),
                          child: Text(
                            _tabs[i],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: selected ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(
                icon: Icons.school_outlined,
                title: 'No programmes here yet',
                subtitle: 'Check back after your next performance evaluation.',
              )
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: list.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _TrainingCard(program: t),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingCard extends StatelessWidget {
  final TrainingProgram program;
  const _TrainingCard({required this.program});

  Color get _catColor {
    switch (program.category) {
      case 'Leadership':
        return AppColors.purple;
      case 'Behavioural':
        return AppColors.amber;
      default:
        return AppColors.infoBlue;
    }
  }

  Color get _catBg {
    switch (program.category) {
      case 'Leadership':
        return AppColors.purpleBg;
      case 'Behavioural':
        return AppColors.amberBg;
      default:
        return AppColors.infoBlueBg;
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
            ],
          ),
          const SizedBox(height: 10),
          Text(program.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text(program.description, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 5),
              Text(program.duration, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
            ],
          ),
          if (program.isRecommended && program.recommendationReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.primaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      program.recommendationReason!,
                      style: const TextStyle(fontSize: 11, color: AppColors.primaryDark, fontWeight: FontWeight.w600, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (program.progress > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: program.progress,
                minHeight: 6,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text('${(program.progress * 100).toInt()}% complete', style: const TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              child: Text(program.progress > 0 ? 'Continue' : 'View Details & Enrol'),
            ),
          ),
        ],
      ),
    );
  }
}