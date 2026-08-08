import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../model/models.dart';
import '../../../controller/anomaly_controller.dart';
import '../../../controller/employee_controller.dart';
import '../employees/employee_detail.dart';

class AnomalyDetailScreen extends StatefulWidget {
  const AnomalyDetailScreen({super.key});

  @override
  State<AnomalyDetailScreen> createState() => _AnomalyDetailScreenState();
}

class _AnomalyDetailScreenState extends State<AnomalyDetailScreen> {
  String _filter = 'All';
  final _filters = ['All', 'High', 'Medium', 'Low'];

  @override
  void initState() {
    super.initState();
    anomalyController.loadFeed();
    if (employeeController.employees.isEmpty) {
      employeeController.loadEmployees();
    }
  }

  List<AnomalyEvent> _filtered(List<AnomalyEvent> events) {
    if (_filter == 'All') return events;
    final map = {'High': RiskLevel.high, 'Medium': RiskLevel.medium, 'Low': RiskLevel.low};
    return events.where((e) => e.severity == map[_filter]).toList();
  }

  void _markReviewed(AnomalyEvent event) async {
    await anomalyController.markReviewed(event);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Marked reviewed: ${event.employeeName} · ${event.type}')),
    );
  }

  void _viewEmployee(BuildContext context, String employeeName) {
    final match = employeeController.employees.where((e) => e.name == employeeName);
    if (match.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$employeeName is not in the current team directory yet')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeDetailScreen(employee: match.first, onUpdate: employeeController.updateLocal),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: anomalyController,
      builder: (context, _) {
    final allEvents = anomalyController.feed;
    final events = _filtered(allEvents);
    final high = allEvents.where((e) => e.severity == RiskLevel.high).length;
    final med = allEvents.where((e) => e.severity == RiskLevel.medium).length;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Anomaly & Violation Feed'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: StatCard(label: 'High Severity', value: '$high', icon: Icons.error_outline_rounded, iconColor: c.riskHigh, iconBg: c.riskHighBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Medium Severity', value: '$med', icon: Icons.warning_amber_rounded, iconColor: c.riskMedium, iconBg: c.riskMediumBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Total Events', value: '${allEvents.length}', icon: Icons.flag_rounded, iconColor: c.infoBlue, iconBg: c.infoBlueBg)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filters.map((f) {
                        final selected = _filter == f;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _filter = f),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? c.primary : c.surfaceMuted,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(f, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : c.textSecondary)),
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
              child: anomalyController.loading
                  ? const Center(child: CircularProgressIndicator())
                  : events.isEmpty
                      ? const EmptyState(icon: Icons.security_rounded, title: 'No violations found', subtitle: 'No anomalies matching the selected filter.')
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          itemCount: events.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _AnomalyCard(
                            event: events[i],
                            onViewEmployee: () => _viewEmployee(context, events[i].employeeName),
                            onMarkReviewed: () => _markReviewed(events[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
      },
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final AnomalyEvent event;
  final VoidCallback onViewEmployee;
  final VoidCallback onMarkReviewed;
  const _AnomalyCard({required this.event, required this.onViewEmployee, required this.onMarkReviewed});

  IconData get _icon {
    switch (event.type) {
      case 'Shared-device violation': return Icons.devices_rounded;
      case 'Out-of-zone clock-in': return Icons.location_off_rounded;
      case 'WiFi SSID mismatch': return Icons.wifi_off_rounded;
      case 'Early clock-out': return Icons.logout_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  Color _iconColor(BuildContext context) => event.severity == RiskLevel.high ? context.colors.riskHigh : event.severity == RiskLevel.medium ? context.colors.riskMedium : context.colors.riskLow;
  Color _iconBg(BuildContext context) => event.severity == RiskLevel.high ? context.colors.riskHighBg : event.severity == RiskLevel.medium ? context.colors.riskMediumBg : context.colors.riskLowBg;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final initials = event.employeeName.split(' ').map((w) => w[0]).take(2).join();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: _iconBg(context), borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, color: _iconColor(context), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.type, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    Text(event.date, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
              StatusDot.risk(context, event.severity),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InitialsAvatar(initials: initials, size: 32),
              const SizedBox(width: 10),
              Expanded(child: Text(event.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
              if (event.reviewed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: c.riskLowBg, borderRadius: BorderRadius.circular(100)),
                  child: Text('Reviewed', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: c.primary)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 14, color: c.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(event.details, style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onViewEmployee,
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: const Text('View Employee'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: event.reviewed ? null : onMarkReviewed,
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: Text(event.reviewed ? 'Reviewed' : 'Mark Reviewed'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}