import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../connection/analytics_service.dart';
import '../model/models.dart';
import '../utility/pdf_report_builder.dart';
import 'employee_controller.dart';

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package). Shared by the full Analytics screen and
/// the HR dashboard's summary cards, so both read the same real numbers
/// instead of one being wired and the other still showing dummy data.
class AnalyticsController extends ChangeNotifier {
  String period = 'This Week';

  // Export Reports' own month filter — deliberately separate from `period`
  // (which drives the live dashboard above it). Report *labels* reflect the
  // chosen month; the figures behind them still come from whatever `period`
  // last loaded, since real per-month aggregation queries aren't wired yet
  // (TODO: Phase where seed data covers a full year — wire AnalyticsService
  // methods that take an explicit month range instead of reusing `period`,
  // and drop the "illustrative" labels on the breakdown tables below once
  // there's enough real data to fill them honestly).
  DateTime exportMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void setExportMonth(DateTime month) {
    exportMonth = DateTime(month.year, month.month, 1);
    notifyListeners();
  }

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

  // Raw figures behind the summary sentences above — kept alongside them so
  // report exports (PDF/CSV) can show real numbers instead of re-parsing
  // formatted text.
  double payrollTotal = 0;
  int payrollEmployeeCount = 0;
  int highSeverityCount = 0;
  double? avgPeScore;
  int peEvaluationCount = 0;

  bool loading = false;
  String? errorMessage;

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
    errorMessage = null;
    notifyListeners();

    try {
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
    } catch (e) {
      errorMessage = 'Could not load analytics: $e';
    }

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
    payrollTotal = payroll.total;
    payrollEmployeeCount = payroll.employeeCount;
    payrollSummary = payroll.employeeCount == 0
        ? 'No payroll has been generated for this month yet.'
        : 'Total deductions this cycle: RM ${payroll.total.toStringAsFixed(2)} across ${payroll.employeeCount} employees.';

    highSeverityCount = await AnalyticsService.fetchHighSeverityAnomalyCount(start: start, endExclusive: endExclusive);
    anomalySummary = '$flaggedEvents anomaly event(s) logged, $highSeverityCount high severity.';

    final avgPe = await AnalyticsService.fetchAveragePeScoreThisYear();
    avgPeScore = avgPe.average;
    peEvaluationCount = avgPe.count;
    peSummary = avgPe.average == null
        ? 'No performance evaluations recorded yet this year.'
        : 'Average weighted PE score across recorded evaluations: ${avgPe.average!.toStringAsFixed(1)}/100.';
  }

  /// Cheap targeted refresh for just the pending-leave badge — called after
  /// a leave decision elsewhere in the app. HrHomeScreen only calls the
  /// full `load()` once (IndexedStack keeps it mounted, so its initState
  /// never re-runs), so without this the Dashboard's Approvals badge and
  /// "Pending Approvals" card stay stuck at whatever count they had on
  /// first load, even after HR approves/rejects requests elsewhere.
  Future<void> refreshPendingLeaveCount() async {
    try {
      pendingLeaveCount = await AnalyticsService.fetchPendingLeaveCount();
      notifyListeners();
    } catch (_) {
      // Best-effort — worst case the badge just doesn't update until the
      // next full load().
    }
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

  static String _csvField(String value) {
    // Quote any field containing a comma, quote, or newline, doubling
    // embedded quotes — the standard CSV escaping rule (RFC 4180).
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _csvRow(List<String> fields) => '${fields.map(_csvField).join(',')}\r\n';

  static final _monthYearFormat = DateFormat('MMMM yyyy');
  String get _exportMonthLabel => _monthYearFormat.format(exportMonth);

  /// Builds the real file behind each report tile's "Download" action.
  /// Headline figures reuse this controller's real already-loaded numbers;
  /// see `exportMonth`'s doc comment for why they're not yet filtered to
  /// the specific chosen month.
  String csvFor(String reportTitle) {
    final buffer = StringBuffer();
    switch (reportTitle) {
      case 'Monthly Attendance Summary':
        buffer.write(_csvRow(['Metric', 'Value']));
        buffer.write(_csvRow(['Month', _exportMonthLabel]));
        buffer.write(_csvRow(['Attendance Rate', '${(attendanceRate * 100).toInt()}%']));
        buffer.write(_csvRow(['Late Arrivals', '$lateArrivals']));
        buffer.write(_csvRow(['Flagged Events', '$flaggedEvents']));
        buffer.write(_csvRow(['Total Employees', '$totalEmployees']));
        if (topLateEmployees.isNotEmpty) {
          buffer.write(_csvRow([]));
          buffer.write(_csvRow(['Top Late Employees', 'Department', 'Late Count']));
          for (final e in topLateEmployees) {
            buffer.write(_csvRow([e.name, e.department, '${e.count}']));
          }
        }
        break;
      case 'Leave Utilisation Report':
        buffer.write(_csvRow(['Metric', 'Value']));
        buffer.write(_csvRow(['Month', _exportMonthLabel]));
        buffer.write(_csvRow(['Pending Leave Applications', '$pendingLeaveCount']));
        buffer.write(_csvRow(['Employees On Leave Today', '$onLeaveToday']));
        break;
      case 'Payroll Deduction Report':
        buffer.write(_csvRow(['Metric', 'Value']));
        buffer.write(_csvRow(['Month', _exportMonthLabel]));
        buffer.write(_csvRow(['Summary', payrollSummary]));
        break;
      case 'Suspicious Activity Report':
        buffer.write(_csvRow(['Metric', 'Value']));
        buffer.write(_csvRow(['Month', _exportMonthLabel]));
        buffer.write(_csvRow(['Flagged Events', '$flaggedEvents']));
        buffer.write(_csvRow(['Flagged Today', '$flaggedToday']));
        break;
      case 'Annual PE Summary':
        buffer.write(_csvRow(['Metric', 'Value']));
        buffer.write(_csvRow(['Summary', peSummary]));
        break;
      default:
        buffer.write(_csvRow(['Report', reportTitle]));
        buffer.write(_csvRow(['Value', summaryFor(reportTitle)]));
    }
    return buffer.toString();
  }

  static final _generatedDate = DateFormat('d MMM yyyy');

  /// Builds the branded PDF behind each report tile's "Download PDF"
  /// action. Headline/metric figures reuse this controller's real
  /// already-loaded numbers; per-department and per-employee breakdown
  /// tables are illustrative placeholder rows (matching the Report Layout
  /// Mockups artifact) rather than new queries — see PdfReportBuilder's
  /// doc comment and `exportMonth`'s doc comment for why that scope was
  /// chosen for this pass.
  Future<Uint8List> pdfBytesFor(String reportTitle) {
    final generatedBy = 'Generated ${_generatedDate.format(DateTime.now())}';
    switch (reportTitle) {
      case 'Monthly Attendance Summary':
        return PdfReportBuilder.build(
          doctype: 'Analytics Export · Monthly Attendance Summary',
          title: 'Company-Wide Attendance — $_exportMonthLabel',
          subtitle: 'Month: $_exportMonthLabel',
          headlineValue: '${(attendanceRate * 100).toInt()}%',
          headlineLabel: 'Company-wide attendance rate',
          metrics: [
            ('Late Arrivals', '$lateArrivals'),
            ('Flagged Events', '$flaggedEvents'),
            ('Total Employees', '$totalEmployees'),
          ],
          sections: [
            PdfReportSection.groupedByDepartment(
              label: 'Per-Department Breakdown, by Employee (illustrative)',
              headers: ['Employee', 'On-Time', 'Late', 'Flagged', 'Rate'],
              numericColumns: const [1, 2, 3, 4],
              groups: const [
                PdfDeptGroup(department: 'Engineering', summary: '142 on-time, 11 late, 3 flagged — 93%', employeeRows: [
                  ['Nur Aisyah binti Rahman', '19', '1', '0', '95%'],
                  ['Muthu Kumar a/l Selvam', '17', '3', '1', '81%'],
                  ['Tan Wei Ling', '20', '0', '0', '100%'],
                ]),
                PdfDeptGroup(department: 'Sales', summary: '98 on-time, 14 late, 5 flagged — 88%', employeeRows: [
                  ['Farah Izzati binti Kamal', '16', '4', '1', '80%'],
                  ['Ryan Tan Zhi Hao', '18', '2', '0', '90%'],
                ]),
                PdfDeptGroup(department: 'HR', summary: '30 on-time, 1 late, 0 flagged — 97%', employeeRows: [
                  ['Aisyah Rahman', '20', '1', '0', '95%'],
                ]),
                PdfDeptGroup(department: 'Design', summary: '54 on-time, 6 late, 2 flagged — 90%', employeeRows: [
                  ['Chong Mei Yi', '18', '2', '1', '86%'],
                  ['Aravind Balasubramaniam', '19', '1', '0', '95%'],
                ]),
                PdfDeptGroup(department: 'Operations', summary: '76 on-time, 9 late, 4 flagged — 89%', employeeRows: [
                  ['Nurul Huda binti Osman', '17', '3', '1', '83%'],
                  ['Kevin Wong Jun Kai', '19', '1', '1', '90%'],
                ]),
                PdfDeptGroup(department: 'Finance', summary: '41 on-time, 3 late, 1 flagged — 95%', employeeRows: [
                  ['Priya Devi a/p Suresh', '20', '0', '0', '100%'],
                ]),
              ],
            ),
          ],
          generatedBy: generatedBy,
        );

      case 'Leave Utilisation Report':
        return PdfReportBuilder.build(
          doctype: 'Analytics Export · Leave Utilisation Report',
          title: 'Leave Utilisation — $_exportMonthLabel',
          subtitle: 'Month: $_exportMonthLabel',
          headlineValue: '$pendingLeaveCount',
          headlineLabel: 'pending applications company-wide',
          metrics: [
            ('Employees On Leave Today', '$onLeaveToday'),
          ],
          sections: [
            PdfReportSection.groupedByDepartment(
              label: 'Per-Department Balances, by Employee (illustrative)',
              headers: ['Employee', 'Annual (used/total)', 'Medical (used/total)', 'Emergency (used/total)'],
              centerColumns: const [1, 2, 3],
              groups: const [
                PdfDeptGroup(department: 'Engineering', summary: '168 / 224 annual used company-wide', employeeRows: [
                  ['Nur Aisyah binti Rahman', '6 / 8', '1 / 14', '0 / 3'],
                  ['Muthu Kumar a/l Selvam', '4 / 8', '0 / 14', '1 / 3'],
                  ['Tan Wei Ling', '8 / 8', '2 / 14', '0 / 3'],
                ]),
                PdfDeptGroup(department: 'Sales', summary: '120 / 168 annual used company-wide', employeeRows: [
                  ['Farah Izzati binti Kamal', '5 / 8', '3 / 14', '1 / 3'],
                  ['Ryan Tan Zhi Hao', '3 / 8', '1 / 14', '0 / 3'],
                ]),
                PdfDeptGroup(department: 'HR', summary: '38 / 56 annual used company-wide', employeeRows: [
                  ['Aisyah Rahman', '5 / 8', '0 / 14', '0 / 3'],
                ]),
                PdfDeptGroup(department: 'Design', summary: '64 / 96 annual used company-wide', employeeRows: [
                  ['Chong Mei Yi', '6 / 8', '2 / 14', '0 / 3'],
                  ['Aravind Balasubramaniam', '2 / 8', '0 / 14', '1 / 3'],
                ]),
              ],
            ),
          ],
          generatedBy: generatedBy,
        );

      case 'Payroll Deduction Report':
        return PdfReportBuilder.build(
          doctype: 'Analytics Export · Payroll Deduction Report',
          title: 'Payroll Deductions — $_exportMonthLabel',
          subtitle: '$payrollEmployeeCount employees processed',
          headlineValue: 'RM ${payrollTotal.toStringAsFixed(2)}',
          headlineLabel: 'Total deductions this run',
          sections: [
            PdfReportSection.table(
              label: 'Per-Employee Breakdown (illustrative, top 5 by deduction)',
              headers: ['Name', 'Late', 'Absent', 'Deductions', 'Net Pay'],
              numericColumns: const [1, 2, 3, 4],
              rows: const [
                ['Nur Aisyah binti Rahman', '5', '1', 'RM 245', 'RM 4,255'],
                ['Muthu Kumar a/l Selvam', '3', '2', 'RM 315', 'RM 3,685'],
                ['Tan Wei Ling', '6', '0', 'RM 150', 'RM 4,850'],
                ['Farah Izzati binti Kamal', '2', '1', 'RM 170', 'RM 3,930'],
                ['Ryan Tan Zhi Hao', '4', '0', 'RM 100', 'RM 4,400'],
              ],
            ),
          ],
          generatedBy: generatedBy,
        );

      case 'Suspicious Activity Report':
        return PdfReportBuilder.build(
          doctype: 'Analytics Export · Suspicious Activity Report',
          title: 'Suspicious Activity — $_exportMonthLabel',
          subtitle: 'Month: $_exportMonthLabel',
          headlineValue: '$flaggedEvents',
          headlineLabel: 'anomalies logged, $highSeverityCount high severity',
          metrics: [
            ('Flagged Today', '$flaggedToday'),
          ],
          sections: [
            PdfReportSection.table(
              label: 'Flagged Events (illustrative)',
              headers: ['Employee', 'Type', 'Severity', 'Date', 'Reviewed'],
              centerColumns: const [1, 2, 3, 4],
              rows: const [
                ['Muthu Kumar a/l Selvam', 'Shared Device', 'High', '14 Aug', '—'],
                ['Tan Wei Ling', 'Out of Zone', 'Medium', '19 Aug', 'Yes'],
                ['Nur Aisyah binti Rahman', 'WiFi Mismatch', 'Low', '22 Aug', '—'],
                ['Farah Izzati binti Kamal', 'Early Clock-Out', 'Low', '25 Aug', 'Yes'],
                ['Ryan Tan Zhi Hao', 'Out of Zone', 'Medium', '27 Aug', '—'],
              ],
            ),
          ],
          generatedBy: generatedBy,
        );

      case 'Annual PE Summary':
        return PdfReportBuilder.build(
          doctype: 'Analytics Export · Annual PE Summary',
          title: 'Annual Performance Evaluation Summary — ${DateTime.now().year}',
          subtitle: '$peEvaluationCount evaluations completed',
          headlineValue: avgPeScore?.toStringAsFixed(1) ?? '—',
          headlineLabel: '/ 100 average weighted score, company-wide',
          sections: [
            PdfReportSection.groupedByDepartment(
              label: 'Per-Department, by Employee (illustrative)',
              headers: ['Employee', 'Weighted Score', 'Below-Threshold KPIs'],
              numericColumns: const [1, 2],
              groups: const [
                PdfDeptGroup(department: 'Engineering', summary: 'avg 79.1, 6 below-threshold KPIs', employeeRows: [
                  ['Nur Aisyah binti Rahman', '85.2', '0'],
                  ['Muthu Kumar a/l Selvam', '71.4', '2'],
                  ['Tan Wei Ling', '80.6', '1'],
                ]),
                PdfDeptGroup(department: 'Sales', summary: 'avg 71.8, 14 below-threshold KPIs', employeeRows: [
                  ['Farah Izzati binti Kamal', '68.0', '3'],
                  ['Ryan Tan Zhi Hao', '75.5', '1'],
                ]),
                PdfDeptGroup(department: 'HR', summary: 'avg 83.4, 1 below-threshold KPI', employeeRows: [
                  ['Aisyah Rahman', '83.4', '1'],
                ]),
                PdfDeptGroup(department: 'Design', summary: 'avg 75.0, 5 below-threshold KPIs', employeeRows: [
                  ['Chong Mei Yi', '77.2', '1'],
                  ['Aravind Balasubramaniam', '72.8', '2'],
                ]),
                PdfDeptGroup(department: 'Operations', summary: 'avg 77.6, 8 below-threshold KPIs', employeeRows: [
                  ['Nurul Huda binti Osman', '74.0', '2'],
                  ['Kevin Wong Jun Kai', '81.2', '1'],
                ]),
                PdfDeptGroup(department: 'Finance', summary: 'avg 81.2, 3 below-threshold KPIs', employeeRows: [
                  ['Priya Devi a/p Suresh', '81.2', '0'],
                ]),
              ],
            ),
          ],
          generatedBy: generatedBy,
        );

      default:
        return PdfReportBuilder.build(
          doctype: 'Analytics Export',
          title: reportTitle,
          subtitle: 'Month: $_exportMonthLabel',
          headlineValue: '—',
          headlineLabel: summaryFor(reportTitle),
          sections: const [],
          generatedBy: generatedBy,
        );
    }
  }
}

final analyticsController = AnalyticsController();
