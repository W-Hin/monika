import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors_extension.dart';
import 'widgets/common_widgets.dart';
import '../../controller/notification_controller.dart';

IconData _iconFor(String type) {
  switch (type) {
    case 'leave_decision':
      return Icons.check_circle_outline_rounded;
    case 'training':
      return Icons.school_outlined;
    case 'payroll':
      return Icons.receipt_long_outlined;
    case 'anomaly':
      return Icons.flag_rounded;
    case 'pe':
      return Icons.insights_outlined;
    case 'device_change':
      return Icons.phone_android_rounded;
    case 'announcement':
      return Icons.campaign_rounded;
    default:
      return Icons.notifications_none_rounded;
  }
}

AppHue _hueFor(String type) {
  switch (type) {
    case 'leave_decision':
      return AppHue.primary;
    case 'training':
      return AppHue.infoBlue;
    case 'payroll':
      return AppHue.purple;
    case 'anomaly':
      return AppHue.riskHigh;
    case 'pe':
      return AppHue.amber;
    case 'device_change':
      return AppHue.primary;
    case 'announcement':
      return AppHue.purple;
    default:
      return AppHue.infoBlue;
  }
}

String _relativeTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
  if (diff.inDays < 7) return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
  return DateFormat('d MMM yyyy').format(t);
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  void initState() {
    super.initState();
    notificationController.load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(
        title: ListenableBuilder(
          listenable: notificationController,
          builder: (context, _) {
            final unread = notificationController.unreadCount;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Notifications'),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: c.riskHigh, borderRadius: BorderRadius.circular(100)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                  ),
                ],
              ],
            );
          },
        ),
        actions: [
          ListenableBuilder(
            listenable: notificationController,
            builder: (context, _) => notificationController.unreadCount > 0
                ? TextButton(onPressed: notificationController.markAllRead, child: const Text('Mark all read'))
                : const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: notificationController,
          builder: (context, _) {
            if (notificationController.loading && notificationController.items.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            if (notificationController.errorMessage != null && notificationController.items.isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load notifications',
                  subtitle: notificationController.errorMessage!,
                  onRetry: notificationController.load,
                ),
              );
            }
            final notifs = notificationController.items;
            if (notifs.isEmpty) {
              return const Center(
                child: EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No notifications',
                  subtitle: 'You\'re all caught up!',
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = notifs[i];
                final (color, bg) = resolveHue(c, _hueFor(n.type));
                return GestureDetector(
                  onTap: () => notificationController.markRead(n),
                  child: Container(
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: n.isRead ? c.border : color.withValues(alpha: 0.3)),
                    ),
                    child: Stack(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                                child: Icon(_iconFor(n.type), size: 20, color: color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      n.title,
                                      style: TextStyle(fontSize: 13.5, fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800, color: c.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(n.body, style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4)),
                                    const SizedBox(height: 6),
                                    Text(_relativeTime(n.createdAt), style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!n.isRead)
                          Positioned(
                            top: 14,
                            right: 14,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                          ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
