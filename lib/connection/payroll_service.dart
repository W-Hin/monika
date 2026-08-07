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
  /// for the given month. Deduction so far covers only late-arrival
  /// occurrences (policy_settings.late_deduction x count of 'late'
  /// attendance_records that month) — there's no reliable source yet for
  /// "days they should have worked but didn't clock in at all" (that
  /// needs a working-days/company-calendar concept that isn't wired up
  /// yet), so absence deduction is deliberately not computed here rather
  /// than guessed at.
  static Future<int> generateForMonth(DateTime month) async {
    final policy = await _client.from('policy_settings').select('late_deduction').eq('id', 1).single();
    final lateDeduction = (policy['late_deduction'] as num).toDouble();

    final employees = await _client.from('profiles').select('id, base_salary').eq('is_active', true);

    final monthStart = DateTime(month.year, month.month, 1);
    final monthEndExclusive = DateTime(month.year, month.month + 1, 1);
    final monthStartKey = monthStart.toIso8601String().split('T').first;
    final monthEndKey = monthEndExclusive.toIso8601String().split('T').first;

    var generatedCount = 0;
    for (final emp in List<Map<String, dynamic>>.from(employees)) {
      final uid = emp['id'] as String;
      final baseSalary = (emp['base_salary'] as num?)?.toDouble();
      if (baseSalary == null) continue; // no salary on file - nothing to generate

      final lateRecords = await _client
          .from('attendance_records')
          .select('id')
          .eq('user_id', uid)
          .eq('status', 'late')
          .gte('work_date', monthStartKey)
          .lt('work_date', monthEndKey);
      final lateCount = List.from(lateRecords).length;
      final deductionAmount = lateCount * lateDeduction;
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
      if (lateCount > 0) {
        await _client.from('payroll_deduction_items').insert({
          'payroll_id': payrollId,
          'label': 'Late arrival ($lateCount occurrence${lateCount > 1 ? 's' : ''})',
          'amount': deductionAmount,
        });
      }
      generatedCount++;
    }
    return generatedCount;
  }
}
