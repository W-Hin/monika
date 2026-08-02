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

  Future<void> loadFeed() async {
    loading = true;
    notifyListeners();
    final rows = await AnomalyService.fetchFeed();
    feed = rows.map(_mapEvent).toList();
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
}

final anomalyController = AnomalyController();
