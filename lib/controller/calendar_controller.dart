import 'package:flutter/foundation.dart';
import '../connection/calendar_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class CalendarController extends ChangeNotifier {
  List<CalendarEvent> events = [];
  bool loading = false;
  String? errorMessage;

  static const _typeToDisplay = {
    'public_holiday': 'Public Holiday',
    'company_event': 'Company Event',
    'hr_event': 'HR Event',
  };
  static const _typeToDb = {
    'Public Holiday': 'public_holiday',
    'Company Event': 'company_event',
    'HR Event': 'hr_event',
  };

  CalendarEvent _mapEvent(Map<String, dynamic> row) {
    final assignRaw = row['company_event_assignments'] as List<dynamic>? ?? [];
    final assignedTo = assignRaw
        .map((a) {
          final profile = a['profiles'] as Map<String, dynamic>?;
          return AssignedEmployee(uuid: a['user_id'] as String, name: profile?['name'] as String? ?? '');
        })
        .toList();
    // .toLocal() matches the .toUtc() applied on write in CalendarService —
    // without it, a timestamptz read back as a UTC-flagged DateTime would
    // show the wrong hour (and sometimes the wrong day) once formatted.
    return CalendarEvent(
      dbId: row['id'] as int,
      title: row['title'] as String,
      eventDate: DateTime.parse(row['event_date'] as String).toLocal(),
      endDate: row['end_date'] != null ? DateTime.parse(row['end_date'] as String).toLocal() : null,
      type: _typeToDisplay[row['event_type']] ?? row['event_type'] as String,
      assignedTo: assignedTo,
    );
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final rows = await CalendarService.fetchAll();
      events = rows.map(_mapEvent).toList();
    } catch (e) {
      errorMessage = 'Could not load calendar events: $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> create({
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String displayType,
    List<String> assignedUuids = const [],
  }) async {
    errorMessage = null;
    try {
      await CalendarService.create(
        title: title,
        eventDate: eventDate,
        endDate: endDate,
        eventType: _typeToDb[displayType] ?? 'company_event',
        assignedUuids: assignedUuids,
      );
      await load();
      return true;
    } catch (e) {
      errorMessage = 'Could not create event: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> update({
    required CalendarEvent existing,
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String displayType,
    List<String> assignedUuids = const [],
  }) async {
    errorMessage = null;
    if (existing.dbId == null) return false;
    try {
      await CalendarService.update(
        id: existing.dbId!,
        title: title,
        eventDate: eventDate,
        endDate: endDate,
        eventType: _typeToDb[displayType] ?? 'company_event',
        assignedUuids: assignedUuids,
      );
      await load();
      return true;
    } catch (e) {
      errorMessage = 'Could not update event: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(CalendarEvent event) async {
    errorMessage = null;
    if (event.dbId == null) return false;
    try {
      await CalendarService.delete(event.dbId!);
      await load();
      return true;
    } catch (e) {
      errorMessage = 'Could not delete event: $e';
      notifyListeners();
      return false;
    }
  }
}

final calendarController = CalendarController();
