import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the `payroll_summaries` and `payroll_deduction_items`
/// tables. Holds no state of its own — PayrollController owns app-facing
/// state.
class PayrollService {
  PayrollService._();
  static final _client = Supabase.instance.client;

  static String _monthKey(DateTime month) => DateTime(month.year, month.month, 1).toIso8601String().split('T').first;

  static Future<Map<String, dynamic>?> fetchMyCurrentMonth() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    return await _client
        .from('payroll_summaries')
        .select('*, payroll_deduction_items(*)')
        .eq('user_id', uid)
        .eq('pay_month', _monthKey(DateTime.now()))
        .maybeSingle();
  }

  static Future<List<Map<String, dynamic>>> fetchMyHistory() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('payroll_summaries')
        .select('*, payroll_deduction_items(*)')
        .eq('user_id', uid)
        .order('pay_month', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// HR — every generated summary for a given month, joined with the
  /// employee's name.
  static Future<List<Map<String, dynamic>>> fetchAllForMonth(DateTime month) async {
    final rows = await _client
        .from('payroll_summaries')
        .select('*, profiles(name), payroll_deduction_items(*)')
        .eq('pay_month', _monthKey(month));
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Generates (or regenerates) every active employee's payroll summary
  /// for the given month. Deducts for:
  ///  - late arrivals (policy_settings.late_deduction x count of 'late'
  ///    attendance_records that month)
  ///  - unexplained absences (policy_settings.absent_deduction x count of
  ///    weekdays with no attendance record, no public holiday, and no
  ///    approved leave application covering that day) — days covered by
  ///    an approved leave are explicitly excluded, they're not absences.
  ///  - approved unpaid leave (policy_settings.unpaid_leave_daily_rate x
  ///    count of weekdays covered by an approved 'unpaid' leave
  ///    application) — unlike annual/medical/emergency, unpaid leave has
  ///    no balance pool to draw from, so instead of just excusing the
  ///    absence it costs the employee a day's pay.
  ///  - risk_score_penalties queued for this pay_month (percent x
  ///    base_salary) — inserted by apply_risk_deduction() the instant an
  ///    employee's risk score hits 0 (migration 0032). Re-queried from that
  ///    ledger table each time rather than a one-shot flag, so it survives
  ///    a regeneration of this month the same way late/absence/unpaid-leave
  ///    do (all re-derived from source data, never a "already applied"
  ///    flag that a regen could silently lose).
  /// Only counts days up to today (never penalises days in the month that
  /// haven't happened yet), and never before the employee's hire date.
  static Future<int> generateForMonth(DateTime month) async {
    final policy = await _client
        .from('policy_settings')
        .select('late_deduction, absent_deduction, unpaid_leave_daily_rate')
        .eq('id', 1)
        .single();
    final lateDeduction = (policy['late_deduction'] as num).toDouble();
    final absentDeduction = (policy['absent_deduction'] as num).toDouble();
    final unpaidLeaveDailyRate = (policy['unpaid_leave_daily_rate'] as num).toDouble();

    final employees = await _client.from('profiles').select('id, base_salary, hire_date').eq('is_active', true);

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEndExclusive = DateTime(month.year, month.month + 1, 1);
    final monthStartKey = monthStart.toIso8601String().split('T').first;
    final monthEndKey = monthEndExclusive.toIso8601String().split('T').first;
    final today = DateTime.now();
    final lastCountableDay = monthEndExclusive.isAfter(today) ? DateTime(today.year, today.month, today.day) : monthEndExclusive.subtract(const Duration(days: 1));

    final holidayRows = await _client
        .from('company_events')
        .select('event_date')
        .eq('event_type', 'public_holiday')
        // event_date is a timestamptz written with .toUtc() (CalendarService),
        // so bound the month in the same terms and read it back .toLocal() —
        // a holiday at local midnight is the previous day in UTC, which
        // otherwise shifted it onto the wrong payroll day.
        .gte('event_date', monthStart.toUtc().toIso8601String())
        .lt('event_date', monthEndExclusive.toUtc().toIso8601String());
    final holidayDates = List<Map<String, dynamic>>.from(holidayRows).map((r) => DateTime.parse(r['event_date'] as String).toLocal()).toSet();

    var generatedCount = 0;
    for (final emp in List<Map<String, dynamic>>.from(employees)) {
      final uid = emp['id'] as String;
      final baseSalary = (emp['base_salary'] as num?)?.toDouble();
      if (baseSalary == null) continue; // no salary on file - nothing to generate
      final hireDate = DateTime.tryParse(emp['hire_date'] as String? ?? '');

      final attendanceRows = await _client
          .from('attendance_records')
          .select('work_date, status')
          .eq('user_id', uid)
          .gte('work_date', monthStartKey)
          .lt('work_date', monthEndKey);
      final attendance = List<Map<String, dynamic>>.from(attendanceRows);
      final lateCount = attendance.where((r) => r['status'] == 'late').length;
      final attendedDates = attendance.map((r) => DateTime.parse(r['work_date'] as String)).toSet();

      final approvedLeaveRows = await _client
          .from('leave_applications')
          .select('start_date, end_date, leave_type')
          .eq('user_id', uid)
          .eq('status', 'approved')
          .lte('start_date', monthEndKey)
          .gte('end_date', monthStartKey);
      final leaveRanges = List<Map<String, dynamic>>.from(approvedLeaveRows)
          .map((r) => (
                DateTime.parse(r['start_date'] as String),
                DateTime.parse(r['end_date'] as String),
                r['leave_type'] as String,
              ))
          .toList();
      bool onApprovedLeave(DateTime d) => leaveRanges.any((r) => !d.isBefore(r.$1) && !d.isAfter(r.$2));

      // Absences HR excused after an appeal (migration 0044) aren't deducted.
      final excusedRows = await _client
          .from('anomaly_events')
          .select('event_date')
          .eq('user_id', uid)
          .eq('type', 'unexplained_absence')
          .not('reverted_at', 'is', null)
          .gte('event_date', monthStartKey)
          .lt('event_date', monthEndKey);
      final excusedDates = List<Map<String, dynamic>>.from(excusedRows)
          .map((r) => DateTime.parse(r['event_date'] as String))
          .toSet();
      bool excused(DateTime d) => excusedDates.any((e) => e.year == d.year && e.month == d.month && e.day == d.day);
      bool onUnpaidLeave(DateTime d) =>
          leaveRanges.any((r) => r.$3 == 'unpaid' && !d.isBefore(r.$1) && !d.isAfter(r.$2));

      var absentCount = 0;
      var unpaidLeaveCount = 0;
      for (var d = monthStart; !d.isAfter(lastCountableDay); d = d.add(const Duration(days: 1))) {
        if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) continue;
        if (holidayDates.any((h) => h.year == d.year && h.month == d.month && h.day == d.day)) continue;
        if (hireDate != null && d.isBefore(DateTime(hireDate.year, hireDate.month, hireDate.day))) continue;
        if (attendedDates.any((a) => a.year == d.year && a.month == d.month && a.day == d.day)) continue;
        if (onUnpaidLeave(d)) {
          unpaidLeaveCount++;
          continue;
        }
        if (onApprovedLeave(d) || excused(d)) continue;
        absentCount++;
      }

      final riskPenaltyRows = await _client
          .from('risk_score_penalties')
          .select('percent')
          .eq('user_id', uid)
          .eq('pay_month', monthStartKey);
      final riskPenaltyPercent = List<Map<String, dynamic>>.from(riskPenaltyRows)
          .fold<double>(0, (sum, r) => sum + (r['percent'] as num).toDouble());

      final lateAmount = lateCount * lateDeduction;
      final absentAmount = absentCount * absentDeduction;
      final unpaidLeaveAmount = unpaidLeaveCount * unpaidLeaveDailyRate;
      final riskPenaltyAmount = baseSalary * riskPenaltyPercent / 100;
      final deductionAmount = lateAmount + absentAmount + unpaidLeaveAmount + riskPenaltyAmount;
      final netPay = baseSalary - deductionAmount;

      final upserted = await _client
          .from('payroll_summaries')
          .upsert({
            'user_id': uid,
            'pay_month': monthStartKey,
            'base_salary': baseSalary,
            'deductions': deductionAmount,
            'net_pay': netPay,
          }, onConflict: 'user_id,pay_month')
          .select()
          .single();

      final payrollId = upserted['id'] as int;
      // Regenerate is idempotent - clear any previous items before
      // inserting the current computation's items.
      await _client.from('payroll_deduction_items').delete().eq('payroll_id', payrollId);
      final items = <Map<String, dynamic>>[];
      if (lateCount > 0) {
        items.add({
          'payroll_id': payrollId,
          'label': 'Late arrival ($lateCount occurrence${lateCount > 1 ? 's' : ''})',
          'amount': lateAmount,
        });
      }
      if (absentCount > 0) {
        items.add({
          'payroll_id': payrollId,
          'label': 'Unexplained absence ($absentCount day${absentCount > 1 ? 's' : ''})',
          'amount': absentAmount,
        });
      }
      if (unpaidLeaveCount > 0) {
        items.add({
          'payroll_id': payrollId,
          'label': 'Unpaid leave ($unpaidLeaveCount day${unpaidLeaveCount > 1 ? 's' : ''})',
          'amount': unpaidLeaveAmount,
        });
      }
      if (riskPenaltyPercent > 0) {
        items.add({
          'payroll_id': payrollId,
          'label': 'Risk score penalty (${riskPenaltyPercent.toStringAsFixed(0)}% of salary)',
          'amount': riskPenaltyAmount,
        });
      }
      if (items.isNotEmpty) {
        await _client.from('payroll_deduction_items').insert(items);
      }
      generatedCount++;
    }
    return generatedCount;
  }
}
