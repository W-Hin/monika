import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../shared/widgets/common_widgets.dart';

class _CalendarEvent {
  final String title;
  final String date;
  final String? endDate;
  final String type; // Holiday, Event, Meeting
  final IconData icon;
  final Color color;
  final Color bg;

  const _CalendarEvent({
    required this.title,
    required this.date,
    this.endDate,
    required this.type,
    required this.icon,
    required this.color,
    required this.bg,
  });
}

const _events = [
  _CalendarEvent(title: 'Hari Raya Aidiladha', date: '7 Jun 2026', type: 'Public Holiday', icon: Icons.celebration_rounded, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Q2 Company Town Hall', date: '15 Jun 2026', type: 'Company Event', icon: Icons.groups_rounded, color: AppColors.infoBlue, bg: AppColors.infoBlueBg),
  _CalendarEvent(title: 'Yang Di-Pertuan Agong Birthday', date: '6 Jul 2026', type: 'Public Holiday', icon: AppIcons.flag, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Mid-Year Performance Reviews', date: '14 Jul 2026', endDate: '18 Jul 2026', type: 'Company Event', icon: Icons.assessment_rounded, color: AppColors.amber, bg: AppColors.amberBg),
  _CalendarEvent(title: 'National Day', date: '31 Aug 2026', type: 'Public Holiday', icon: AppIcons.flag, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Annual Team Building', date: '5 Sep 2026', endDate: '6 Sep 2026', type: 'Company Event', icon: Icons.emoji_events_rounded, color: AppColors.purple, bg: AppColors.purpleBg),
  _CalendarEvent(title: 'Malaysia Day', date: '16 Sep 2026', type: 'Public Holiday', icon: AppIcons.flag, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Q3 Department Reviews', date: '28 Sep 2026', type: 'Company Event', icon: Icons.bar_chart_rounded, color: AppColors.amber, bg: AppColors.amberBg),
  _CalendarEvent(title: 'Deepavali', date: '20 Oct 2026', type: 'Public Holiday', icon: Icons.celebration_rounded, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Annual PE Cycle Begins', date: '1 Nov 2026', type: 'HR Event', icon: Icons.insights_rounded, color: AppColors.riskMedium, bg: AppColors.riskMediumBg),
  _CalendarEvent(title: 'Christmas Day', date: '25 Dec 2026', type: 'Public Holiday', icon: Icons.celebration_rounded, color: AppColors.primary, bg: AppColors.primaryLight),
  _CalendarEvent(title: 'Q4 Annual Review Deadline', date: '30 Dec 2026', type: 'HR Event', icon: Icons.assessment_rounded, color: AppColors.riskMedium, bg: AppColors.riskMediumBg),
];

// Simple alias since Icons.flag isn't a const issue — use a workaround
class AppIcons {
  static const flag = Icons.flag_rounded;
}

class CompanyCalendarScreen extends StatefulWidget {
  const CompanyCalendarScreen({super.key});

  @override
  State<CompanyCalendarScreen> createState() => _CompanyCalendarScreenState();
}

class _CompanyCalendarScreenState extends State<CompanyCalendarScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Public Holiday', 'Company Event', 'HR Event'];

  List<_CalendarEvent> get _filtered =>
      _filter == 'All' ? _events : _events.where((e) => e.type == _filter).toList();

  int get _holidayCount => _events.where((e) => e.type == 'Public Holiday').length;
  int get _eventCount => _events.where((e) => e.type == 'Company Event').length;

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    // Group by month
    final Map<String, List<_CalendarEvent>> grouped = {};
    for (final e in filtered) {
      final parts = e.date.split(' ');
      final monthYear = '${parts[1]} ${parts[2]}';
      grouped.putIfAbsent(monthYear, () => []).add(e);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Company Calendar')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: StatCard(label: 'Public Holidays', value: '$_holidayCount', icon: Icons.flag_rounded, iconColor: AppColors.primary, iconBg: AppColors.primaryLight)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Company Events', value: '$_eventCount', icon: Icons.groups_rounded, iconColor: AppColors.infoBlue, iconBg: AppColors.infoBlueBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'HR Events', value: '${_events.where((e) => e.type == 'HR Event').length}', icon: Icons.insights_rounded, iconColor: AppColors.amber, iconBg: AppColors.amberBg)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final sel = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(f, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? const EmptyState(icon: Icons.calendar_month_outlined, title: 'No events found', subtitle: 'Try a different filter.')
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          entry.key,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                        ),
                      ),
                      ...entry.value.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EventTile(event: e),
                      )),
                      const SizedBox(height: 8),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final _CalendarEvent event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: event.bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(event.icon, color: event.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
                    const SizedBox(width: 5),
                    Text(
                      event.endDate != null ? '${event.date} – ${event.endDate}' : event.date,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: event.bg, borderRadius: BorderRadius.circular(100)),
                  child: Text(event.type, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: event.color)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}