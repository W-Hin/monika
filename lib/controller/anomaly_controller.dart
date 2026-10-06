import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../connection/anomaly_service.dart';
import '../model/models.dart';

/// HR-facing anomaly feed state. There is no employee-facing equivalent —
/// employees see their own flags inline on attendance history/flag_reason
/// (wired as part of the Attendance module), not through this table.
class AnomalyController extends ChangeNotifier {
  List<AnomalyEvent> feed = [];
  bool loading = false;
  String? errorMessage;

  Future<void> loadFeed() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final rows = await AnomalyService.fetchFeed();
      feed = rows.map(_mapEvent).toList();
    } catch (e) {
      errorMessage = 'Could not load anomaly feed: $e';
    }
    loading = false;
    notifyListeners();
  }

  AnomalyEvent _mapEvent(Map<String, dynamic> row) {
    final severity = RiskLevel.values.firstWhere(
      (s) => s.name == row['severity'],
      orElse: () => RiskLevel.low,
    );
    final name = (row['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
    final eventDate = DateTime.parse(row['event_date'] as String);
    return AnomalyEvent(
      id: row['id'] as int,
      employeeName: name,
      type: _displayType(row['type'] as String),
      date: DateFormat('EEE, d MMM').format(eventDate),
      details: row['details'] as String,
      severity: severity,
      reviewed: row['reviewed'] as bool? ?? false,
      attendanceRecordId: row['attendance_record_id'] as int?,
      reverted: row['reverted_at'] != null,
      isAbsence: row['type'] == 'unexplained_absence',
      eventDate: eventDate,
      appealReason: row['appeal_reason'] as String?,
      appealStatus: row['appeal_status'] as String?,
      appealedAt: DateTime.tryParse(row['appealed_at'] as String? ?? '')?.toLocal(),
    );
  }

  String _displayType(String dbType) {
    switch (dbType) {
      case 'out_of_zone':
        return 'Out-of-zone clock-in';
      case 'shared_device':
        return 'Shared-device violation';
      case 'wifi_mismatch':
        return 'WiFi SSID mismatch';
      case 'late':
        return 'Repeated late arrival';
      case 'early_clockout':
        return 'Early clock-out';
      case 'unexplained_absence':
        return 'Unexplained absence';
      default:
        return dbType;
    }
  }

  Future<void> markReviewed(AnomalyEvent event) async {
    await AnomalyService.markReviewed(event.id);
    final i = feed.indexWhere((e) => e.id == event.id);
    if (i != -1) feed[i] = feed[i].copyWith(reviewed: true);
    notifyListeners();
  }

  /// HR reverting a violation after a dispute investigation finds it
  /// invalid (FR3.6). Only offered when [AnomalyEvent.attendanceRecordId]
  /// is non-null — see that field's doc comment. Returns the risk points
  /// given back; throws if the server refuses (e.g. already reverted, or
  /// HR reverting their own violation).
  Future<int> revertViolation(AnomalyEvent event) async {
    final restored = await AnomalyService.revert(event.id);
    final i = feed.indexWhere((e) => e.id == event.id);
    if (i != -1) {
      feed[i] = feed[i].copyWith(
        reviewed: true,
        reverted: true,
        appealStatus: feed[i].appealStatus == 'pending' ? 'accepted' : null,
      );
    }
    notifyListeners();
    return restored;
  }

  /// Throws if the server refuses (e.g. no open appeal, or HR's own).
  Future<void> rejectAppeal(AnomalyEvent event, String response) async {
    await AnomalyService.rejectAppeal(event.id, response);
    final i = feed.indexWhere((e) => e.id == event.id);
    if (i != -1) feed[i] = feed[i].copyWith(reviewed: true, appealStatus: 'rejected');
    notifyListeners();
  }
}

final anomalyController = AnomalyController();
