import 'package:flutter/foundation.dart';
import '../connection/training_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class TrainingController extends ChangeNotifier {
  /// Employee side — the full catalog merged with the current user's own
  /// enrollment (if any), one entry per program. The screen itself
  /// derives its Recommended/Mandatory/All/Completed tabs from this via
  /// simple `.where()` filters, same as it did with the old dummy lists.
  List<TrainingProgram> myPrograms = [];

  /// HR side — the catalog with real enrolled-employee counts.
  List<TrainingProgram> hrPrograms = [];

  /// HR side — every employee's enrollment, for the Completion tab.
  List<TrainingCompletionRecord> completionRecords = [];

  bool loading = false;
  String? errorMessage;

  double get overallCompletionRate {
    if (completionRecords.isEmpty) return 0;
    final completed = completionRecords.where((r) => r.progress >= 1.0).length;
    return completed / completionRecords.length;
  }

  static const _categoryToDisplay = {
    'technical': 'Technical',
    'behavioural': 'Behavioural',
    'leadership': 'Leadership',
  };
  static const _categoryToDb = {
    'Technical': 'technical',
    'Behavioural': 'behavioural',
    'Leadership': 'leadership',
  };

  TrainingProgram _mergeMy(Map<String, dynamic> program, Map<String, dynamic>? enrollment) {
    final deptName = (program['departments'] as Map<String, dynamic>?)?['name'] as String?;
    return TrainingProgram(
      dbId: program['id'] as int,
      enrollmentId: enrollment?['id'] as int?,
      title: program['title'] as String,
      category: _categoryToDisplay[program['category']] ?? program['category'] as String,
      description: program['description'] as String,
      isMandatory: program['is_mandatory'] as bool,
      isRecommended: enrollment?['is_recommended'] as bool? ?? false,
      recommendationReason: enrollment?['recommendation_reason'] as String?,
      progress: enrollment != null ? (enrollment['progress'] as num).toDouble() : 0,
      duration: program['duration'] as String,
      isCompleted: enrollment?['is_completed'] as bool? ?? false,
      performanceScore: (enrollment?['performance_score'] as num?)?.toDouble(),
      department: deptName,
    );
  }

  Future<void> loadMy() async {
    loading = true;
    notifyListeners();
    final catalogRows = await TrainingService.fetchCatalog();
    final enrollmentRows = await TrainingService.fetchMyEnrollments();
    final enrollByProgram = {for (final e in enrollmentRows) e['program_id'] as int: e};
    myPrograms = catalogRows.map((p) => _mergeMy(p, enrollByProgram[p['id'] as int])).toList();
    loading = false;
    notifyListeners();
  }

  Future<bool> enroll(TrainingProgram program) async {
    errorMessage = null;
    if (program.dbId == null) return false;
    try {
      await TrainingService.enroll(program.dbId!);
      await loadMy();
      return true;
    } catch (e) {
      errorMessage = 'Could not enrol: $e';
      notifyListeners();
      return false;
    }
  }

  /// Progress here is still a simulated "tap to advance" mechanic, same
  /// as the dummy version — there's no actual training content/module
  /// system to consume. What's real now is that it's a genuine database
  /// row, not local widget state that resets on navigation.
  Future<bool> continueTraining(TrainingProgram program) async {
    errorMessage = null;
    if (program.enrollmentId == null) return false;
    try {
      final next = (program.progress + 0.3).clamp(0.0, 1.0);
      final completed = next >= 1.0;
      await TrainingService.updateProgress(enrollmentId: program.enrollmentId!, progress: next, completed: completed);
      await loadMy();
      return true;
    } catch (e) {
      errorMessage = 'Could not update progress: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadForHr() async {
    loading = true;
    notifyListeners();
    final catalogRows = await TrainingService.fetchCatalog();
    final allEnrollRows = await TrainingService.fetchAllEnrollments();

    final countByProgram = <int, int>{};
    for (final e in allEnrollRows) {
      final pid = e['program_id'] as int;
      countByProgram[pid] = (countByProgram[pid] ?? 0) + 1;
    }

    hrPrograms = catalogRows.map((p) {
      final deptName = (p['departments'] as Map<String, dynamic>?)?['name'] as String?;
      final id = p['id'] as int;
      return TrainingProgram(
        dbId: id,
        enrolledCount: countByProgram[id] ?? 0,
        title: p['title'] as String,
        category: _categoryToDisplay[p['category']] ?? p['category'] as String,
        description: p['description'] as String,
        isMandatory: p['is_mandatory'] as bool,
        duration: p['duration'] as String,
        department: deptName,
      );
    }).toList();

    completionRecords = allEnrollRows.map((e) {
      final profile = e['profiles'] as Map<String, dynamic>?;
      final program = e['training_programs'] as Map<String, dynamic>?;
      return TrainingCompletionRecord(
        enrollmentId: e['id'] as int,
        employeeName: profile?['name'] as String? ?? '',
        department: '',
        programTitle: program?['title'] as String? ?? '',
        progress: (e['progress'] as num).toDouble(),
        performanceScore: (e['performance_score'] as num?)?.toDouble(),
      );
    }).toList();

    loading = false;
    notifyListeners();
  }

  Future<bool> saveProgram({
    int? existingId,
    required String title,
    required String category,
    required String description,
    required bool isMandatory,
    required String duration,
    String? departmentName,
  }) async {
    errorMessage = null;
    try {
      if (existingId == null) {
        final deptId = await TrainingService.departmentIdForName(departmentName);
        await TrainingService.createProgram(
          title: title,
          category: _categoryToDb[category] ?? 'technical',
          description: description,
          isMandatory: isMandatory,
          duration: duration,
          departmentId: deptId,
        );
      } else {
        await TrainingService.updateProgram(
          id: existingId,
          title: title,
          category: _categoryToDb[category] ?? 'technical',
          description: description,
          isMandatory: isMandatory,
          duration: duration,
        );
      }
      await loadForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not save training programme: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignDepartment(TrainingProgram program, String departmentName) async {
    errorMessage = null;
    if (program.dbId == null) return false;
    try {
      final deptId = await TrainingService.departmentIdForName(departmentName);
      await TrainingService.assignDepartment(programId: program.dbId!, departmentId: deptId);
      await loadForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not assign department: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> setScore(TrainingCompletionRecord record, double score) async {
    errorMessage = null;
    if (record.enrollmentId == null) return false;
    try {
      await TrainingService.setPerformanceScore(enrollmentId: record.enrollmentId!, score: score);
      await loadForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not save score: $e';
      notifyListeners();
      return false;
    }
  }
}

final trainingController = TrainingController();
