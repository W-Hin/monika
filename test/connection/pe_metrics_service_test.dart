import 'package:flutter_test/flutter_test.dart';
import 'package:monika/connection/pe_metrics_service.dart';

DateTime d(int y, int m, int day) => DateTime(y, m, day);

void main() {
  group('attendance', () {
    // 2026-09-07 is a Monday, so Mon 7th - Fri 11th is a clean 5-day week.
    final from = d(2026, 9, 7);
    final to = d(2026, 9, 11);

    test('counts present weekdays over expected weekdays', () {
      final m = PeMetricsService.attendance(
        from: from,
        to: to,
        attendedDates: {d(2026, 9, 7), d(2026, 9, 8), d(2026, 9, 9), d(2026, 9, 10)},
        holidays: {},
        leaveRanges: [],
      );
      expect(m.score, 80);
    });

    test('weekends, holidays and approved leave are not expected days', () {
      final m = PeMetricsService.attendance(
        from: from,
        to: d(2026, 9, 13), // through Sunday
        attendedDates: {d(2026, 9, 7), d(2026, 9, 8)},
        holidays: {d(2026, 9, 9)},
        leaveRanges: [(d(2026, 9, 10), d(2026, 9, 11))],
      );
      // Only Mon 7th and Tue 8th are expected, and both were attended.
      expect(m.score, 100);
    });

    test('a flagged-but-recorded day still counts as attended', () {
      final m = PeMetricsService.attendance(
        from: d(2026, 9, 7),
        to: d(2026, 9, 7),
        attendedDates: {d(2026, 9, 7)},
        holidays: {},
        leaveRanges: [],
      );
      expect(m.score, 100);
    });

    test('no expected days yet gives no score instead of 0 or 100', () {
      final m = PeMetricsService.attendance(
        from: d(2026, 9, 12), // Saturday
        to: d(2026, 9, 13),
        attendedDates: {},
        holidays: {},
        leaveRanges: [],
      );
      expect(m.score, isNull);
    });
  });

  group('punctuality', () {
    test('share of clock-ins that were on time', () {
      expect(PeMetricsService.punctuality(onTime: 18, late: 2).score, 90);
    });
    test('no clock-ins gives no score', () {
      expect(PeMetricsService.punctuality(onTime: 0, late: 0).score, isNull);
    });
  });

  group('conduct', () {
    test('is the current risk score, clamped to 0-100', () {
      expect(PeMetricsService.conduct(72).score, 72);
      expect(PeMetricsService.conduct(130).score, 100);
      expect(PeMetricsService.conduct(null).score, isNull);
    });
  });

  group('training', () {
    test('completion rate alone when no scores are recorded', () {
      final m = PeMetricsService.training([
        {'is_completed': true, 'performance_score': null},
        {'is_completed': false, 'performance_score': null},
      ]);
      expect(m.score, 50);
    });

    test('blends completion rate 50/50 with the average score', () {
      final m = PeMetricsService.training([
        {'is_completed': true, 'performance_score': 90},
        {'is_completed': true, 'performance_score': 70},
      ]);
      // completion 100, avg score 80 -> 90
      expect(m.score, 90);
    });

    test('no enrolments gives no score', () {
      expect(PeMetricsService.training([]).score, isNull);
    });
  });
}
