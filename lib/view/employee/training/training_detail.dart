import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/training_controller.dart';

class TrainingDetailScreen extends StatefulWidget {
  final TrainingProgram program;

  const TrainingDetailScreen({super.key, required this.program});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  late TrainingProgram _program;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
  }

  Color _catColor(BuildContext context) {
    final c = context.colors;
    switch (_program.category) {
      case 'Leadership':
        return c.purple;
      case 'Behavioural':
        return c.amber;
      default:
        return c.infoBlue;
    }
  }

  /// Pulls the freshly-reloaded version of this program from the
  /// controller's list (by dbId) after a mutation succeeds, so the
  /// screen reflects whatever was actually saved.
  void _syncFromController() {
    final updated = trainingController.myPrograms.where((p) => p.dbId == _program.dbId);
    if (updated.isNotEmpty) {
      setState(() => _program = updated.first);
    }
  }

  Future<void> _refresh() async {
    await trainingController.loadMy();
    if (!mounted) return;
    _syncFromController();
  }

  Future<void> _enroll() async {
    setState(() => _busy = true);
    final success = await trainingController.enroll(_program);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trainingController.errorMessage ?? 'Could not enrol')),
      );
      return;
    }
    _syncFromController();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Enrolled successfully')),
    );
  }

  Future<void> _continue() async {
    setState(() => _busy = true);
    final wasCompleted = _program.isCompleted;
    final success = await trainingController.continueTraining(_program);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trainingController.errorMessage ?? 'Could not update progress')),
      );
      return;
    }
    _syncFromController();
    if (!wasCompleted && _program.isCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 Training completed! HR will review and score it soon.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = _program;
    final catColor = _catColor(context);
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Training Details'),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: catColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(100)),
                  child: Text(p.category, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: catColor)),
                ),
                const SizedBox(width: 8),
                if (p.isMandatory)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(100)),
                    child: Text('Mandatory', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.riskHigh)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(p.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary)),
            const SizedBox(height: 8),
            Text(p.description, style: TextStyle(fontSize: 13.5, color: c.textSecondary, height: 1.5)),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 15, color: c.textMuted),
                const SizedBox(width: 6),
                Text(p.duration, style: TextStyle(fontSize: 12.5, color: c.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
            if (p.isRecommended && p.recommendationReason != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: c.primaryDark),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.recommendationReason!, style: TextStyle(fontSize: 12.5, color: c.primaryDark, fontWeight: FontWeight.w600, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (p.isCompleted) ...[
              AppCard(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: c.riskLowBg, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.workspace_premium_rounded, color: c.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Training Performance Score', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    ),
                    Text(
                      p.performanceScore != null ? '${p.performanceScore!.toInt()} / 100' : 'Pending HR review',
                      style: TextStyle(fontSize: p.performanceScore != null ? 16 : 12.5, fontWeight: FontWeight.w900, color: p.performanceScore != null ? c.primary : c.textMuted),
                    ),
                  ],
                ),
              ),
            ] else if (p.progress > 0) ...[
              const SectionHeader(title: 'Your Progress'),
              ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: p.progress,
                  minHeight: 8,
                  backgroundColor: c.surfaceMuted,
                  valueColor: AlwaysStoppedAnimation(c.primary),
                ),
              ),
              const SizedBox(height: 6),
              Text('${(p.progress * 100).toInt()}% complete', style: TextStyle(fontSize: 11.5, color: c.textMuted, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Continue Training', icon: Icons.play_arrow_rounded, onPressed: _continue, isLoading: _busy),
            ] else ...[
              PrimaryButton(label: 'Enrol Now', icon: Icons.how_to_reg_rounded, onPressed: _enroll, isLoading: _busy),
            ],
          ],
          ),
        ),
      ),
    );
  }
}
