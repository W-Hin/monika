import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/training_content_controller.dart';

/// The auto-graded quiz for a training programme. Grading happens on the
/// server (submit_training_quiz), so the questions arrive without answers;
/// the correct answers and explanations only appear in the review after
/// submitting.
class TrainingQuizScreen extends StatefulWidget {
  final int programId;
  final String programTitle;
  const TrainingQuizScreen({
    super.key,
    required this.programId,
    required this.programTitle,
  });

  @override
  State<TrainingQuizScreen> createState() => _TrainingQuizScreenState();
}

class _TrainingQuizScreenState extends State<TrainingQuizScreen> {
  List<QuizQuestion>? _questions;
  List<int?> _answers = [];
  QuizResult? _result;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final questions = await trainingContentController.fetchQuiz(
        widget.programId,
      );
      if (!mounted) return;
      setState(() {
        _questions = questions;
        _answers = List<int?>.filled(questions.length, null);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            'Could not load the quiz. Make sure you are enrolled in this programme.';
        _loading = false;
      });
    }
  }

  bool get _allAnswered =>
      _answers.isNotEmpty && _answers.every((a) => a != null);

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final result = await trainingContentController.submitQuiz(
      programId: widget.programId,
      answers: _answers.map((a) => a!).toList(),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trainingContentController.errorMessage ??
                'Could not submit the quiz',
          ),
          backgroundColor: context.colors.riskHigh,
        ),
      );
      return;
    }
    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: SimpleAppBar(title: widget.programTitle),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? EmptyState(
                icon: Icons.quiz_outlined,
                title: 'Quiz unavailable',
                subtitle: _error!,
                onRetry: _load,
              )
            : _result != null
            ? _ResultView(
                result: _result!,
                questions: _questions!,
                answers: _answers,
                onRetake: _load,
                onDone: () => Navigator.of(context).pop(true),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text(
                    'Answer all ${_questions!.length} questions, then submit. You need ${trainingContentController.passMark}% to pass.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < _questions!.length; i++) ...[
                    _QuestionCard(
                      index: i,
                      question: _questions![i],
                      selected: _answers[i],
                      onSelected: (v) => setState(() => _answers[i] = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 4),
                  PrimaryButton(
                    label: _allAnswered
                        ? 'Submit Quiz'
                        : 'Answer all questions to submit',
                    icon: Icons.check_rounded,
                    onPressed: _allAnswered ? _submit : null,
                    isLoading: _submitting,
                  ),
                ],
              ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final QuizQuestion question;
  final int? selected;
  final ValueChanged<int> onSelected;
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Question ${index + 1}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            question.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: c.textPrimary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < question.options.length; i++)
            _OptionTile(
              label: question.options[i],
              state: selected == i ? _OptionState.selected : _OptionState.idle,
              onTap: () => onSelected(i),
            ),
        ],
      ),
    );
  }
}

enum _OptionState { idle, selected, correct, wrong }

class _OptionTile extends StatelessWidget {
  final String label;
  final _OptionState state;
  final VoidCallback? onTap;
  const _OptionTile({required this.label, required this.state, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (Color bg, Color border, Color fg, IconData icon) = switch (state) {
      _OptionState.selected => (
        c.primaryLight,
        c.primary,
        c.primaryDark,
        Icons.radio_button_checked_rounded,
      ),
      _OptionState.correct => (
        c.riskLowBg,
        c.primary,
        c.primaryDark,
        Icons.check_circle_rounded,
      ),
      _OptionState.wrong => (
        c.riskHighBg,
        c.riskHigh,
        c.riskHigh,
        Icons.cancel_rounded,
      ),
      _OptionState.idle => (
        c.surfaceMuted,
        Colors.transparent,
        c.textPrimary,
        Icons.radio_button_unchecked_rounded,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border, width: 1.4),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: state == _OptionState.idle ? c.textMuted : fg,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: fg,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final QuizResult result;
  final List<QuizQuestion> questions;
  final List<int?> answers;
  final VoidCallback onRetake;
  final VoidCallback onDone;
  const _ResultView({
    required this.result,
    required this.questions,
    required this.answers,
    required this.onRetake,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final passed = result.passed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: passed ? c.riskLowBg : c.riskHighBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(
                passed ? Icons.workspace_premium_rounded : Icons.replay_rounded,
                size: 36,
                color: passed ? c.primary : c.riskHigh,
              ),
              const SizedBox(height: 8),
              Text(
                '${result.score.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: passed ? c.primaryDark : c.riskHigh,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                passed ? 'Passed' : 'Not passed yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: passed ? c.primaryDark : c.riskHigh,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${result.correct} of ${result.total} correct · pass mark ${result.passMark}%',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionHeader(title: 'Review'),
        for (var i = 0; i < questions.length; i++) ...[
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  questions[i].question,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: c.textPrimary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                for (var o = 0; o < questions[i].options.length; o++)
                  _OptionTile(
                    label: questions[i].options[o],
                    state: o == result.review[i].correctIndex
                        ? _OptionState.correct
                        : (answers[i] == o
                              ? _OptionState.wrong
                              : _OptionState.idle),
                  ),
                if ((result.review[i].explanation ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    result.review[i].explanation!,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        if (!passed) ...[
          PrimaryButton(
            label: 'Retake Quiz',
            icon: Icons.replay_rounded,
            onPressed: onRetake,
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: onDone,
          child: const Text('Back to Programme'),
        ),
      ],
    );
  }
}
