import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class AnomalyDetailScreen extends StatefulWidget {
  const AnomalyDetailScreen({super.key});

  @override
  State<AnomalyDetailScreen> createState() => _AnomalyDetailScreenState();
}

class _AnomalyDetailScreenState extends State<AnomalyDetailScreen> {
  String _filter = 'All';
  final _filters = ['All', 'High', 'Medium', 'Low'];

  List<AnomalyEvent> get _filtered {
    if (_filter == 'All') return DummyData.anomalyFeed;
    final map = {'High': RiskLevel.high, 'Medium': RiskLevel.medium, 'Low': RiskLevel.low};
    return DummyData.anomalyFeed.where((e) => e.severity == map[_filter]).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _filtered;
    final high = DummyData.anomalyFeed.where((e) => e.severity == RiskLevel.high).length;
    final med = DummyData.anomalyFeed.where((e) => e.severity == RiskLevel.medium).length;

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
                      Expanded(child: StatCard(label: 'High Severity', value: '$high', icon: Icons.error_outline_rounded, iconColor: AppColors.riskHigh, iconBg: AppColors.riskHighBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Medium Severity', value: '$med', icon: Icons.warning_amber_rounded, iconColor: AppColors.riskMedium, iconBg: AppColors.riskMediumBg)),
                      const SizedBox(width: 12),
                      Expanded(child: StatCard(label: 'Total Today', value: '${DummyData.anomalyFeed.length}', icon: Icons.flag_rounded, iconColor: AppColors.infoBlue, iconBg: AppColors.infoBlueBg)),
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
                                color: selected ? AppColors.primary : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Text(f, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textSecondary)),
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
              child: events.isEmpty
                  ? const EmptyState(icon: Icons.security_rounded, title: 'No violations found', subtitle: 'No anomalies matching the selected filter.')
                  : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _AnomalyCard(event: events[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnomalyCard extends StatelessWidget {
  final AnomalyEvent event;
  const _AnomalyCard({required this.event});

  IconData get _icon {
    switch (event.type) {
      case 'Shared-device violation': return Icons.devices_rounded;
      case 'Out-of-zone clock-in': return Icons.location_off_rounded;
      case 'WiFi SSID mismatch': return Icons.wifi_off_rounded;
      default: return Icons.schedule_rounded;
    }
  }

  Color get _iconColor => event.severity == RiskLevel.high ? AppColors.riskHigh : event.severity == RiskLevel.medium ? AppColors.riskMedium : AppColors.riskLow;
  Color get _iconBg => event.severity == RiskLevel.high ? AppColors.riskHighBg : event.severity == RiskLevel.medium ? AppColors.riskMediumBg : AppColors.riskLowBg;

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(color: _iconBg, borderRadius: BorderRadius.circular(12)),
                child: Icon(_icon, color: _iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.type, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                    Text(event.date, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              StatusPill.risk(event.severity),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              InitialsAvatar(initials: initials, size: 32),
              const SizedBox(width: 10),
              Text(event.employeeName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(event.details, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.person_search_rounded, size: 16),
                  label: const Text('View Employee'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 10)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                  label: const Text('Mark Reviewed'),
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