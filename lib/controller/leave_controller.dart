import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../connection/leave_service.dart';
import '../model/models.dart';
import 'analytics_controller.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class LeaveController extends ChangeNotifier {
  LeaveBalance? myBalance;
  List<LeaveApplication> myApplications = [];
  List<LeaveApplication> allApplications = []; // HR
  List<LeaveBalance> allBalances = []; // HR

  // Deliberately separate loading/error state per operation rather than one
  // shared pair — an HR admin's own EmployeeShell tabs (loadMy) and HrShell
  // tabs (loadAllForHr/loadAllBalancesForHr) can be mounted *simultaneously*
  // ("Switch to Admin/Employee View" pushes one shell on top of the other
  // rather than replacing it, by design — see hr_approvals.dart's comment).
  // With one shared `loading`/`errorMessage`, a concurrent loadMy() call
  // could flip `loading` back to false or set a stale `errorMessage` while
  // loadAllForHr()'s own fetch was still in flight, which is exactly what
  // made the Approvals list intermittently stay empty after switching views
  // even though the underlying query had succeeded.
  bool loadingMy = false;
  String? myErrorMessage;
  bool loadingApprovals = false;
  String? approvalsErrorMessage;
  bool loadingBalances = false;
  String? balancesErrorMessage;

  static const _typeToDb = {
    'Annual Leave': 'annual',
    'Medical Leave': 'medical',
    'Emergency Leave': 'emergency',
    'Unpaid Leave': 'unpaid',
  };
  static const _typeToDisplay = {
    'annual': 'Annual Leave',
    'medical': 'Medical Leave',
    'emergency': 'Emergency Leave',
    'unpaid': 'Unpaid Leave',
  };

  static final _dateFormat = DateFormat('d MMM yyyy');

  LeaveBalance _mapBalance(Map<String, dynamic> row, {String? employeeNameOverride}) {
    final profile = row['profiles'] as Map<String, dynamic>?;
    final joinedName = profile?['name'] as String?;
    final joinedDept = (profile?['departments'] as Map<String, dynamic>?)?['name'] as String?;
    return LeaveBalance(
      userUuid: row['user_id'] as String,
      employeeName: employeeNameOverride ?? joinedName ?? '',
      department: joinedDept ?? 'Unassigned',
      annualTotal: row['annual_total'] as int,
      annualUsed: row['annual_used'] as int,
      medicalTotal: row['medical_total'] as int,
      medicalUsed: row['medical_used'] as int,
      emergencyTotal: row['emergency_total'] as int,
      emergencyUsed: row['emergency_used'] as int,
    );
  }

  LeaveApplication _mapApplication(Map<String, dynamic> row) {
    final joinedName = (row['profiles'] as Map<String, dynamic>?)?['name'] as String?;
    final status = LeaveStatus.values.firstWhere(
      (s) => s.name == row['status'],
      orElse: () => LeaveStatus.pending,
    );
    return LeaveApplication(
      dbId: row['id'] as int,
      userUuid: row['user_id'] as String,
      id: row['reference_code'] as String,
      employeeName: joinedName ?? '',
      leaveType: _typeToDisplay[row['leave_type']] ?? row['leave_type'] as String,
      startDate: _dateFormat.format(DateTime.parse(row['start_date'] as String)),
      endDate: _dateFormat.format(DateTime.parse(row['end_date'] as String)),
      days: row['days'] as int,
      reason: row['reason'] as String,
      status: status,
    );
  }

  Future<void> loadMy() async {
    loadingMy = true;
    myErrorMessage = null;
    notifyListeners();
    try {
      final balanceRow = await LeaveService.fetchMyBalance();
      myBalance = balanceRow != null ? _mapBalance(balanceRow) : null;
      final appRows = await LeaveService.fetchMyApplications();
      myApplications = appRows.map(_mapApplication).toList();
    } catch (e) {
      myErrorMessage = 'Could not load your leave data: $e';
    }
    loadingMy = false;
    notifyListeners();
  }

  /// Returns true on success. On failure, sets myErrorMessage for the
  /// caller to surface and returns false.
  Future<bool> submit({
    required String displayLeaveType,
    required DateTime startDate,
    required DateTime endDate,
    required String reason,
  }) async {
    myErrorMessage = null;
    final days = endDate.difference(startDate).inDays + 1;
    try {
      await LeaveService.submitApplication(
        leaveType: _typeToDb[displayLeaveType] ?? 'annual',
        startDate: startDate,
        endDate: endDate,
        days: days,
        reason: reason,
      );
      await loadMy();
      return true;
    } catch (e) {
      myErrorMessage = 'Could not submit application: $e';
      notifyListeners();
      return false;
    }
  }

  /// Returns true on success. On failure, sets myErrorMessage.
  Future<bool> cancel(LeaveApplication app) async {
    myErrorMessage = null;
    if (app.dbId == null) return false;
    try {
      await LeaveService.cancelApplication(app.dbId!);
      await loadMy();
      unawaited(analyticsController.refreshPendingLeaveCount());
      return true;
    } catch (e) {
      myErrorMessage = 'Could not cancel the application: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> loadAllForHr() async {
    loadingApprovals = true;
    approvalsErrorMessage = null;
    notifyListeners();
    try {
      final rows = await LeaveService.fetchAllApplications();
      allApplications = rows.map(_mapApplication).toList();
    } catch (e) {
      approvalsErrorMessage = 'Could not load leave applications: $e';
    }
    loadingApprovals = false;
    notifyListeners();
  }

  /// Throws on failure (e.g. the self-decision DB trigger rejecting an
  /// HR admin trying to approve their own application) — caller shows
  /// the error.
  Future<void> decide({required LeaveApplication app, required bool approve}) async {
    await LeaveService.decide(applicationId: app.dbId!, approve: approve);
    if (approve) {
      final dbType = _typeToDb[app.leaveType] ?? 'annual';
      await LeaveService.incrementUsedDays(userUuid: app.userUuid!, leaveType: dbType, days: app.days);
    }
    await loadAllForHr();
    unawaited(analyticsController.refreshPendingLeaveCount());
  }

  Future<void> loadAllBalancesForHr() async {
    loadingBalances = true;
    balancesErrorMessage = null;
    notifyListeners();
    try {
      final rows = await LeaveService.fetchAllBalances();
      allBalances = rows.map(_mapBalance).toList();
    } catch (e) {
      balancesErrorMessage = 'Could not load leave balances: $e';
    }
    loadingBalances = false;
    notifyListeners();
  }

  Future<void> updateEntitlement({
    required LeaveBalance balance,
    required int annualTotal,
    required int medicalTotal,
    required int emergencyTotal,
  }) async {
    await LeaveService.updateEntitlement(
      userUuid: balance.userUuid!,
      annualTotal: annualTotal,
      medicalTotal: medicalTotal,
      emergencyTotal: emergencyTotal,
    );
    await loadAllBalancesForHr();
  }
}

final leaveController = LeaveController();
