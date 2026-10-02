import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../model/models.dart';
import '../../../controller/training_content_controller.dart';

/// HR's editor for a programme's lessons and quiz. Employees only ever see
/// the questions without answers (see TrainingContentService) — the correct
/// option is set here and checked server-side.
class TrainingContentEditorScreen extends StatefulWidget {
  final int programId;
  final String programTitle;
  const TrainingContentEditorScreen({
    super.key,
    required this.programId,
    required this.programTitle,
  });

  @override
  State<TrainingContentEditorScreen> createState() =>
      _TrainingContentEditorScreenState();
}

class _TrainingContentEditorScreenState
    extends State<TrainingContentEditorScreen> {
  @override
  void initState() {
    super.initState();
    trainingContentController.loadForHr(widget.programId);
  }

  void _toast(bool ok, String success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? success
              : trainingContentController.errorMessage ??
                    'Something went wrong',
        ),
        backgroundColor: ok ? null : context.colors.riskHigh,
      ),
    );
  }

  Future<void> _editLesson([TrainingLesson? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _LessonSheet(programId: widget.programId, existing: existing),
    );
  }

  Future<void> _editQuestion([QuizQuestion? existing]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _QuestionSheet(programId: widget.programId, existing: existing),
    );
  }

  Future<bool> _confirmDelete(String what) async {
    final c = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Delete this $what?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(d).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(d).pop(true),
            child: Text('Delete', style: TextStyle(color: c.riskHigh)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: SimpleAppBar(title: widget.programTitle),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: trainingContentController,
          builder: (context, _) {
            final content = trainingContentController;
            if (content.loading &&
                content.lessons.isEmpty &&
                content.hrQuestions.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                Text(
                  'Employees read the lessons, then take the quiz. A programme with no lessons or questions keeps simple self-reported progress.',
                  style: TextStyle(
                    fontSize: 12,
                    color: c.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SectionHeader(title: 'Lessons (${content.lessons.length})'),
                if (content.lessons.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'No lessons yet.',
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                  ),
                for (final l in content.lessons)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(
                      title: l.title,
                      subtitle: l.body.isEmpty
                          ? (l.mediaUrl ?? 'No text')
                          : l.body,
                      first: l.id == content.lessons.first.id,
                      last: l.id == content.lessons.last.id,
                      onUp: () => content.moveLesson(widget.programId, l, -1),
                      onDown: () => content.moveLesson(widget.programId, l, 1),
                      onEdit: () => _editLesson(l),
                      onDelete: () async {
                        if (!await _confirmDelete('lesson')) return;
                        final ok = await content.deleteLesson(
                          widget.programId,
                          l,
                        );
                        if (mounted) _toast(ok, '✓ Lesson deleted');
                      },
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _editLesson(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Lesson'),
                ),
                const SizedBox(height: 28),
                SectionHeader(
                  title: 'Quiz (${content.hrQuestions.length} questions)',
                ),
                _PassMarkRow(programId: widget.programId),
                const SizedBox(height: 12),
                if (content.hrQuestions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      'No questions yet — add at least one to turn on the quiz.',
                      style: TextStyle(fontSize: 12.5, color: c.textMuted),
                    ),
                  ),
                for (final q in content.hrQuestions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ItemCard(
                      title: q.question,
                      subtitle: 'Answer: ${q.options[q.correctIndex ?? 0]}',
                      first: q.id == content.hrQuestions.first.id,
                      last: q.id == content.hrQuestions.last.id,
                      onUp: () => content.moveQuestion(widget.programId, q, -1),
                      onDown: () =>
                          content.moveQuestion(widget.programId, q, 1),
                      onEdit: () => _editQuestion(q),
                      onDelete: () async {
                        if (!await _confirmDelete('question')) return;
                        final ok = await content.deleteQuestion(
                          widget.programId,
                          q,
                        );
                        if (mounted) _toast(ok, '✓ Question deleted');
                      },
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => _editQuestion(),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Question'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool first;
  final bool last;
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ItemCard({
    required this.title,
    required this.subtitle,
    required this.first,
    required this.last,
    required this.onUp,
    required this.onDown,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: first ? null : onUp,
                child: Icon(
                  Icons.keyboard_arrow_up_rounded,
                  size: 22,
                  color: first ? c.border : c.textSecondary,
                ),
              ),
              InkWell(
                onTap: last ? null : onDown,
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 22,
                  color: last ? c.border : c.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.edit_outlined, size: 19, color: c.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 19,
              color: c.riskHigh,
            ),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _PassMarkRow extends StatefulWidget {
  final int programId;
  const _PassMarkRow({required this.programId});

  @override
  State<_PassMarkRow> createState() => _PassMarkRowState();
}

class _PassMarkRowState extends State<_PassMarkRow> {
  double? _value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final value = _value ?? trainingContentController.passMark.toDouble();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pass mark',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '${value.round()}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: c.primary,
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(50, 100),
            min: 50,
            max: 100,
            divisions: 10,
            onChanged: (v) => setState(() => _value = v),
            onChangeEnd: (v) async {
              final ok = await trainingContentController.setPassMark(
                widget.programId,
                v.round(),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? '✓ Pass mark set to ${v.round()}%'
                        : trainingContentController.errorMessage ??
                              'Could not save pass mark',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

Widget _sheetShell(
  BuildContext context, {
  required String title,
  required List<Widget> children,
}) {
  final c = context.colors;
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
      maxHeight: MediaQuery.of(context).size.height * 0.88,
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
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

Widget _errorBanner(BuildContext context, String? text) {
  if (text == null) return const SizedBox.shrink();
  final c = context.colors;
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: c.riskHighBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 12.5,
        color: c.riskHigh,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _LessonSheet extends StatefulWidget {
  final int programId;
  final TrainingLesson? existing;
  const _LessonSheet({required this.programId, this.existing});

  @override
  State<_LessonSheet> createState() => _LessonSheetState();
}

class _LessonSheetState extends State<_LessonSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late final _body = TextEditingController(text: widget.existing?.body);
  late final _media = TextEditingController(text: widget.existing?.mediaUrl);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _media.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give the lesson a title.');
      return;
    }
    if (_body.text.trim().isEmpty && _media.text.trim().isEmpty) {
      setState(() => _error = 'Add some lesson text or a media link.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final ok = await trainingContentController.saveLesson(
      programId: widget.programId,
      existing: widget.existing,
      title: _title.text.trim(),
      body: _body.text.trim(),
      mediaUrl: _media.text.trim().isEmpty ? null : _media.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = trainingContentController.errorMessage);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return _sheetShell(
      context,
      title: widget.existing == null ? 'Add Lesson' : 'Edit Lesson',
      children: [
        const Text(
          'Title',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _title,
          decoration: const InputDecoration(
            hintText: 'e.g. Spotting a phishing email',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Lesson text',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _body,
          maxLines: 8,
          minLines: 4,
          decoration: const InputDecoration(
            hintText: 'The material employees will read…',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Image or resource link (optional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _media,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText:
                'https://… (image links show inline; others show as a copyable link)',
          ),
        ),
        const SizedBox(height: 14),
        _errorBanner(context, _error),
        PrimaryButton(
          label: widget.existing == null ? 'Add Lesson' : 'Save Changes',
          icon: Icons.save_rounded,
          onPressed: _save,
          isLoading: _saving,
        ),
      ],
    );
  }
}

class _QuestionSheet extends StatefulWidget {
  final int programId;
  final QuizQuestion? existing;
  const _QuestionSheet({required this.programId, this.existing});

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  late final _question = TextEditingController(text: widget.existing?.question);
  late final _explanation = TextEditingController(
    text: widget.existing?.explanation,
  );
  late final List<TextEditingController> _options =
      (widget.existing?.options ?? const ['', '', '', ''])
          .map((o) => TextEditingController(text: o))
          .toList();
  late int _correct = widget.existing?.correctIndex ?? 0;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _explanation.dispose();
    for (final o in _options) {
      o.dispose();
    }
    super.dispose();
  }

  void _removeOption(int i) {
    setState(() {
      _options[i].dispose();
      _options.removeAt(i);
      if (_correct == i) {
        _correct = 0;
      } else if (_correct > i) {
        _correct--;
      }
    });
  }

  Future<void> _save() async {
    final options = _options.map((o) => o.text.trim()).toList();
    if (_question.text.trim().isEmpty) {
      setState(() => _error = 'Enter the question.');
      return;
    }
    if (options.any((o) => o.isEmpty)) {
      setState(() => _error = 'Fill in every option or remove the empty ones.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    final ok = await trainingContentController.saveQuestion(
      programId: widget.programId,
      existing: widget.existing,
      question: _question.text.trim(),
      options: options,
      correctIndex: _correct,
      explanation: _explanation.text.trim().isEmpty
          ? null
          : _explanation.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) {
      setState(() => _error = trainingContentController.errorMessage);
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return _sheetShell(
      context,
      title: widget.existing == null ? 'Add Question' : 'Edit Question',
      children: [
        const Text(
          'Question',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _question,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'e.g. Which of these is a sign of phishing?',
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Options — tap the circle to mark the correct one',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (var i = 0; i < _options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                InkWell(
                  onTap: () => setState(() => _correct = i),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      _correct == i
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: _correct == i ? c.primary : c.textMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _options[i],
                    decoration: InputDecoration(
                      hintText: 'Option ${i + 1}',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.remove_circle_outline_rounded,
                    size: 20,
                    color: _options.length > 2 ? c.riskHigh : c.border,
                  ),
                  onPressed: _options.length > 2
                      ? () => _removeOption(i)
                      : null,
                ),
              ],
            ),
          ),
        if (_options.length < 6)
          TextButton.icon(
            onPressed: () =>
                setState(() => _options.add(TextEditingController())),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add option'),
          ),
        const SizedBox(height: 8),
        const Text(
          'Explanation (shown after the quiz, optional)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _explanation,
          maxLines: 3,
          minLines: 2,
          decoration: const InputDecoration(
            hintText: 'Why the correct answer is right…',
          ),
        ),
        const SizedBox(height: 14),
        _errorBanner(context, _error),
        PrimaryButton(
          label: widget.existing == null ? 'Add Question' : 'Save Changes',
          icon: Icons.save_rounded,
          onPressed: _save,
          isLoading: _saving,
        ),
      ],
    );
  }
}
