import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/models.dart';

/// One system-measured KPI result: the 0-100 [score] (null when there isn't
/// enough data yet to say anything honest) and a one-line [detail] showing
/// the working behind it, so HR can see why the number is what it is.
class PeMetric {
  final double? score;
  final String detail;
  const PeMetric(this.score, this.detail);
}

/// Measures the KPIs this system can genuinely observe about an employee,
/// year-to-date — attendance, punctuality, conduct and training. It can't
/// see work output (code shipped, deals closed), so templates keep those
/// KPIs as `manual`: HR scores them from whatever other system holds that
/// data. See KpiMetricSource.
///
/// The fetch lives in [measure]; every formula is a separate pure static
/// function so it can be tested without a backend.
class PeMetricsService {
  PeMetricsService._();
  static final _client = Supabase.instance.client;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static Future<Map<String, PeMetric>> measure(String userUuid) async {
    final today = _dateOnly(DateTime.now());
    final yearStart = DateTime(today.year, 1, 1);
    final yearStartKey = _key(yearStart);

    final profile = await _client
        .from('profiles')
        .select('hire_date, risk_score')
        .eq('id', userUuid)
        .maybeSingle();
    final hireDate = DateTime.tryParse(profile?['hire_date'] as String? ?? '');

    final attendanceRows = List<Map<String, dynamic>>.from(
      await _client
          .from('attendance_records')
          .select('work_date, status')
          .eq('user_id', userUuid)
          .gte('work_date', yearStartKey),
    );

    final leaveRows = List<Map<String, dynamic>>.from(
      await _client
          .from('leave_applications')
          .select('start_date, end_date')
          .eq('user_id', userUuid)
          .eq('status', 'approved')
          .gte('end_date', yearStartKey),
    );

    final holidayRows = List<Map<String, dynamic>>.from(
      await _client
          .from('company_events')
          .select('event_date')
          .eq('event_type', 'public_holiday')
          .gte('event_date', yearStart.toUtc().toIso8601String()),
    );

    // Absences HR excused after an appeal count like a day of leave.
    final excusedRows = List<Map<String, dynamic>>.from(
      await _client
          .from('anomaly_events')
          .select('event_date')
          .eq('user_id', userUuid)
          .eq('type', 'unexplained_absence')
          .not('reverted_at', 'is', null)
          .gte('event_date', yearStartKey),
    );

    final enrollmentRows = List<Map<String, dynamic>>.from(
      await _client
          .from('training_enrollments')
          .select('is_completed, performance_score')
          .eq('user_id', userUuid),
    );

    // event_date is a timestamptz written with .toUtc() (see CalendarService),
    // so read it back with .toLocal() or a holiday lands a day early.
    final holidays = holidayRows
        .map(
          (r) => _dateOnly(DateTime.parse(r['event_date'] as String).toLocal()),
        )
        .toSet();
    final leaveRanges = leaveRows
        .map(
          (r) => (
            _dateOnly(DateTime.parse(r['start_date'] as String)),
            _dateOnly(DateTime.parse(r['end_date'] as String)),
          ),
        )
        .toList()
      ..addAll(excusedRows.map((r) {
        final d = _dateOnly(DateTime.parse(r['event_date'] as String));
        return (d, d);
      }));
    final attendedDates = attendanceRows
        .map((r) => _dateOnly(DateTime.parse(r['work_date'] as String)))
        .toSet();

    final from = (hireDate != null && _dateOnly(hireDate).isAfter(yearStart))
        ? _dateOnly(hireDate)
        : yearStart;

    return {
      KpiMetricSource.attendance: attendance(
        from: from,
        // Yesterday, not today: today's clock-in may simply not have
        // happened yet, which shouldn't read as an absence.
        to: today.subtract(const Duration(days: 1)),
        attendedDates: attendedDates,
        holidays: holidays,
        leaveRanges: leaveRanges,
      ),
      KpiMetricSource.punctuality: punctuality(
        onTime: attendanceRows.where((r) => r['status'] == 'on_time').length,
        late: attendanceRows.where((r) => r['status'] == 'late').length,
      ),
      KpiMetricSource.conduct: conduct(
        (profile?['risk_score'] as num?)?.toInt(),
      ),
      KpiMetricSource.training: training(enrollmentRows),
    };
  }

  /// Share of expected working days (weekdays that aren't a public holiday
  /// or covered by approved leave) the employee has an attendance record
  /// for, from [from] to [to] inclusive. A flagged clock-in still counts as
  /// attending — whether it was legitimate is Conduct's job, not this one's.
  static PeMetric attendance({
    required DateTime from,
    required DateTime to,
    required Set<DateTime> attendedDates,
    required Set<DateTime> holidays,
    required List<(DateTime, DateTime)> leaveRanges,
  }) {
    var expected = 0;
    var present = 0;
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      if (d.weekday == DateTime.saturday || d.weekday == DateTime.sunday) {
        continue;
      }
      if (holidays.contains(d)) {
        continue;
      }
      if (leaveRanges.any((r) => !d.isBefore(r.$1) && !d.isAfter(r.$2))) {
        continue;
      }
      expected++;
      if (attendedDates.contains(d)) {
        present++;
      }
    }
    if (expected == 0) {
      return const PeMetric(null, 'Not enough working days yet to measure');
    }
    final score = (present / expected * 100).clamp(0, 100).toDouble();
    return PeMetric(
      score,
      '$present of $expected working days attended this year',
    );
  }

  /// Of the clock-ins that happened, the share that were on time.
  static PeMetric punctuality({required int onTime, required int late}) {
    final total = onTime + late;
    if (total == 0) {
      return const PeMetric(null, 'No clock-ins recorded yet this year');
    }
    return PeMetric(
      onTime / total * 100,
      '$onTime of $total clock-ins on time',
    );
  }

  /// The employee's current risk score. It resets periodically (see
  /// policy_settings.risk_reset_period_months), so this reflects recent
  /// conduct rather than a whole-year tally.
  static PeMetric conduct(int? riskScore) {
    if (riskScore == null) return const PeMetric(null, 'No risk score on file');
    return PeMetric(
      riskScore.clamp(0, 100).toDouble(),
      'Current risk score: $riskScore / 100',
    );
  }

  /// Completion rate across the employee's enrolments, blended 50/50 with
  /// their average quiz/assessment score when any have been recorded.
  static PeMetric training(List<Map<String, dynamic>> enrollments) {
    if (enrollments.isEmpty) {
      return const PeMetric(null, 'Not enrolled in any training yet');
    }
    final completed = enrollments
        .where((e) => e['is_completed'] == true)
        .length;
    final completionRate = completed / enrollments.length * 100;
    final scores = enrollments
        .map((e) => (e['performance_score'] as num?)?.toDouble())
        .whereType<double>()
        .toList();
    if (scores.isEmpty) {
      return PeMetric(
        completionRate,
        '$completed of ${enrollments.length} programmes completed',
      );
    }
    final avgScore = scores.reduce((a, b) => a + b) / scores.length;
    return PeMetric(
      completionRate * 0.5 + avgScore * 0.5,
      '$completed of ${enrollments.length} programmes completed, avg score ${avgScore.toStringAsFixed(0)}',
    );
  }
}
