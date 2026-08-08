import 'package:flutter/foundation.dart';
import '../connection/device_request_service.dart';
import '../connection/employee_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class DeviceRequestController extends ChangeNotifier {
  List<DeviceChangeRequest> allRequests = []; // HR
  bool loading = false;
  bool submitting = false;
  String? errorMessage;

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
      notifyListeners();
      return true;
    } catch (e) {
      submitting = false;
      errorMessage = 'Could not submit request: $e';
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
