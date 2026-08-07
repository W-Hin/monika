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
      items: itemsRaw.map((i) => KpiTemplateItem(name: i['name'] as String, weightage: (i['weightage'] as num).toDouble())).toList(),
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
          .map((s) => KpiItem(name: s['kpi_name'] as String, weightage: (s['weightage'] as num).toDouble(), score: (s['score'] as num).toDouble()))
          .toList(),
    );
  }

  Future<void> loadTemplates() async {
    final rows = await PeService.fetchTemplates();
    templates = rows.map(_mapTemplate).toList();
    notifyListeners();
  }

  Future<void> loadMy() async {
    loading = true;
    notifyListeners();
    final currentRow = await PeService.fetchMyCurrentYear();
    myCurrent = currentRow != null ? _mapEvaluation(currentRow) : null;
    final historyRows = await PeService.fetchMyHistory();
    myHistory = historyRows.map(_mapEvaluation).toList();
    loading = false;
    notifyListeners();
  }

  Future<void> loadForEmployee(String userUuid) async {
    loading = true;
    notifyListeners();
    final historyRows = await PeService.fetchHistoryForEmployee(userUuid);
    selectedHistory = historyRows.map(_mapEvaluation).toList();
    final currentYear = DateTime.now().year.toString();
    selectedCurrent = selectedHistory.where((e) => e.year == currentYear).isEmpty
        ? null
        : selectedHistory.firstWhere((e) => e.year == currentYear);
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
        scores: kpis.map((k) => {'kpi_name': k.name, 'weightage': k.weightage, 'score': k.score}).toList(),
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
