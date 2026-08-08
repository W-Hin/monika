import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../connection/notification_service.dart';
import '../model/models.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
class NotificationController extends ChangeNotifier {
  List<AppNotification> items = [];
  bool loading = false;
  String? errorMessage;
  RealtimeChannel? _channel;

  int get unreadCount => items.where((n) => !n.isRead).length;

  AppNotification _mapRow(Map<String, dynamic> row) {
    return AppNotification(
      id: row['id'] as int,
      title: row['title'] as String,
      body: row['body'] as String,
      type: row['type'] as String,
      isRead: row['is_read'] as bool,
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
    );
  }

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final rows = await NotificationService.fetchMine();
      items = rows.map(_mapRow).toList();
    } catch (e) {
      errorMessage = 'Could not load notifications: $e';
    }
    loading = false;
    notifyListeners();
  }

  /// Starts the Realtime subscription for the given user — call once right
  /// after login. New rows from the server-side triggers (migration 0015)
  /// arrive here immediately over the websocket, no polling.
  void subscribe(String userId) {
    _channel?.unsubscribe();
    _channel = NotificationService.subscribe(
      userId: userId,
      onInsert: (row) {
        items = [_mapRow(row), ...items];
        notifyListeners();
      },
    );
  }

  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    items = [];
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    items = items.map((i) => i.id == n.id ? i.copyWith(isRead: true) : i).toList();
    notifyListeners();
    await NotificationService.markRead(n.id);
  }

  Future<void> markAllRead() async {
    items = items.map((i) => i.copyWith(isRead: true)).toList();
    notifyListeners();
    await NotificationService.markAllRead();
  }
}

final notificationController = NotificationController();
