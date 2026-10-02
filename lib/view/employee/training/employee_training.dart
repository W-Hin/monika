import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../../controller/training_controller.dart';
import 'training_detail.dart';

class EmployeeTrainingScreen extends StatefulWidget {
  const EmployeeTrainingScreen({super.key});

  @override
  State<EmployeeTrainingScreen> createState() => _EmployeeTrainingScreenState();
}

class _EmployeeTrainingScreenState extends State<EmployeeTrainingScreen> {
  int _tab = 0;
  final _tabs = const ['All Programs', 'Recommended', 'Mandatory', 'Completed'];

  @override
  void initState() {
    super.initState();
    trainingController.loadMy();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final myDepartment = DummyData.employeeUser.department;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Training & Development'),
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: trainingController,
          builder: (context, _) {
            final all = trainingController.myPrograms;
            final recommended = all.where((t) => t.isRecommended).toList();
            final mandatory = all
                .where(
                  (t) =>
                      t.isMandatory &&
                      (t.department == null || t.department == myDepartment),
                )
                .toList();
            final completed = all.where((t) => t.isCompleted).toList();

            List<TrainingProgram> list;
            switch (_tab) {
              case 1:
                list = recommended;
                break;
              case 2:
                list = mandatory;
                break;
              case 3:
                list = completed;
                break;
              default:
                list = all;
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
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
                                color: selected
                                    ? c.surface
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(11),
                                boxShadow: selected
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.06,
                                          ),
                                          blurRadius: 6,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _tabs[i],
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? c.textPrimary
                                        : c.textMuted,
                                  ),
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
                  child: trainingController.loading && all.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : list.isEmpty
                      ? EmptyState(
                          icon: Icons.school_outlined,
                          title: 'No programmes here yet',
                          subtitle: _tab == 1
                              ? 'Check back after your next performance evaluation.'
                              : 'Nothing in this category right now.',
                        )
                      : RefreshIndicator(
                          onRefresh: trainingController.loadMy,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                            children: list
                                .map(
                                  (t) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _TrainingCard(
                                      program: t,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              TrainingDetailScreen(program: t),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
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

class _TrainingCard extends StatelessWidget {
  final TrainingProgram program;
  final VoidCallback onTap;
  const _TrainingCard({required this.program, required this.onTap});

  Color _catColor(BuildContext context) {
    final c = context.colors;
    switch (program.category) {
      case 'Leadership':
        return c.purple;
      case 'Behavioural':
        return c.amber;
      default:
        return c.infoBlue;
    }
  }

  Color _catBg(BuildContext context) {
    final c = context.colors;
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
                  color: _catBg(context),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  program.category,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _catColor(context),
                  ),
                ),
              ),
              const Spacer(),
              if (program.locked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(100)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded, size: 11, color: c.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        'Opens after ${program.minTenureMonths} mo',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.textMuted),
                      ),
                    ],
                  ),
                )
              else if (program.isCompleted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.riskLowBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: c.primary,
                    ),
                  ),
                )
              else if (program.isMandatory)
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
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
            ),
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
              Icon(Icons.schedule_rounded, size: 13, color: c.textMuted),
              const SizedBox(width: 5),
              Text(
                program.duration,
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (program.isRecommended &&
              program.recommendationReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: c.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 14,
                    color: c.primaryDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      program.recommendationReason!,
                      style: TextStyle(
                        fontSize: 11,
                        color: c.primaryDark,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (program.isCompleted && program.performanceScore != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.riskLowBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 14,
                    color: c.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Performance Score: ${program.performanceScore!.toInt()}/100',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ] else if (program.isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: c.surfaceMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Awaiting performance score from HR',
                style: TextStyle(
                  fontSize: 11.5,
                  color: c.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ] else if (program.isEnrolled) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: program.progress,
                minHeight: 6,
                backgroundColor: c.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(c.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${(program.progress * 100).toInt()}% complete',
              style: TextStyle(
                fontSize: 11,
                color: c.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (!program.isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                child: Text(
                  program.isEnrolled ? 'Continue' : 'View Details & Enrol',
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onTap,
                child: const Text('View Details'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
