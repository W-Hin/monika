import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/training_controller.dart';
import '../../../controller/training_content_controller.dart';
import '../../../controller/certificate_controller.dart';
import 'certificates.dart';
import 'training_quiz.dart';

class TrainingDetailScreen extends StatefulWidget {
  final TrainingProgram program;

  const TrainingDetailScreen({super.key, required this.program});

  @override
  State<TrainingDetailScreen> createState() => _TrainingDetailScreenState();
}

class _TrainingDetailScreenState extends State<TrainingDetailScreen> {
  late TrainingProgram _program;
  bool _busy = false;
  TrainingCertificate? _certificate;

  @override
  void initState() {
    super.initState();
    _program = widget.program;
    _loadContent();
  }

  Future<void> _loadContent() async {
    final id = _program.dbId;
    if (id == null) return;
    await trainingContentController.load(programId: id, enrollmentId: _program.enrollmentId);
    await _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    final enrollmentId = _program.enrollmentId;
    if (!_program.isCompleted || enrollmentId == null) return;
    final cert = await certificateController.forEnrollment(enrollmentId);
    if (mounted) setState(() => _certificate = cert);
  }

  void _openCertificate(TrainingCertificate cert) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CertificateScreen(certificate: cert)));
  }

  /// Shown once, right after the action that completed the programme.
  void _announceCertificate() {
    final cert = _certificate;
    if (cert == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🎓 Certificate ${cert.certificateNo} earned!'),
        action: SnackBarAction(label: 'View', onPressed: () => _openCertificate(cert)),
      ),
    );
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
    await _loadContent();
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
    _loadContent();
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
      await _loadCertificate();
      if (_certificate != null) {
        _announceCertificate();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🎉 Training completed! HR will review and score it soon.')),
        );
      }
    }
  }

  Future<void> _markRead(TrainingLesson lesson) async {
    final ok = await trainingContentController.markLessonRead(lesson);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(trainingContentController.errorMessage ?? 'Could not mark as read'), backgroundColor: context.colors.riskHigh),
      );
      return;
    }
    await trainingController.loadMy();
    if (!mounted) return;
    _syncFromController();
  }

  Future<void> _takeQuiz() async {
    final wasCompleted = _program.isCompleted;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TrainingQuizScreen(programId: _program.dbId!, programTitle: _program.title)),
    );
    // Refresh however they came back — the "Back to Programme" button pops
    // true but the app-bar/system back pops null, and the attempt is
    // already saved server-side either way.
    if (!mounted) return;
    await _refresh();
    if (!wasCompleted && _program.isCompleted) _announceCertificate();
  }

  List<Widget> _contentSection(BuildContext context) {
    final c = context.colors;
    final content = trainingContentController;
    if (!content.hasContent) return const [];
    final enrolled = _program.isEnrolled;
    return [
      const SizedBox(height: 24),
      if (content.lessons.isNotEmpty) ...[
        SectionHeader(title: 'Lessons (${enrolled ? '${content.lessonsDone}/' : ''}${content.lessons.length})'),
        if (!enrolled)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Enrol to unlock the full lessons.', style: TextStyle(fontSize: 12, color: c.textMuted)),
          ),
        for (var i = 0; i < content.lessons.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LessonCard(
              index: i + 1,
              lesson: content.lessons[i],
              unlocked: enrolled,
              onMarkRead: () => _markRead(content.lessons[i]),
            ),
          ),
      ],
      if (content.hasQuiz) ...[
        const SizedBox(height: 14),
        const SectionHeader(title: 'Quiz'),
        _QuizCard(
          questionCount: content.quizQuestionCount,
          passMark: content.passMark,
          bestScore: content.bestScore,
          attempts: content.attemptCount,
          enrolled: enrolled,
          lessonsDone: content.allLessonsDone,
          passed: _program.isCompleted,
          onTake: _takeQuiz,
        ),
        if (content.attempts.isNotEmpty) ...[
          const SizedBox(height: 14),
          SectionHeader(title: 'Attempt History (${content.attempts.length})'),
          _AttemptHistory(attempts: content.attempts, passMark: content.passMark),
        ],
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = _program;
    final catColor = _catColor(context);
    return ListenableBuilder(
      listenable: trainingContentController,
      builder: (context, _) => _buildScaffold(context, c, p, catColor),
    );
  }

  Widget _buildScaffold(BuildContext context, AppColorsExtension c, TrainingProgram p, Color catColor) {
    final hasContent = trainingContentController.hasContent;
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
              if (_certificate != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCertificate(_certificate!),
                    icon: const Icon(Icons.workspace_premium_outlined, size: 18),
                    label: Text('View Certificate · ${_certificate!.certificateNo}'),
                  ),
                ),
              ],
            ] else if (p.isEnrolled) ...[
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
              // Programmes with lessons/a quiz track progress through them;
              // only content-less ones keep the old tap-to-advance button.
              if (!hasContent) ...[
                const SizedBox(height: 20),
                PrimaryButton(label: 'Continue Training', icon: Icons.play_arrow_rounded, onPressed: _continue, isLoading: _busy),
              ],
            ] else if (p.locked) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 18, color: c.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'This programme opens after ${p.minTenureMonths} months of service.',
                        style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w600, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              PrimaryButton(label: 'Enrol Now', icon: Icons.how_to_reg_rounded, onPressed: _enroll, isLoading: _busy),
            ],
            ..._contentSection(context),
          ],
          ),
        ),
      ),
    );
  }
}


class _LessonCard extends StatelessWidget {
  final int index;
  final TrainingLesson lesson;
  final bool unlocked;
  final VoidCallback onMarkRead;
  const _LessonCard({required this.index, required this.lesson, required this.unlocked, required this.onMarkRead});

  static bool _looksLikeImage(String url) {
    final u = url.toLowerCase().split('?').first;
    return u.endsWith('.png') || u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.gif') || u.endsWith('.webp');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final media = lesson.mediaUrl;
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          enabled: unlocked,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          leading: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: lesson.completed ? c.riskLowBg : c.surfaceMuted, shape: BoxShape.circle),
            child: lesson.completed
                ? Icon(Icons.check_rounded, size: 17, color: c.primary)
                : Text('$index', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: unlocked ? c.textSecondary : c.textMuted)),
          ),
          title: Text(lesson.title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: unlocked ? c.textPrimary : c.textMuted)),
          trailing: unlocked ? null : Icon(Icons.lock_outline_rounded, size: 17, color: c.textMuted),
          children: [
            if (lesson.body.isNotEmpty) Text(lesson.body, style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.55)),
            if (media != null && media.isNotEmpty) ...[
              const SizedBox(height: 12),
              if (_looksLikeImage(media))
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    media,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Text('Image could not be loaded: $media', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                  decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 16, color: c.infoBlue),
                      const SizedBox(width: 8),
                      Expanded(child: Text(media, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: c.infoBlue))),
                      IconButton(
                        tooltip: 'Copy link',
                        icon: Icon(Icons.copy_rounded, size: 16, color: c.textMuted),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: media));
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
                        },
                      ),
                    ],
                  ),
                ),
            ],
            if (!lesson.completed) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: onMarkRead,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Mark as read'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Every quiz attempt, newest first, numbered in the order they were taken.
class _AttemptHistory extends StatelessWidget {
  final List<QuizAttempt> attempts;
  final int passMark;
  const _AttemptHistory({required this.attempts, required this.passMark});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final best = attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < attempts.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: Text('Attempt ${attempts.length - i}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat('d MMM yyyy, h:mm a').format(attempts[i].takenAt),
                      style: TextStyle(fontSize: 11.5, color: c.textMuted),
                    ),
                  ),
                  if (attempts[i].score == best && attempts.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(Icons.star_rounded, size: 15, color: c.amber),
                    ),
                  Text('${attempts[i].score.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: attempts[i].passed ? c.riskLowBg : c.riskHighBg,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      attempts[i].passed ? 'Passed' : 'Below $passMark%',
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: attempts[i].passed ? c.primary : c.riskHigh),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final int questionCount;
  final int passMark;
  final double? bestScore;
  final int attempts;
  final bool enrolled;
  final bool lessonsDone;
  final bool passed;
  final VoidCallback onTake;
  const _QuizCard({
    required this.questionCount,
    required this.passMark,
    required this.bestScore,
    required this.attempts,
    required this.enrolled,
    required this.lessonsDone,
    required this.passed,
    required this.onTake,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unlocked = enrolled && lessonsDone;
    final note = !enrolled
        ? 'Enrol to take the quiz.'
        : !lessonsDone
            ? 'Mark every lesson as read to unlock the quiz.'
            : bestScore == null
                ? 'Not attempted yet.'
                : 'Best score ${bestScore!.toStringAsFixed(0)}% · $attempts attempt${attempts == 1 ? '' : 's'}';
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.amberBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.quiz_rounded, color: c.amber, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$questionCount questions · pass mark $passMark%', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(note, style: TextStyle(fontSize: 12, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: unlocked ? onTake : null,
              icon: Icon(passed ? Icons.replay_rounded : Icons.play_arrow_rounded, size: 18),
              label: Text(attempts == 0 ? 'Take Quiz' : (passed ? 'Retake for a better score' : 'Retake Quiz')),
            ),
          ),
        ],
      ),
    );
  }
}
