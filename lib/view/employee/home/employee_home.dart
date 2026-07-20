import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import '../attendance/clock_in.dart';
import '../attendance/clock_out.dart';
import '../leave/leave_apply.dart';
import '../payroll/payroll.dart';
import '../pe/pe_detail.dart';
import '../attendance/attendance_history.dart';
import '../../shared/notification.dart';

class EmployeeHomeScreen extends StatefulWidget {
  const EmployeeHomeScreen({super.key});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  String? _clockInTime;
  String? _clockOutTime;

  Future<void> _handleClockIn() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ClockInScreen()),
    );
    if (result != null) setState(() => _clockInTime = result);
  }

  Future<void> _handleClockOut() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ClockOutScreen()),
    );
    if (result != null) setState(() => _clockOutTime = result);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = DummyData.employeeUser;

    return Scaffold(
      appBar: HomeAppBar(
        greeting: 'Good morning,',
        name: user.name,
        initials: user.avatarInitials,
        notificationCount: 2,
        onNotificationTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const NotificationScreen()),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _ClockInCard(
              clockInTime: _clockInTime,
              clockOutTime: _clockOutTime,
              onClockIn: _handleClockIn,
              onClockOut: _handleClockOut,
            ),
            const SizedBox(height: 20),

            // Quick stat row
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: 'Attendance Rate',
                    value: '96%',
                    icon: Icons.event_available_rounded,
                    iconColor: c.primary,
                    iconBg: c.primaryLight,
                    trend: '+2% MoM',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatCard(
                    label: 'Leave Balance',
                    value: '${DummyData.myLeaveBalance.annualRemaining} days',
                    icon: Icons.beach_access_rounded,
                    iconColor: c.infoBlue,
                    iconBg: c.infoBlueBg,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.riskLowBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.shield_outlined, color: c.riskLow, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your Risk Classification', style: TextStyle(fontSize: 12.5, color: c.textSecondary, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text('No flagged violations this month', style: TextStyle(fontSize: 12, color: c.textMuted)),
                      ],
                    ),
                  ),
                  StatusPill.risk(user.riskLevel),
                ],
              ),
            ),

            const SizedBox(height: 24),
            const SectionHeader(title: 'Quick Actions'),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.note_add_outlined,
                    label: 'Apply Leave',
                    color: c.infoBlue,
                    bg: c.infoBlueBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveApplyScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.receipt_long_outlined,
                    label: 'Payroll',
                    color: c.purple,
                    bg: c.purpleBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.insights_outlined,
                    label: 'My PE',
                    color: c.amber,
                    bg: c.amberBg,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PeDetailScreen())),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            SectionHeader(
              title: 'Recent Attendance',
              actionLabel: 'See all',
              onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceHistoryScreen())),
            ),
            ...DummyData.attendanceHistory.take(3).map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AttendanceTile(record: r),
            )),

            const SizedBox(height: 16),
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.amberBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.auto_awesome_rounded, color: c.amber, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '2 training programmes recommended for you this cycle',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: c.textPrimary, height: 1.3),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: c.textMuted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClockInCard extends StatelessWidget {
  final String? clockInTime;
  final String? clockOutTime;
  final VoidCallback onClockIn;
  final VoidCallback onClockOut;

  const _ClockInCard({
    required this.clockInTime,
    required this.clockOutTime,
    required this.onClockIn,
    required this.onClockOut,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasClockedIn = clockInTime != null;
    final hasClockedOut = clockOutTime != null;
    final statusLabel = hasClockedOut ? 'Day Complete' : hasClockedIn ? 'Clocked In' : 'Not Clocked In';
    final timeLabel = hasClockedOut
        ? '$clockInTime  →  $clockOutTime'
        : hasClockedIn
            ? clockInTime!
            : '— : — — AM';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: c.kpiGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [c.shadowTinted()],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat('EEE, d MMMM yyyy').format(DateTime.now()),
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.circle, size: 7, color: Colors.white),
                    const SizedBox(width: 5),
                    Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            timeLabel,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 1, fontFeatures: [FontFeature.tabularFigures()]),
          ),
          const SizedBox(height: 2),
          Text(
            hasClockedOut
                ? 'Great work today — see you tomorrow!'
                : hasClockedIn
                    ? 'Tap below to verify location before you leave'
                    : 'Tap below to verify location, network & device',
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
          ),
          const SizedBox(height: 18),
          if (!hasClockedOut)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: hasClockedIn ? onClockOut : onClockIn,
                icon: Icon(hasClockedIn ? Icons.logout_rounded : Icons.fingerprint_rounded, size: 20),
                label: Text(hasClockedIn ? 'Clock Out Now' : 'Clock In Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: c.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceTile extends StatelessWidget {
  final AttendanceRecord record;
  const _AttendanceTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.calendar_today_rounded, size: 16, color: c.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.date, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(
                  '${record.clockIn}${record.clockOut != null ? '  →  ${record.clockOut}' : ''}',
                  style: TextStyle(fontSize: 12, color: c.textMuted, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ],
            ),
          ),
          StatusPill.attendance(record.status),
        ],
      ),
    );
  }
}