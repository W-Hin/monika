import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/view/employee/attendance/employee_attendance.dart';

void main() {
  group('AnomalyEvent.absenceExcusableOn', () {
    final today = DateTime(2026, 10, 20);
    AnomalyEvent absence(DateTime day, {String? status, DateTime? appealedAt}) => AnomalyEvent(
          id: 1,
          employeeName: 'Sarah Lim',
          type: 'Unexplained absence',
          date: '',
          details: '',
          severity: RiskLevel.medium,
          isAbsence: true,
          eventDate: day,
          appealStatus: status,
          appealedAt: appealedAt,
        );

    test('within 7 days of the absence', () {
      expect(absence(DateTime(2026, 10, 13)).absenceExcusableOn(today), isTrue);
    });

    test('not after 7 days without an appeal', () {
      expect(absence(DateTime(2026, 10, 12)).absenceExcusableOn(today), isFalse);
    });

    test('still allowed later for an open appeal made within 7 days', () {
      final a = absence(DateTime(2026, 10, 10), status: 'pending', appealedAt: DateTime(2026, 10, 16));
      expect(a.absenceExcusableOn(today), isTrue);
    });

    test('not for an appeal made after the 7 days', () {
      final a = absence(DateTime(2026, 10, 1), status: 'pending', appealedAt: DateTime(2026, 10, 9));
      expect(a.absenceExcusableOn(today), isFalse);
    });

    test('never once already excused', () {
      final a = AnomalyEvent(
        id: 1, employeeName: 'x', type: 'x', date: '', details: '', severity: RiskLevel.low,
        isAbsence: true, eventDate: DateTime(2026, 10, 19), reverted: true,
      );
      expect(a.canRevertOn(today), isFalse);
    });

    test('other violations need a clock-in record to revert', () {
      const withRecord = AnomalyEvent(id: 1, employeeName: 'x', type: 'x', date: '', details: '', severity: RiskLevel.low, attendanceRecordId: 5);
      const without = AnomalyEvent(id: 2, employeeName: 'x', type: 'x', date: '', details: '', severity: RiskLevel.low);
      expect(withRecord.canRevertOn(today), isTrue);
      expect(without.canRevertOn(today), isFalse);
    });
  });

  group('AbsenceFlagCard', () {
    AbsenceFlag flag({bool canAppeal = false, String? status, String? response, bool excused = false}) => AbsenceFlag(
          id: 1,
          date: DateTime(2026, 10, 5),
          appealStatus: status,
          appealResponse: response,
          excused: excused,
          appealDeadline: DateTime(2026, 10, 12),
          canAppeal: canAppeal,
        );

    Future<void> pump(WidgetTester tester, AbsenceFlag f, VoidCallback onAppeal) => tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: Scaffold(body: AbsenceFlagCard(flag: f, onAppeal: onAppeal))),
        );

    testWidgets('offers an appeal with its deadline', (tester) async {
      var tapped = false;
      await pump(tester, flag(canAppeal: true), () => tapped = true);
      expect(find.text('You can appeal until 12 Oct'), findsOneWidget);
      await tester.tap(find.text('Appeal'));
      expect(tapped, isTrue);
    });

    testWidgets('shows a pending appeal without another Appeal button', (tester) async {
      await pump(tester, flag(status: 'pending'), () {});
      expect(find.text('Appeal sent — waiting for HR'), findsOneWidget);
      expect(find.text('Appeal'), findsNothing);
    });

    testWidgets('shows HR\'s note when an appeal is rejected', (tester) async {
      await pump(tester, flag(status: 'rejected', response: 'Apply for leave in advance'), () {});
      expect(find.text('Appeal not accepted'), findsOneWidget);
      expect(find.text('HR: Apply for leave in advance'), findsOneWidget);
    });

    testWidgets('shows an excused absence', (tester) async {
      await pump(tester, flag(status: 'accepted', excused: true), () {});
      expect(find.text('Excused by HR'), findsOneWidget);
    });
  });
}
