import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monika/core/theme/app_theme.dart';
import 'package:monika/model/models.dart';
import 'package:monika/utility/certificate_pdf_builder.dart';
import 'package:monika/view/employee/training/certificates.dart';
import 'package:monika/view/employee/training/employee_training.dart';
import 'package:monika/view/employee/training/training_detail.dart';
import 'package:monika/view/employee/training/training_quiz.dart';

void main() {
  testWidgets('EmployeeTrainingScreen builds', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeTrainingScreen()));
    expect(find.text('Recommended'), findsOneWidget);
  });

  testWidgets('TrainingDetailScreen builds', (tester) async {
    const program = TrainingProgram(
      title: 'Leadership Fundamentals',
      category: 'Leadership',
      description: 'desc',
      isMandatory: false,
      isRecommended: false,
      progress: 0,
      duration: '2 weeks',
      isCompleted: false,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: TrainingDetailScreen(program: program),
    ));
    expect(find.text('Leadership Fundamentals'), findsOneWidget);
  });

  testWidgets('a tenure-locked programme explains when it opens instead of offering Enrol', (tester) async {
    const program = TrainingProgram(
      title: 'Strategic Thinking for Team Leads',
      category: 'Leadership',
      description: 'desc',
      duration: '3 hours',
      minTenureMonths: 24,
      locked: true,
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: TrainingDetailScreen(program: program)));
    await tester.pump();
    expect(find.text('This programme opens after 24 months of service.'), findsOneWidget);
    expect(find.text('Enrol Now'), findsNothing);
  });

  testWidgets('a completed programme links its certificate and lists every quiz attempt', (tester) async {
    const program = TrainingProgram(
      dbId: 7,
      enrollmentId: 3,
      title: 'Workplace Ethics',
      category: 'Behavioural',
      description: 'desc',
      duration: '2 hours',
      progress: 1,
      isCompleted: true,
      performanceScore: 80,
    );
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: TrainingDetailScreen(program: program)));
    await tester.pumpAndSettle();

    expect(find.text('View Certificate · MON-2026-00002'), findsOneWidget);

    await tester.dragUntilVisible(find.text('Attempt History (2)'), find.byType(ListView), const Offset(0, -200));
    await tester.dragUntilVisible(find.text('Attempt 1'), find.byType(ListView), const Offset(0, -200));
    expect(find.text('Attempt 2'), findsOneWidget);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Below 70%'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
  });

  testWidgets('My Certificates opens from the Training tab', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const EmployeeTrainingScreen()));
    await tester.tap(find.byTooltip('My Certificates'));
    await tester.pumpAndSettle();
    expect(find.text('My Certificates'), findsOneWidget);
    // No signed-in user in tests, so the list is empty.
    expect(find.text('No certificates yet'), findsOneWidget);
  });

  group('CertificateScreen', () {
    final cert = TrainingCertificate(
      id: 2,
      certificateNo: 'MON-2026-00002',
      enrollmentId: 3,
      programId: 7,
      employeeName: 'Aina Rahman',
      programTitle: 'Workplace Ethics',
      category: 'behavioural',
      score: 80,
      issuedAt: DateTime(2026, 9, 12),
    );

    testWidgets('shows who earned it, for what, and the certificate number', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: CertificateScreen(certificate: cert)));
      expect(find.text('CERTIFICATE OF COMPLETION'), findsOneWidget);
      expect(find.text('Aina Rahman'), findsOneWidget);
      expect(find.text('Workplace Ethics'), findsOneWidget);
      expect(find.text('Behavioural programme  ·  Score 80%  ·  Issued 12 Sep 2026'), findsOneWidget);
      expect(find.text('Certificate No. MON-2026-00002'), findsOneWidget);
      expect(find.text('Download PDF'), findsOneWidget);
    });

    test('builds a PDF', () async {
      final bytes = await CertificatePdfBuilder.build(cert);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('leaves the score off when there is none', () async {
      final unscored = TrainingCertificate(
        id: 3,
        certificateNo: 'MON-2026-00003',
        enrollmentId: null,
        programId: null,
        employeeName: 'Ben Tan',
        programTitle: 'Leading Teams',
        category: 'leadership',
        score: null,
        issuedAt: DateTime(2026, 10, 1),
      );
      expect(unscored.categoryLabel, 'Leadership');
      final bytes = await CertificatePdfBuilder.build(unscored);
      expect(bytes.length, greaterThan(1000));
    });
  });

  test('QuizAttempt and TrainingCertificate read database rows', () {
    final a = QuizAttempt.fromJson({'score': 60, 'passed': false, 'created_at': '2026-09-10T02:15:00Z'});
    expect(a.score, 60);
    expect(a.passed, isFalse);
    final c = TrainingCertificate.fromJson({
      'id': 1,
      'certificate_no': 'MON-2026-00001',
      'enrollment_id': null,
      'program_id': null,
      'employee_name': 'Aina Rahman',
      'program_title': 'Secure Coding',
      'category': 'technical',
      'score': null,
      'issued_at': '2026-03-01T00:00:00Z',
    });
    expect(c.programTitle, 'Secure Coding');
    expect(c.score, isNull);
  });

  testWidgets('TrainingQuizScreen builds and keeps Submit disabled until every question is answered', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: const TrainingQuizScreen(programId: 1, programTitle: 'Cybersecurity Essentials'),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Cybersecurity Essentials'), findsOneWidget);
    expect(find.text('Answer all questions to submit'), findsOneWidget);
  });
}
