import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../../../controller/attendance_controller.dart';
import '../../../controller/auth_controller.dart';
import '../../../controller/leave_controller.dart';
import 'attendance_history.dart';

class EmployeeAttendanceScreen extends StatefulWidget {
  const EmployeeAttendanceScreen({super.key});

  @override
  State<EmployeeAttendanceScreen> createState() => _EmployeeAttendanceScreenState();
}

class _EmployeeAttendanceScreenState extends State<EmployeeAttendanceScreen> {
  GpsCheckResult? _gpsResult;
  WifiCheckResult? _wifiResult;
  DeviceCheckResult? _deviceResult;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    attendanceController.loadPolicy().then((_) => setState(() {}));
    attendanceController.loadHistory();
    attendanceController.loadRiskWindow();
    attendanceController.loadYearWindow();
    attendanceController.loadAbsenceFlags();
    leaveController.loadMy();
    _runLiveChecks();
  }

  Future<void> _appeal(AbsenceFlag flag) async {
    final reason = TextEditingController();
    final submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Appeal This Absence'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tell HR why you had no clock-in on ${DateFormat('EEE, d MMM').format(flag.date)}, e.g. you were working off-site or forgot to clock in. HR will excuse it or reply.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reason,
                maxLines: 3,
                maxLength: 300,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(hintText: 'Reason (at least 10 characters)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
            TextButton(
              onPressed: reason.text.trim().length >= 10 ? () => Navigator.of(dialogContext).pop(true) : null,
              child: const Text('Send Appeal'),
            ),
          ],
        ),
      ),
    );
    final text = reason.text.trim();
    reason.dispose();
    if (submitted != true) return;
    final error = await attendanceController.appealAbsence(flag, text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? '✓ Appeal sent to HR'),
        backgroundColor: error == null ? null : context.colors.riskHigh,
      ),
    );
  }

  /// Re-runs the actual GPS/WiFi/device checks so this screen reflects
  /// live conditions — it previously just showed three cards hardcoded to
  /// "verified", including "Registered Device" staying checked even after
  /// HR approved a device-change request and cleared it.
  Future<void> _runLiveChecks() async {
    setState(() => _checking = true);
    // GPS first: it asks for location permission, which the WiFi check
    // needs before the phone will reveal the network name.
    final gps = await attendanceController.runGpsCheck();
    final results = await Future.wait([
      attendanceController.runWifiCheck(),
      attendanceController.checkDeviceStatus(),
    ]);
    if (!mounted) return;
    setState(() {
      _gpsResult = gps;
      _wifiResult = results[0] as WifiCheckResult;
      _deviceResult = results[1] as DeviceCheckResult;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Attendance'),
        actions: [
          IconButton(
            tooltip: 'Re-check verification status',
            onPressed: _checking ? null : _runLiveChecks,
            icon: _checking
                ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.textSecondary))
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([attendanceController, authController, leaveController]),
          builder: (context, _) {
          final user = DummyData.employeeUser;
          return RefreshIndicator(
          onRefresh: () => Future.wait([
            attendanceController.loadHistory(),
            attendanceController.loadRiskWindow(),
            attendanceController.loadYearWindow(),
            attendanceController.loadAbsenceFlags(),
            _runLiveChecks(),
          ]),
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AppCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Risk Classification', style: TextStyle(fontSize: 13, color: c.textSecondary, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('Deducted per violation; counts below are last 90 days', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      StatusPill.risk(user.riskLevel),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _RiskFactor(label: 'Score', value: '${user.riskScore}', color: c.primary),
                      const SizedBox(width: 12),
                      _RiskFactor(label: 'Violations', value: '${attendanceController.riskViolations}', color: c.amber),
                      const SizedBox(width: 12),
                      _RiskFactor(label: 'Late Days', value: '${attendanceController.riskLateDays}', color: c.infoBlue),
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
                    label: 'Days Present This Year',
                    value: '${attendanceController.daysPresentThisYear}',
                    icon: Icons.event_available_rounded,
                    iconColor: c.primary,
                    iconBg: c.primaryLight,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Leave Taken',
                    value: '${(leaveController.myBalance?.annualUsed ?? 0) + (leaveController.myBalance?.medicalUsed ?? 0) + (leaveController.myBalance?.emergencyUsed ?? 0)} days',
                    icon: Icons.beach_access_rounded,
                    iconColor: c.infoBlue,
                    iconBg: c.infoBlueBg,
                  ),
                ),
              ],
            ),
            if (attendanceController.absenceFlags.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionHeader(title: 'Unexplained Absences'),
              ...attendanceController.absenceFlags.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AbsenceFlagCard(flag: f, onAppeal: () => _appeal(f)),
                  )),
            ],
            const SizedBox(height: 24),
            const SectionHeader(title: 'IoT Verification Layers'),
            _VerificationInfoCard(
              icon: Icons.my_location_rounded,
              title: 'GPS Geofencing',
              desc: _gpsResult?.detail ?? 'Checking your current location…',
              state: _checking && _gpsResult == null
                  ? _VerifyState.pending
                  : (_gpsResult?.passed ?? false)
                      ? _VerifyState.ok
                      : _VerifyState.fail,
            ),
            const SizedBox(height: 10),
            _VerificationInfoCard(
              icon: Icons.wifi_rounded,
              title: 'WiFi SSID Verification',
              desc: _wifiResult?.detail ?? 'Checking your WiFi connection…',
              state: _checking && _wifiResult == null
                  ? _VerifyState.pending
                  : (_wifiResult?.passed ?? false)
                      ? _VerifyState.ok
                      : _VerifyState.fail,
            ),
            const SizedBox(height: 10),
            _VerificationInfoCard(
              icon: Icons.phone_android_rounded,
              title: 'Registered Device',
              desc: _deviceResult?.detail ?? 'Checking this device…',
              state: _checking && _deviceResult == null
                  ? _VerifyState.pending
                  : user.registeredDevice == 'Not yet registered'
                      ? _VerifyState.warning
                      : (_deviceResult?.passed ?? false)
                          ? _VerifyState.ok
                          : _VerifyState.fail,
            ),
            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Records',
              actionLabel: 'See all',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())),
            ),
            if (attendanceController.history.isEmpty)
              const EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'No attendance records yet',
                subtitle: 'Clock in from the Home tab to start building your history.',
              )
            else
              ...attendanceController.history.take(7).map((r) => Padding(
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
          );
          },
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

enum _VerifyState { pending, ok, warning, fail }

class _VerificationInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  final _VerifyState state;
  const _VerificationInfoCard({required this.icon, required this.title, required this.desc, required this.state});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget trailing;
    switch (state) {
      case _VerifyState.pending:
        trailing = SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: c.textMuted));
        break;
      case _VerifyState.ok:
        trailing = Icon(Icons.check_circle_rounded, color: c.primary, size: 20);
        break;
      case _VerifyState.warning:
        trailing = Icon(Icons.info_rounded, color: c.amber, size: 20);
        break;
      case _VerifyState.fail:
        trailing = Icon(Icons.error_rounded, color: c.riskHigh, size: 20);
        break;
    }
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
          trailing,
        ],
      ),
    );
  }
}
/// One unexplained absence with where its appeal stands.
class AbsenceFlagCard extends StatelessWidget {
  final AbsenceFlag flag;
  final VoidCallback onAppeal;
  const AbsenceFlagCard({super.key, required this.flag, required this.onAppeal});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fmt = DateFormat('d MMM');
    final (String label, Color color) = flag.excused
        ? ('Excused by HR', c.primary)
        : switch (flag.appealStatus) {
            'pending' => ('Appeal sent — waiting for HR', c.statusPending),
            'rejected' => ('Appeal not accepted', c.riskHigh),
            _ => flag.canAppeal ? ('You can appeal until ${fmt.format(flag.appealDeadline)}', c.amber) : ('Appeal period has ended', c.textMuted),
          };
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_busy_rounded, size: 18, color: flag.excused ? c.primary : c.riskHigh),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('EEE, d MMM yyyy').format(flag.date), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(label, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (flag.canAppeal)
                TextButton(onPressed: onAppeal, child: const Text('Appeal')),
            ],
          ),
          if (flag.appealResponse != null) ...[
            const SizedBox(height: 6),
            Text('HR: ${flag.appealResponse}', style: TextStyle(fontSize: 12, color: c.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
