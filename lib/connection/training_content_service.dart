import 'package:supabase_flutter/supabase_flutter.dart';

/// Lessons and quizzes for a training programme. Employees never read
/// `training_questions` directly (it holds the answers, HR-only by RLS) —
/// they go through [fetchQuizQuestions] / [submitQuiz], which grade
/// server-side.
class TrainingContentService {
  TrainingContentService._();
  static final _client = Supabase.instance.client;

  // ── Employee ────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchLessons(int programId) async {
    final rows = await _client
        .from('training_lessons')
        .select()
        .eq('program_id', programId)
        .order('sort_order')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Set<int>> fetchCompletedLessonIds(int enrollmentId) async {
    final rows = await _client
        .from('training_lesson_completions')
        .select('lesson_id')
        .eq('enrollment_id', enrollmentId);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map((r) => r['lesson_id'] as int).toSet();
  }

  /// (questionCount, passMark) — safe for anyone to read.
  static Future<(int, int)> fetchQuizInfo(int programId) async {
    final rows = await _client.rpc(
      'training_quiz_info',
      params: {'p_program_id': programId},
    );
    final list = List<Map<String, dynamic>>.from(rows as List);
    if (list.isEmpty) return (0, 70);
    return (
      (list.first['question_count'] as num?)?.toInt() ?? 0,
      (list.first['pass_mark'] as num?)?.toInt() ?? 70,
    );
  }

  static Future<List<Map<String, dynamic>>> fetchQuizQuestions(
    int programId,
  ) async {
    final rows = await _client.rpc(
      'get_quiz_questions',
      params: {'p_program_id': programId},
    );
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<Map<String, dynamic>> submitQuiz({
    required int programId,
    required List<int> answers,
  }) async {
    final result = await _client.rpc(
      'submit_training_quiz',
      params: {'p_program_id': programId, 'p_answers': answers},
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static Future<void> completeLesson(int lessonId) async {
    await _client.rpc(
      'complete_training_lesson',
      params: {'p_lesson_id': lessonId},
    );
  }

  /// This employee's own attempts for an enrollment, newest first.
  static Future<List<Map<String, dynamic>>> fetchAttempts(
    int enrollmentId,
  ) async {
    final rows = await _client
        .from('training_attempts')
        .select()
        .eq('enrollment_id', enrollmentId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  // ── HR editor ───────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> fetchQuestionsForHr(
    int programId,
  ) async {
    final rows = await _client
        .from('training_questions')
        .select()
        .eq('program_id', programId)
        .order('sort_order')
        .order('id');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> saveLesson({
    int? id,
    required int programId,
    required int sortOrder,
    required String title,
    required String body,
    String? mediaUrl,
  }) async {
    final values = {'title': title, 'body': body, 'media_url': mediaUrl};
    if (id == null) {
      await _client.from('training_lessons').insert({
        ...values,
        'program_id': programId,
        'sort_order': sortOrder,
      });
    } else {
      await _client.from('training_lessons').update(values).eq('id', id);
    }
  }

  static Future<void> deleteLesson(int id) async {
    await _client.from('training_lessons').delete().eq('id', id);
  }

  static Future<void> saveQuestion({
    int? id,
    required int programId,
    required int sortOrder,
    required String question,
    required List<String> options,
    required int correctIndex,
    String? explanation,
  }) async {
    final values = {
      'question': question,
      'options': options,
      'correct_index': correctIndex,
      'explanation': explanation,
    };
    if (id == null) {
      await _client.from('training_questions').insert({
        ...values,
        'program_id': programId,
        'sort_order': sortOrder,
      });
    } else {
      await _client.from('training_questions').update(values).eq('id', id);
    }
  }

  static Future<void> deleteQuestion(int id) async {
    await _client.from('training_questions').delete().eq('id', id);
  }

  static Future<void> setSortOrder({
    required String table,
    required int id,
    required int sortOrder,
  }) async {
    await _client.from(table).update({'sort_order': sortOrder}).eq('id', id);
  }

  static Future<void> setPassMark({
    required int programId,
    required int passMark,
  }) async {
    await _client
        .from('training_programs')
        .update({'pass_mark': passMark})
        .eq('id', programId);
  }
}
