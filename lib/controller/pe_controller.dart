import 'package:flutter/foundation.dart';
import '../connection/pe_service.dart';
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
    );
  }

  Future<void> loadTemplates() async {
    final rows = await PeService.fetchTemplates();
    templates = rows.map(_mapTemplate).toList();
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
      errorMessage = e.toString().contains('kpi_templates_department_unique')
          ? 'A KPI Template already exists for ${departmentName ?? 'All Departments'}. Delete it first if you want to replace it.'
          : 'Could not create template: $e';
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
      );
      await loadForEmployee(userUuid);
      return true;
    } catch (e) {
      errorMessage = 'Could not submit evaluation: $e';
      notifyListeners();
      return false;
    }
  }
}

final peController = PeController();
