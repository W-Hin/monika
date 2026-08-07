import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../connection/analytics_service.dart';
import '../model/models.dart';
import 'employee_controller.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package). Shared by the full Analytics screen and
/// the HR dashboard's summary cards, so both read the same real numbers
/// instead of one being wired and the other still showing dummy data.
class AnalyticsController extends ChangeNotifier {
  String period = 'This Week';

  double attendanceRate = 0; // fraction of logged clock-ins that were on_time or late (not flagged)
  int lateArrivals = 0;
  int flaggedEvents = 0; // for the selected period
  int flaggedToday = 0; // always today, regardless of period - for dashboard cards
  int onLeaveToday = 0;
  int pendingLeaveCount = 0;

  List<double> weeklyTrend = List.filled(7, 0);
  List<String> weekdayLabels = List.filled(7, '');

  Map<RiskLevel, int> riskDistribution = {RiskLevel.low: 0, RiskLevel.medium: 0, RiskLevel.high: 0};
  int totalEmployees = 0;

  /// (name, department, lateCount), sorted descending, top 5.
  List<({String name, String department, int count})> topLateEmployees = [];

  String attendanceSummary = '';
  String leaveSummary = '';
  String payrollSummary = '';
  String anomalySummary = '';
  String peSummary = '';

  bool loading = false;

  static final _weekdayFormat = DateFormat('E');

  /// Attendance Rate and Late Arrivals deliberately measure "of the
  /// clock-ins that were logged, what fraction were on time / how many
  /// were late" - not "of the whole workforce, who was present." A true
  /// presence/absence rate needs a working-days calendar (which days an
  /// employee was expected to clock in at all) that isn't wired up yet -
  /// same limitation already flagged for Payroll's missing absence
  /// deduction. This is the same honest, computable metric applied
  /// consistently rather than a different guessed-at one here.
  (DateTime, DateTime) _rangeFor(String period) {
    final now = DateTime.now();
    switch (period) {
      case 'This Month':
        return (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 1));
      case 'This Quarter':
        final qStartMonth = ((now.month - 1) ~/ 3) * 3 + 1;
        return (DateTime(now.year, qStartMonth, 1), DateTime(now.year, qStartMonth + 3, 1));
      default: // This Week
        final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        return (start, start.add(const Duration(days: 7)));
    }
  }

  Future<void> load({String? period}) async {
    if (period != null) this.period = period;
    loading = true;
    notifyListeners();

    final (start, endExclusive) = _rangeFor(this.period);

    final attendanceRows = await AnalyticsService.fetchAttendanceRecords(start: start, endExclusive: endExclusive);
    final anomalyCount = await AnalyticsService.fetchAnomalyCount(start: start, endExclusive: endExclusive);
    final onLeave = await AnalyticsService.fetchOnLeaveTodayCount();
    final pending = await AnalyticsService.fetchPendingLeaveCount();

    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayCount = await AnalyticsService.fetchAnomalyCount(start: todayStart, endExclusive: todayStart.add(const Duration(days: 1)));

    final onTimeOrLate = attendanceRows.where((r) => r['status'] == 'on_time' || r['status'] == 'late').length;
    attendanceRate = attendanceRows.isEmpty ? 0 : onTimeOrLate / attendanceRows.length;
    lateArrivals = attendanceRows.where((r) => r['status'] == 'late').length;
    flaggedEvents = anomalyCount;
    flaggedToday = todayCount;
    onLeaveToday = onLeave;
    pendingLeaveCount = pending;

    await _loadWeeklyTrend();
    await _loadRiskDistribution();
    await _loadTopLateEmployees(start, endExclusive);
    await _loadExportSummaries(start, endExclusive);

    loading = false;
    notifyListeners();
  }

  Future<void> _loadWeeklyTrend() async {
    final today = DateTime.now();
    final trendStart = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final trendRows = await AnalyticsService.fetchAttendanceRecords(
      start: trendStart,
      endExclusive: DateTime(today.year, today.month, today.day).add(const Duration(days: 1)),
    );

    weeklyTrend = List.generate(7, (i) {
      final day = trendStart.add(Duration(days: i));
      final key = AnalyticsService.dateKey(day);
      final dayRows = trendRows.where((r) => r['work_date'] == key).toList();
      if (dayRows.isEmpty) return 0.0;
      final onTimeOrLate = dayRows.where((r) => r['status'] == 'on_time' || r['status'] == 'late').length;
      return onTimeOrLate / dayRows.length;
    });
    weekdayLabels = List.generate(7, (i) => _weekdayFormat.format(trendStart.add(Duration(days: i))));
  }

  Future<void> _loadRiskDistribution() async {
    if (employeeController.employees.isEmpty) {
      await employeeController.loadEmployees();
    }
    final counts = {RiskLevel.low: 0, RiskLevel.medium: 0, RiskLevel.high: 0};
    for (final emp in employeeController.employees) {
      counts[emp.risk] = (counts[emp.risk] ?? 0) + 1;
    }
    riskDistribution = counts;
    totalEmployees = employeeController.employees.length;
  }

  Future<void> _loadTopLateEmployees(DateTime start, DateTime endExclusive) async {
    final rows = await AnalyticsService.fetchLateRecordsWithNames(start: start, endExclusive: endExclusive);
    final counts = <String, ({String name, String department, int count})>{};
    for (final row in rows) {
      final uid = row['user_id'] as String;
      final profile = row['profiles'] as Map<String, dynamic>?;
      final name = profile?['name'] as String? ?? 'Unknown';
      final dept = (profile?['departments'] as Map<String, dynamic>?)?['name'] as String? ?? '—';
      final existing = counts[uid];
      counts[uid] = (name: name, department: dept, count: (existing?.count ?? 0) + 1);
    }
    final sorted = counts.values.toList()..sort((a, b) => b.count.compareTo(a.count));
    topLateEmployees = sorted.take(5).toList();
  }

  Future<void> _loadExportSummaries(DateTime start, DateTime endExclusive) async {
    attendanceSummary = 'Average attendance rate this $period: ${(attendanceRate * 100).toInt()}% across $totalEmployees employees.';
    leaveSummary = '$pendingLeaveCount leave application(s) currently pending across all departments.';

    final payroll = await AnalyticsService.fetchPayrollDeductionsThisMonth();
    payrollSummary = payroll.employeeCount == 0
        ? 'No payroll has been generated for this month yet.'
        : 'Total deductions this cycle: RM ${payroll.total.toStringAsFixed(2)} across ${payroll.employeeCount} employees.';

    final highSeverity = await AnalyticsService.fetchHighSeverityAnomalyCount(start: start, endExclusive: endExclusive);
    anomalySummary = '$flaggedEvents anomaly event(s) logged, $highSeverity high severity.';

    final avgPe = await AnalyticsService.fetchAveragePeScoreThisYear();
    peSummary = avgPe == null
        ? 'No performance evaluations recorded yet this year.'
        : 'Average weighted PE score across recorded evaluations: ${avgPe.toStringAsFixed(1)}/100.';
  }

  String summaryFor(String reportTitle) {
    switch (reportTitle) {
      case 'Monthly Attendance Summary':
        return attendanceSummary;
      case 'Leave Utilisation Report':
        return leaveSummary;
      case 'Payroll Deduction Report':
        return payrollSummary;
      case 'Suspicious Activity Report':
        return anomalySummary;
      case 'Annual PE Summary':
        return peSummary;
      default:
        return 'Report generated successfully.';
    }
  }
}

final analyticsController = AnalyticsController();
