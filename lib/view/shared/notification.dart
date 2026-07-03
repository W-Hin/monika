import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import 'widgets/common_widgets.dart';

class _Notif {
  final String title;
  final String body;
  final String time;
  final IconData icon;
  final Color color;
  final Color bg;
  final bool read;

  const _Notif({
    required this.title,
    required this.body,
    required this.time,
    required this.icon,
    required this.color,
    required this.bg,
    this.read = false,
  });
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final List<_Notif> _notifs = [
    const _Notif(
      title: 'Leave Application Approved',
      body:
          'Your Annual Leave application (02 Jul – 04 Jul) has been approved by HR.',
      time: '10 min ago',
      icon: Icons.check_circle_outline_rounded,
      color: AppColors.primary,
      bg: AppColors.primaryLight,
    ),
    const _Notif(
      title: 'Training Recommendation',
      body:
          'A new training programme has been recommended for you: Leadership Fundamentals.',
      time: '1 hour ago',
      icon: Icons.auto_awesome_rounded,
      color: AppColors.amber,
      bg: AppColors.amberBg,
    ),
    const _Notif(
      title: 'Attendance Flag',
      body:
          'Your clock-in on Mon 15 Jun was flagged: GPS outside geofence radius.',
      time: '2 days ago',
      icon: Icons.flag_rounded,
      color: AppColors.riskHigh,
      bg: AppColors.riskHighBg,
    ),
    const _Notif(
      title: 'Payroll Summary Available',
      body:
          'Your June 2026 payroll summary is now available. Net pay: RM 4,355.00.',
      time: '3 days ago',
      icon: Icons.receipt_long_outlined,
      color: AppColors.purple,
      bg: AppColors.purpleBg,
      read: true,
    ),
    const _Notif(
      title: 'Mandatory Training Reminder',
      body:
          'Workplace Data Privacy & Security training is due in 7 days. 60% completed.',
      time: '5 days ago',
      icon: Icons.school_outlined,
      color: AppColors.infoBlue,
      bg: AppColors.infoBlueBg,
      read: true,
    ),
    const _Notif(
      title: 'Performance Evaluation',
      body:
          'Your 2025 Performance Evaluation results are now available. View your KPI scores.',
      time: '1 week ago',
      icon: Icons.insights_outlined,
      color: AppColors.amber,
      bg: AppColors.amberBg,
      read: true,
    ),
  ];

  late List<bool> _readState;

  @override
  void initState() {
    super.initState();
    _readState = _notifs.map((n) => n.read).toList();
  }

  int get _unreadCount => _readState.where((r) => !r).length;

  void _markAllRead() => setState(() {
    for (int i = 0; i < _readState.length; i++) {
      _readState[i] = true;
    }
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Notifications'),
            if (_unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.riskHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _notifs.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications',
                subtitle: 'You\'re all caught up!',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _notifs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = _notifs[i];
                  final isRead = _readState[i];
                  return GestureDetector(
                    onTap: () => setState(() => _readState[i] = true),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? AppColors.border
                              : n.color.withOpacity(0.3),
                        ),
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
                                  decoration: BoxDecoration(
                                    color: n.bg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(n.icon, size: 20, color: n.color),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: isRead
                                              ? FontWeight.w600
                                              : FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        n.time,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (!isRead)
                            Positioned(
                              top: 14,
                              right: 14,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: n.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
