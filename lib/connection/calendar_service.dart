import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `company_events` table.
class CalendarService {
  CalendarService._();
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchAll() async {
    final rows = await _client.from('company_events').select().order('event_date');
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> create({
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String eventType,
  }) async {
    await _client.from('company_events').insert({
      'title': title,
      'event_date': _dateKey(eventDate),
      'end_date': endDate != null ? _dateKey(endDate) : null,
      'event_type': eventType,
    });
  }

  static Future<void> update({
    required int id,
    required String title,
    required DateTime eventDate,
    DateTime? endDate,
    required String eventType,
  }) async {
    await _client.from('company_events').update({
      'title': title,
      'event_date': _dateKey(eventDate),
      'end_date': endDate != null ? _dateKey(endDate) : null,
      'event_type': eventType,
    }).eq('id', id);
  }

  static Future<void> delete(int id) async {
    await _client.from('company_events').delete().eq('id', id);
  }

  static String _dateKey(DateTime d) => DateTime(d.year, d.month, d.day).toIso8601String().split('T').first;
}
