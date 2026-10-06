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

  /// Mandatory for this employee: a mandatory programme meant for their
  /// department (or everyone) that HR hasn't exempted them from (FR9.6).
  static bool isMandatoryFor({
    required bool programMandatory,
    required int? programDepartmentId,
    required int? myDepartmentId,
    required bool exempt,
  }) =>
      programMandatory && !exempt && (programDepartmentId == null || programDepartmentId == myDepartmentId);

  /// FR9.5 — only an optional programme the employee hasn't started yet
  /// (no progress, no lesson read, no quiz attempt). The server checks the
  /// same rules again.
  static bool canWithdraw(TrainingProgram p, {required int lessonsRead, required int attempts}) =>
      p.dbId != null &&
      p.enrollmentId != null &&
      !p.isCompleted &&
      !p.isMandatory &&
      p.progress == 0 &&
      lessonsRead == 0 &&
      attempts == 0;

  TrainingProgram _mergeMy(Map<String, dynamic> program, Map<String, dynamic>? enrollment, int tenureMonths, bool mandatoryForMe) {
    final minTenure = (program['min_tenure_months'] as num?)?.toInt() ?? 0;
    final deptName = (program['departments'] as Map<String, dynamic>?)?['name'] as String?;
    return TrainingProgram(
      dbId: program['id'] as int,
      enrollmentId: enrollment?['id'] as int?,
      title: program['title'] as String,
      category: _categoryToDisplay[program['category']] ?? program['category'] as String,
      description: program['description'] as String,
      isMandatory: mandatoryForMe,
      isRecommended: enrollment?['is_recommended'] as bool? ?? false,
      recommendationReason: enrollment?['recommendation_reason'] as String?,
      progress: enrollment != null ? (enrollment['progress'] as num).toDouble() : 0,
      duration: program['duration'] as String,
      isCompleted: enrollment?['is_completed'] as bool? ?? false,
      performanceScore: (enrollment?['performance_score'] as num?)?.toDouble(),
      department: deptName,
      access: program['access'] as String? ?? 'open',
      minTenureMonths: minTenure,
      triggerRiskLevel: program['trigger_risk_level'] as String?,
      triggerAttendanceBelow: (program['trigger_attendance_below'] as num?)?.toDouble(),
      locked: enrollment == null && tenureMonths < minTenure,
    );
  }

  Future<void> loadMy() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      // Evaluate attendance/risk rules first so a newly-triggered remedial
      // programme shows up in this very load. Best-effort: a failure here
      // must not hide the catalogue.
      try {
        await TrainingService.refreshMyRecommendations();
      } catch (_) {}
      final catalogRows = await TrainingService.fetchCatalog();
      final enrollmentRows = await TrainingService.fetchMyEnrollments();
      final me = await TrainingService.fetchMyContext();
      final exempt = await TrainingService.fetchMyExemptProgramIds(me.departmentId);
      final enrollByProgram = {for (final e in enrollmentRows) e['program_id'] as int: e};
      // Recommendation-only programmes stay out of the catalogue unless the
      // employee has actually been enrolled in one.
      myPrograms = catalogRows
          .where((p) => (p['access'] ?? 'open') != 'recommended_only' || enrollByProgram.containsKey(p['id'] as int))
          .map((p) => _mergeMy(
                p,
                enrollByProgram[p['id'] as int],
                me.tenureMonths,
                isMandatoryFor(
                  programMandatory: p['is_mandatory'] as bool,
                  programDepartmentId: p['department_id'] as int?,
                  myDepartmentId: me.departmentId,
                  exempt: exempt.contains(p['id'] as int),
                ),
              ))
          .toList();
    } catch (e) {
      errorMessage = 'Could not load training programmes: $e';
    }
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

  /// Returns true on success. On failure, sets errorMessage to the
  /// server's reason (e.g. the programme was already started).
  Future<bool> withdraw(TrainingProgram program) async {
    errorMessage = null;
    if (program.dbId == null) return false;
    try {
      await TrainingService.withdraw(program.dbId!);
      await loadMy();
      return true;
    } catch (e) {
      final m = RegExp(r'message: ([^,)]+)').firstMatch(e.toString());
      errorMessage = m?.group(1) ?? 'Could not withdraw: $e';
      notifyListeners();
      return false;
    }
  }

  // ── HR: exemptions from mandatory programmes (FR9.6) ──────────────────
  Future<List<TrainingExemption>> loadExemptions(TrainingProgram program) async {
    if (program.dbId == null) return [];
    final rows = await TrainingService.fetchExemptions(program.dbId!);
    return rows.map(TrainingExemption.fromJson).toList();
  }

  /// Exactly one of [userUuid] / [departmentName]. Returns true on success.
  Future<bool> addExemption(TrainingProgram program, {String? userUuid, String? departmentName}) async {
    errorMessage = null;
    try {
      final deptId = departmentName == null ? null : await TrainingService.departmentIdForName(departmentName);
      await TrainingService.addExemption(programId: program.dbId!, userUuid: userUuid, departmentId: deptId);
      return true;
    } catch (e) {
      errorMessage = e.toString().contains('duplicate')
          ? 'Already exempted.'
          : 'Could not add the exemption: $e';
      return false;
    }
  }

  Future<bool> removeExemption(TrainingExemption exemption) async {
    errorMessage = null;
    try {
      await TrainingService.removeExemption(exemption.id);
      return true;
    } catch (e) {
      errorMessage = 'Could not remove the exemption: $e';
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
    errorMessage = null;
    notifyListeners();
    try {
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
          access: p['access'] as String? ?? 'open',
          minTenureMonths: (p['min_tenure_months'] as num?)?.toInt() ?? 0,
          triggerRiskLevel: p['trigger_risk_level'] as String?,
          triggerAttendanceBelow: (p['trigger_attendance_below'] as num?)?.toDouble(),
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
    } catch (e) {
      errorMessage = 'Could not load training data: $e';
    }

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
    String access = 'open',
    int minTenureMonths = 0,
    String? triggerRiskLevel,
    double? triggerAttendanceBelow,
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
          access: access,
          minTenureMonths: minTenureMonths,
          triggerRiskLevel: triggerRiskLevel,
          triggerAttendanceBelow: triggerAttendanceBelow,
        );
      } else {
        await TrainingService.updateProgram(
          id: existingId,
          title: title,
          category: _categoryToDb[category] ?? 'technical',
          description: description,
          isMandatory: isMandatory,
          duration: duration,
          access: access,
          minTenureMonths: minTenureMonths,
          triggerRiskLevel: triggerRiskLevel,
          triggerAttendanceBelow: triggerAttendanceBelow,
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

  Future<bool> deleteProgram(TrainingProgram program) async {
    errorMessage = null;
    if (program.dbId == null) return false;
    try {
      await TrainingService.deleteProgram(program.dbId!);
      await loadForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not delete training programme: $e';
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
