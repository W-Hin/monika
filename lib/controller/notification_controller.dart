import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../connection/notification_service.dart';
import '../model/models.dart';
import 'device_request_controller.dart';

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
        // A device-change decision notification means the employee's
        // pending request just got resolved — recheck so "Requested"
        // reverts to "Request Change" without needing to leave and
        // re-open the Profile screen.
        if (row['type'] == 'device_change') {
          deviceRequestController.loadMyPending();
        }
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

  String? announcementError;

  /// Returns the recipient count on success, null on failure (with
  /// announcementError set for the caller to surface).
  Future<int?> postAnnouncement({required String title, required String body, String? departmentName}) async {
    announcementError = null;
    try {
      return await NotificationService.postAnnouncement(title: title, body: body, departmentName: departmentName);
    } catch (e) {
      announcementError = 'Could not post announcement: $e';
      notifyListeners();
      return null;
    }
  }
}

final notificationController = NotificationController();
