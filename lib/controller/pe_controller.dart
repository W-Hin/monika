import 'dart:async';
import 'package:flutter/foundation.dart';
import '../connection/employee_service.dart';
import '../connection/pe_service.dart';
import '../connection/policy_service.dart';
import '../connection/training_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class PeController extends ChangeNotifier {
  List<KpiTemplate> templates = [];
  PerformanceEvaluation? myCurrent;
  List<PerformanceEvaluation> myHistory = [];

  // HR side — keyed to whichever employee is currently selected in the
  // HR PE screen, not per-employee cached.
  PerformanceEvaluation? selectedCurrent;
  List<PerformanceEvaluation> selectedHistory = [];

  bool loading = false;
  String? errorMessage;

  KpiTemplate _mapTemplate(Map<String, dynamic> row) {
    final itemsRaw = row['kpi_template_items'] as List<dynamic>? ?? [];
    final deptName = (row['departments'] as Map<String, dynamic>?)?['name'] as String?;
    return KpiTemplate(
      dbId: row['id'] as int,
      name: row['name'] as String,
      department: deptName ?? 'All Departments',
      items: itemsRaw
          .map((i) => KpiTemplateItem(
                name: i['name'] as String,
                weightage: (i['weightage'] as num).toDouble(),
                category: i['category'] as String? ?? 'Technical',
              ))
          .toList(),
    );
  }

  PerformanceEvaluation _mapEvaluation(Map<String, dynamic> row) {
    final scoresRaw = row['performance_evaluation_scores'] as List<dynamic>? ?? [];
    return PerformanceEvaluation(
      dbId: row['id'] as int,
      userUuid: row['user_id'] as String,
      templateId: row['template_id'] as int?,
      year: (row['year'] as int).toString(),
      comments: row['comments'] as String? ?? '',
      kpis: scoresRaw
          .map((s) => KpiItem(
                name: s['kpi_name'] as String,
                weightage: (s['weightage'] as num).toDouble(),
                score: (s['score'] as num).toDouble(),
                category: s['category'] as String? ?? 'Technical',
              ))
          .toList(),
      isDraft: row['is_draft'] as bool? ?? false,
    );
  }

  Future<void> loadTemplates() async {
    try {
      final rows = await PeService.fetchTemplates();
      templates = rows.map(_mapTemplate).toList();
    } catch (e) {
      errorMessage = 'Could not load KPI templates: $e';
    }
    notifyListeners();
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing.
  Future<bool> createTemplate({
    required String name,
    required String? departmentName,
    required List<KpiTemplateItem> items,
  }) async {
    errorMessage = null;
    try {
      await PeService.createTemplate(
        name: name,
        departmentName: departmentName,
        items: items.map((i) => {'name': i.name, 'weightage': i.weightage, 'category': i.category}).toList(),
      );
      await loadTemplates();
      return true;
    } catch (e) {
      errorMessage = 'Could not create template: $e';
      notifyListeners();
      return false;
    }
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing.
  Future<bool> updateTemplate({
    required KpiTemplate existing,
    required String name,
    required String? departmentName,
    required List<KpiTemplateItem> items,
  }) async {
    errorMessage = null;
    if (existing.dbId == null) return false;
    try {
      await PeService.updateTemplate(
        id: existing.dbId!,
        name: name,
        departmentName: departmentName,
        items: items.map((i) => {'name': i.name, 'weightage': i.weightage, 'category': i.category}).toList(),
      );
      await loadTemplates();
      return true;
    } catch (e) {
      errorMessage = 'Could not update template: $e';
      notifyListeners();
      return false;
    }
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing.
  Future<bool> deleteTemplate(KpiTemplate template) async {
    errorMessage = null;
    if (template.dbId == null) return false;
    try {
      await PeService.deleteTemplate(template.dbId!);
      await loadTemplates();
      return true;
    } catch (e) {
      errorMessage = 'Could not delete template: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadMy() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final currentRow = await PeService.fetchMyCurrentYear();
      myCurrent = currentRow != null ? _mapEvaluation(currentRow) : null;
      final historyRows = await PeService.fetchMyHistory();
      myHistory = historyRows.map(_mapEvaluation).toList();
    } catch (e) {
      errorMessage = 'Could not load your evaluations: $e';
    }
    loading = false;
    notifyListeners();
  }

  // Tracks which employee's data is currently being requested, so that if
  // the HR admin taps a different employee before an in-flight request
  // resolves, the stale (superseded) response is discarded instead of
  // overwriting the newer selection — otherwise a fast double-tap could
  // silently leave the wrong employee's (or an empty) history displayed.
  String? _pendingUuid;

  Future<void> loadForEmployee(String userUuid) async {
    _pendingUuid = userUuid;
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final historyRows = await PeService.fetchHistoryForEmployee(userUuid);
      if (_pendingUuid != userUuid) return;
      selectedHistory = historyRows.map(_mapEvaluation).toList();
      final currentYear = DateTime.now().year.toString();
      selectedCurrent = selectedHistory.where((e) => e.year == currentYear).isEmpty
          ? null
          : selectedHistory.firstWhere((e) => e.year == currentYear);
    } catch (e) {
      if (_pendingUuid != userUuid) return;
      errorMessage = 'Could not load this employee\'s evaluations: $e';
    }
    loading = false;
    notifyListeners();
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing.
  Future<bool> submit({
    required String userUuid,
    required int? templateId,
    required List<KpiItem> kpis,
    required String comments,
  }) async {
    errorMessage = null;
    var weightedTotal = 0.0;
    for (final k in kpis) {
      weightedTotal += k.score * k.weightage / 100;
    }
    try {
      await PeService.submitEvaluation(
        userUuid: userUuid,
        templateId: templateId,
        year: DateTime.now().year,
        comments: comments,
        weightedTotal: weightedTotal,
        scores: kpis.map((k) => {'kpi_name': k.name, 'weightage': k.weightage, 'score': k.score, 'category': k.category}).toList(),
        isDraft: false,
      );
      await loadForEmployee(userUuid);
      unawaited(_triggerTrainingRecommendations(userUuid: userUuid, kpis: kpis));
      return true;
    } catch (e) {
      errorMessage = 'Could not submit evaluation: $e';
      notifyListeners();
      return false;
    }
  }

  /// FR10.6 — saves in-progress scoring without it counting as a real
  /// evaluation: doesn't trigger training recommendations (those are tied
  /// to a genuine, finished PE result) and stays invisible on the
  /// employee's own PE screen (PeService.fetchMyCurrentYear/fetchMyHistory
  /// both filter is_draft out) until HR actually submits.
  Future<bool> saveDraft({
    required String userUuid,
    required int? templateId,
    required List<KpiItem> kpis,
    required String comments,
  }) async {
    errorMessage = null;
    var weightedTotal = 0.0;
    for (final k in kpis) {
      weightedTotal += k.score * k.weightage / 100;
    }
    try {
      await PeService.submitEvaluation(
        userUuid: userUuid,
        templateId: templateId,
        year: DateTime.now().year,
        comments: comments,
        weightedTotal: weightedTotal,
        scores: kpis.map((k) => {'kpi_name': k.name, 'weightage': k.weightage, 'score': k.score, 'category': k.category}).toList(),
        isDraft: true,
      );
      await loadForEmployee(userUuid);
      return true;
    } catch (e) {
      errorMessage = 'Could not save draft: $e';
      notifyListeners();
      return false;
    }
  }

  /// FR10.6 — discards a draft outright, leaving no evaluation record for
  /// this employee/year behind. Only ever called on a draft (see
  /// PeService.deleteEvaluation's own doc comment).
  Future<bool> discardDraft(PerformanceEvaluation draft) async {
    if (draft.dbId == null) return false;
    errorMessage = null;
    try {
      await PeService.deleteEvaluation(draft.dbId!);
      if (draft.userUuid != null) await loadForEmployee(draft.userUuid!);
      return true;
    } catch (e) {
      errorMessage = 'Could not discard draft: $e';
      notifyListeners();
      return false;
    }
  }

  static const _categoryToDb = {'Technical': 'technical', 'Behavioural': 'behavioural', 'Leadership': 'leadership'};

  int _monthsEmployed(DateTime hireDate) {
    final now = DateTime.now();
    var months = (now.year - hireDate.year) * 12 + (now.month - hireDate.month);
    if (now.day < hireDate.day) months--;
    return months;
  }

  /// Rule-based (per this project's scope, not a real ML model): any KPI
  /// scored below its category's threshold (from Policy Config) auto-
  /// enrols the employee in a matching training programme, if one exists.
  /// Best-effort — a failure here shouldn't undo an already-saved
  /// evaluation, so errors are swallowed rather than surfaced.
  Future<void> _triggerTrainingRecommendations({required String userUuid, required List<KpiItem> kpis}) async {
    try {
      final policy = await PolicyService.fetch();
      final minTenureMonths = policy['min_tenure_months'] as int;
      if (minTenureMonths > 0) {
        final profile = await EmployeeService.fetchOne(userUuid);
        final hireDate = DateTime.tryParse(profile?['hire_date'] as String? ?? '');
        if (hireDate != null && _monthsEmployed(hireDate) < minTenureMonths) return;
      }
      final thresholds = {
        'Technical': (policy['technical_threshold'] as num).toDouble(),
        'Behavioural': (policy['behavioural_threshold'] as num).toDouble(),
        'Leadership': (policy['leadership_threshold'] as num).toDouble(),
      };
      for (final k in kpis) {
        final threshold = thresholds[k.category];
        final dbCategory = _categoryToDb[k.category];
        if (threshold == null || dbCategory == null) continue;
        if (k.score >= threshold) continue;
        await TrainingService.recommendForCategory(
          userUuid: userUuid,
          category: dbCategory,
          reason: 'Recommended after scoring ${k.score.toInt()}/100 on "${k.name}" (${k.category}) in this year\'s Performance Evaluation.',
        );
      }
    } catch (_) {
      // Best-effort, see doc comment.
    }
  }
}

final peController = PeController();
