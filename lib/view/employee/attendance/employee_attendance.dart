import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../controller/attendance_controller.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  @override
  void initState() {
    super.initState();
    attendanceController.loadPolicy().then((_) => setState(() {}));
    attendanceController.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = DummyData.employeeUser;

    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Attendance')),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: attendanceController,
          builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Risk Classification', style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Based on last 90 days', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                        ],
                      ),
                      StatusPill.risk(user.riskLevel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _RiskFactor(label: 'Score', value: '94', color: c.primary),
                      const SizedBox(width: 12),
                      _RiskFactor(label: 'Violations', value: '1', color: c.amber),
                      const SizedBox(width: 12),
                      _RiskFactor(label: 'Late Days', value: '1', color: c.infoBlue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Days Present',
                    value: '21',
                    icon: Icons.event_available_rounded,
                    iconColor: c.primary,
                    iconBg: c.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'On Leave',
                    value: '2',
                    icon: Icons.beach_access_rounded,
                    iconColor: c.infoBlue,
                    iconBg: c.infoBlueBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'IoT Verification Layers'),
            _VerificationInfoCard(
              icon: Icons.my_location_rounded,
              title: 'GPS Geofencing',
              desc: 'Active · ${attendanceController.geofenceRadius}m radius around Main Office',
              ok: true,
            ),
            const SizedBox(height: 10),
            _VerificationInfoCard(
              icon: Icons.wifi_rounded,
              title: 'WiFi SSID Verification',
              desc: 'Active · Connected to ${attendanceController.officeWifiSsid}',
              ok: true,
            ),
            const SizedBox(height: 10),
            _VerificationInfoCard(
              icon: Icons.phone_android_rounded,
              title: 'Registered Device',
              desc: '${user.registeredDevice} · Bound on ${user.deviceBoundSince}',
              ok: true,
            ),
            const SizedBox(height: 24),
            const SectionHeader(title: 'Recent Records'),
            if (attendanceController.history.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No attendance records yet',
                subtitle: 'Clock in from the Home tab to start building your history.',
              )
            else
              ...attendanceController.history.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.date, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text('${r.clockIn}${r.clockOut != null ? " → ${r.clockOut}" : ""}', style: TextStyle(fontSize: 12, color: c.textMuted)),
                          ],
                        ),
                      ),
                      StatusDot.attendance(context, r.status),
                    ],
                  ),
                ),
              )),
          ],
          ),
        ),
      ),
    );
  }
}

class _RiskFactor extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _RiskFactor({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _VerificationInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final bool ok;
  const _VerificationInfoCard({required this.icon, required this.title, required this.desc, required this.ok});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, size: 19, color: c.primaryDark),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, color: ok ? c.primary : c.riskHigh, size: 20),
        ],
      ),
    );
  }
}