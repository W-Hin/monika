import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `company_events` / `company_event_assignments`
/// tables.
class CalendarService {
  CalendarService._();
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client
        .from('company_events')
        .select('*, company_event_assignments(user_id, profiles(name))')
        .order('event_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> create({
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String eventType,
    required List<String> assignedUuids,
  }) async {
    final inserted = await _client
        .from('company_events')
        .insert({
          'title': title,
          'event_date': _dateKey(eventDate),
          'end_date': endDate != null ? _dateKey(endDate) : null,
          'event_type': eventType,
        })
        .select()
        .single();
    await _replaceAssignments(inserted['id'] as int, assignedUuids);
  }

  static Future<void> update({
    required int id,
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String eventType,
    required List<String> assignedUuids,
  }) async {
    await _client.from('company_events').update({
      'title': title,
      'event_date': _dateKey(eventDate),
      'end_date': endDate != null ? _dateKey(endDate) : null,
      'event_type': eventType,
    }).eq('id', id);
    await _replaceAssignments(id, assignedUuids);
  }

  static Future<void> _replaceAssignments(int eventId, List<String> assignedUuids) async {
    await _client.from('company_event_assignments').delete().eq('event_id', eventId);
    if (assignedUuids.isNotEmpty) {
      await _client.from('company_event_assignments').insert(
            assignedUuids.map((uid) => {'event_id': eventId, 'user_id': uid}).toList(),
          );
    }
  }

  static Future<void> delete(int id) async {
    await _client.from('company_events').delete().eq('id', id);
  }

  static String _dateKey(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;
}
