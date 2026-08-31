import 'package:flutter/foundation.dart';
import '../connection/device_request_service.dart';
import '../connection/employee_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class DeviceRequestController extends ChangeNotifier {
  List<DeviceChangeRequest> allRequests = []; // HR
  DeviceChangeRequest? myPendingRequest; // employee — their own pending request, if any
  // FR6.7 — set when their most recently cancelled request is still within
  // the 24h cooldown, so they can't immediately request → cancel → request
  // again. Null once the cooldown has elapsed.
  DateTime? myCooldownUntil;
  bool loading = false;
  bool submitting = false;
  String? errorMessage;

  bool get myPending => myPendingRequest != null;

  static const cooldownDuration = Duration(hours: 24);

  Future<void> loadMyPending() async {
    try {
      final rows = await DeviceRequestService.fetchMyRecent();
      final pendingRow = rows.where((r) => r['status'] == 'pending').toList();
      myPendingRequest = pendingRow.isEmpty ? null : _mapRow(pendingRow.first);

      // Rows are already newest-first, so the first 'cancelled' one found
      // is the most recent cancellation.
      final cancelledRows = rows.where((r) => r['status'] == 'cancelled').toList();
      if (cancelledRows.isNotEmpty) {
        final cancelledAt = DateTime.parse(cancelledRows.first['decided_at'] as String).toLocal();
        final cooldownEnd = cancelledAt.add(cooldownDuration);
        myCooldownUntil = cooldownEnd.isAfter(DateTime.now()) ? cooldownEnd : null;
      } else {
        myCooldownUntil = null;
      }
      notifyListeners();
    } catch (_) {
      // Best-effort — worst case the button just doesn't show the right
      // state until the next successful check.
    }
  }

  DeviceChangeRequest _mapRow(Map<String, dynamic> row) {
    final joinedName = (row['profiles'] as Map<String, dynamic>?)?['name'] as String?;
    return DeviceChangeRequest(
      id: row['id'] as int,
      userUuid: row['user_id'] as String,
      employeeName: joinedName ?? '',
      reason: row['reason'] as String,
      status: row['status'] as String,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<void> loadAllForHr() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final rows = await DeviceRequestService.fetchAllForHr();
      allRequests = rows.map(_mapRow).toList();
    } catch (e) {
      errorMessage = 'Could not load device change requests: $e';
    }
    loading = false;
    notifyListeners();
  }

  /// Returns true on success. On failure, sets errorMessage and returns
  /// false rather than throwing.
  Future<bool> submit(String reason) async {
    errorMessage = null;
    submitting = true;
    notifyListeners();
    try {
      await DeviceRequestService.submit(reason);
      submitting = false;
      // Re-fetches so myPendingRequest carries the real id (needed to
      // cancel it later), rather than a locally-guessed placeholder.
      await loadMyPending();
      return true;
    } catch (e) {
      submitting = false;
      errorMessage = 'Could not submit request: $e';
      notifyListeners();
      return false;
    }
  }

  /// FR6.7 — the employee withdrawing their own pending request. Starts
  /// the 24h cooldown (loadMyPending() re-derives it from the fresh
  /// 'cancelled' row this leaves behind).
  Future<bool> cancelMine() async {
    final request = myPendingRequest;
    if (request == null) return false;
    errorMessage = null;
    try {
      await DeviceRequestService.cancel(request.id);
      await loadMyPending();
      return true;
    } catch (e) {
      errorMessage = 'Could not cancel request: $e';
      notifyListeners();
      return false;
    }
  }

  /// HR withdrawing someone else's pending request (FR6.7 also allows
  /// this) — distinct from decide()'s approve/reject.
  Future<bool> cancelForHr(DeviceChangeRequest request) async {
    errorMessage = null;
    try {
      await DeviceRequestService.cancel(request.id);
      await loadAllForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not cancel this request: $e';
      notifyListeners();
      return false;
    }
  }

  /// Approving unpairs the employee's current device (same fields
  /// employee_detail.dart's "Reset device binding" action clears) so their
  /// next successful clock-in registers the new one.
  Future<bool> decide({required DeviceChangeRequest request, required bool approve}) async {
    errorMessage = null;
    try {
      await DeviceRequestService.decide(requestId: request.id, approve: approve);
      if (approve) {
        await EmployeeService.resetDeviceBinding(request.userUuid);
      }
      await loadAllForHr();
      return true;
    } catch (e) {
      errorMessage = 'Could not update this request: $e';
      notifyListeners();
      return false;
    }
  }
}

final deviceRequestController = DeviceRequestController();
