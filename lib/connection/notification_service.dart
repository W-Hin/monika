import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `notifications` table. Rows are written only by
/// server-side triggers (see migration 0015) — this service only reads and
/// marks-as-read, plus a Realtime subscription helper.
class NotificationService {
  NotificationService._();
  static final _client = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<void> markRead(int id) async {
    await _client.from('notifications').update({'is_read': true}).eq('id', id);
  }

  static Future<void> markAllRead() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return;
    await _client.from('notifications').update({'is_read': true}).eq('user_id', uid).eq('is_read', false);
  }

  /// Subscribes to new notification rows for the current user in real time
  /// over Supabase Realtime (Postgres change feed via websocket — in-app
  /// real-time, not OS-level push, which needs a separate FCM/APNs setup).
  static RealtimeChannel subscribe({required String userId, required void Function(Map<String, dynamic> row) onInsert}) {
    return _client
        .channel('notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: userId),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }
}
