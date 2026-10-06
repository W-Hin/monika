import 'package:flutter/foundation.dart';
import '../connection/training_content_service.dart';
import '../model/models.dart';

/// Lessons + quiz state for whichever programme's detail screen is open
/// (employee side) or whose content HR is editing. Same ChangeNotifier
/// singleton convention as every other controller in this app.
class TrainingContentController extends ChangeNotifier {
  List<TrainingLesson> lessons = [];
  int quizQuestionCount = 0;
  int passMark = 70;
  List<QuizAttempt> attempts = []; // newest first
  bool loading = false;
  String? errorMessage;

  // HR editor only — includes correct answers.
  List<QuizQuestion> hrQuestions = [];

  bool get hasContent => lessons.isNotEmpty || quizQuestionCount > 0;
  bool get hasQuiz => quizQuestionCount > 0;
  int get lessonsDone => lessons.where((l) => l.completed).length;
  bool get allLessonsDone => lessons.isEmpty || lessonsDone == lessons.length;
  int get attemptCount => attempts.length;
  double? get bestScore => attempts.isEmpty ? null : attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);

  List<TrainingLesson> _mapLessons(
    List<Map<String, dynamic>> rows,
    Set<int> done,
  ) {
    return rows
        .map(
          (r) => TrainingLesson(
            id: r['id'] as int,
            sortOrder: r['sort_order'] as int,
            title: r['title'] as String,
            body: r['body'] as String? ?? '',
            mediaUrl: r['media_url'] as String?,
            completed: done.contains(r['id'] as int),
          ),
        )
        .toList();
  }

  /// Employee view. [enrollmentId] is null before enrolling — lessons are
  /// still listed (as an outline) but nothing is marked done.
  Future<void> load({required int programId, int? enrollmentId}) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final lessonRows = await TrainingContentService.fetchLessons(programId);
      final done = enrollmentId == null
          ? <int>{}
          : await TrainingContentService.fetchCompletedLessonIds(enrollmentId);
      lessons = _mapLessons(lessonRows, done);

      final (count, mark) = await TrainingContentService.fetchQuizInfo(
        programId,
      );
      quizQuestionCount = count;
      passMark = mark;

      attempts = enrollmentId == null
          ? []
          : (await TrainingContentService.fetchAttempts(enrollmentId)).map(QuizAttempt.fromJson).toList();
    } catch (e) {
      errorMessage = 'Could not load this programme\'s content: $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> markLessonRead(TrainingLesson lesson) async {
    errorMessage = null;
    try {
      await TrainingContentService.completeLesson(lesson.id);
      lessons = [
        for (final l in lessons)
          if (l.id == lesson.id)
            TrainingLesson(
              id: l.id,
              sortOrder: l.sortOrder,
              title: l.title,
              body: l.body,
              mediaUrl: l.mediaUrl,
              completed: true,
            )
          else
            l,
      ];
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = _friendly(e, 'Could not mark this lesson as read');
      notifyListeners();
      return false;
    }
  }

  Future<List<QuizQuestion>> fetchQuiz(int programId) async {
    final rows = await TrainingContentService.fetchQuizQuestions(programId);
    return rows
        .map(
          (r) => QuizQuestion(
            id: r['id'] as int,
            sortOrder: (r['sort_order'] as num).toInt(),
            question: r['question'] as String,
            options: List<String>.from(r['options'] as List),
          ),
        )
        .toList();
  }

  Future<QuizResult?> submitQuiz({
    required int programId,
    required List<int> answers,
  }) async {
    errorMessage = null;
    try {
      final r = await TrainingContentService.submitQuiz(
        programId: programId,
        answers: answers,
      );
      return QuizResult(
        score: (r['score'] as num).toDouble(),
        passed: r['passed'] as bool,
        correct: (r['correct'] as num).toInt(),
        total: (r['total'] as num).toInt(),
        passMark: (r['pass_mark'] as num).toInt(),
        review: (r['results'] as List)
            .map(
              (x) => QuizQuestionResult(
                correct: x['correct'] as bool,
                correctIndex: (x['correct_index'] as num).toInt(),
                explanation: x['explanation'] as String?,
              ),
            )
            .toList(),
      );
    } catch (e) {
      errorMessage = _friendly(e, 'Could not submit the quiz');
      notifyListeners();
      return null;
    }
  }

  // ── HR editor ───────────────────────────────────────────────────────────

  Future<void> loadForHr(int programId) async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      lessons = _mapLessons(
        await TrainingContentService.fetchLessons(programId),
        {},
      );
      final qRows = await TrainingContentService.fetchQuestionsForHr(programId);
      hrQuestions = qRows
          .map(
            (r) => QuizQuestion(
              id: r['id'] as int,
              sortOrder: r['sort_order'] as int,
              question: r['question'] as String,
              options: List<String>.from(r['options'] as List),
              correctIndex: r['correct_index'] as int,
              explanation: r['explanation'] as String?,
            ),
          )
          .toList();
      quizQuestionCount = hrQuestions.length;
      passMark = (await TrainingContentService.fetchQuizInfo(programId)).$2;
    } catch (e) {
      errorMessage = 'Could not load content: $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> _hrWrite(
    int programId,
    Future<void> Function() action,
    String failure,
  ) async {
    errorMessage = null;
    try {
      await action();
      await loadForHr(programId);
      return true;
    } catch (e) {
      errorMessage = '$failure: $e';
      notifyListeners();
      return false;
    }
  }

  int get _nextLessonOrder => lessons.isEmpty
      ? 1
      : lessons.map((l) => l.sortOrder).reduce((a, b) => a > b ? a : b) + 1;
  int get _nextQuestionOrder => hrQuestions.isEmpty
      ? 1
      : hrQuestions.map((q) => q.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

  Future<bool> saveLesson({
    required int programId,
    TrainingLesson? existing,
    required String title,
    required String body,
    String? mediaUrl,
  }) {
    return _hrWrite(
      programId,
      () => TrainingContentService.saveLesson(
        id: existing?.id,
        programId: programId,
        sortOrder: existing?.sortOrder ?? _nextLessonOrder,
        title: title,
        body: body,
        mediaUrl: mediaUrl,
      ),
      'Could not save lesson',
    );
  }

  Future<bool> deleteLesson(int programId, TrainingLesson lesson) => _hrWrite(
    programId,
    () => TrainingContentService.deleteLesson(lesson.id),
    'Could not delete lesson',
  );

  Future<bool> saveQuestion({
    required int programId,
    QuizQuestion? existing,
    required String question,
    required List<String> options,
    required int correctIndex,
    String? explanation,
  }) {
    return _hrWrite(
      programId,
      () => TrainingContentService.saveQuestion(
        id: existing?.id,
        programId: programId,
        sortOrder: existing?.sortOrder ?? _nextQuestionOrder,
        question: question,
        options: options,
        correctIndex: correctIndex,
        explanation: explanation,
      ),
      'Could not save question',
    );
  }

  Future<bool> deleteQuestion(int programId, QuizQuestion q) => _hrWrite(
    programId,
    () => TrainingContentService.deleteQuestion(q.id),
    'Could not delete question',
  );

  /// Swaps a lesson with its neighbour ([delta] -1 = up, +1 = down).
  Future<bool> moveLesson(int programId, TrainingLesson lesson, int delta) {
    final i = lessons.indexWhere((l) => l.id == lesson.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= lessons.length) return Future.value(false);
    final other = lessons[j];
    return _hrWrite(programId, () async {
      await TrainingContentService.setSortOrder(
        table: 'training_lessons',
        id: lesson.id,
        sortOrder: other.sortOrder,
      );
      await TrainingContentService.setSortOrder(
        table: 'training_lessons',
        id: other.id,
        sortOrder: lesson.sortOrder,
      );
    }, 'Could not reorder lessons');
  }

  Future<bool> moveQuestion(int programId, QuizQuestion q, int delta) {
    final i = hrQuestions.indexWhere((x) => x.id == q.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= hrQuestions.length) return Future.value(false);
    final other = hrQuestions[j];
    return _hrWrite(programId, () async {
      await TrainingContentService.setSortOrder(
        table: 'training_questions',
        id: q.id,
        sortOrder: other.sortOrder,
      );
      await TrainingContentService.setSortOrder(
        table: 'training_questions',
        id: other.id,
        sortOrder: q.sortOrder,
      );
    }, 'Could not reorder questions');
  }

  Future<bool> setPassMark(int programId, int mark) async {
    errorMessage = null;
    try {
      await TrainingContentService.setPassMark(
        programId: programId,
        passMark: mark,
      );
      passMark = mark;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = 'Could not save pass mark: $e';
      notifyListeners();
      return false;
    }
  }

  /// Supabase surfaces our RPC `raise exception` text inside a
  /// PostgrestException; pull just that sentence out instead of dumping the
  /// whole exception on the user.
  String _friendly(Object e, String fallback) {
    final text = e.toString();
    final m = RegExp(r'message: ([^,)]+)').firstMatch(text);
    return m != null ? m.group(1)! : fallback;
  }
}

final trainingContentController = TrainingContentController();
