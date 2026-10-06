import 'package:flutter_test/flutter_test.dart';
import 'package:monika/controller/training_controller.dart';
import 'package:monika/model/models.dart';

void main() {
  group('isMandatoryFor', () {
    test('a mandatory programme for everyone applies to every department', () {
      expect(
        TrainingController.isMandatoryFor(programMandatory: true, programDepartmentId: null, myDepartmentId: 3, exempt: false),
        isTrue,
      );
    });

    test('a mandatory programme for another department does not apply', () {
      expect(
        TrainingController.isMandatoryFor(programMandatory: true, programDepartmentId: 2, myDepartmentId: 3, exempt: false),
        isFalse,
      );
    });

    test('an exemption from HR removes the obligation', () {
      expect(
        TrainingController.isMandatoryFor(programMandatory: true, programDepartmentId: 3, myDepartmentId: 3, exempt: true),
        isFalse,
      );
    });

    test('an optional programme is never mandatory', () {
      expect(
        TrainingController.isMandatoryFor(programMandatory: false, programDepartmentId: null, myDepartmentId: 3, exempt: false),
        isFalse,
      );
    });
  });

  group('canWithdraw', () {
    TrainingProgram enrolled({bool mandatory = false, double progress = 0, bool completed = false}) => TrainingProgram(
          dbId: 7,
          enrollmentId: 3,
          title: 'Workplace Ethics',
          category: 'Behavioural',
          description: 'desc',
          duration: '2 hours',
          isMandatory: mandatory,
          progress: progress,
          isCompleted: completed,
        );

    test('an optional programme not yet started can be withdrawn from', () {
      expect(TrainingController.canWithdraw(enrolled(), lessonsRead: 0, attempts: 0), isTrue);
    });

    test('not once a lesson has been read or the quiz attempted', () {
      expect(TrainingController.canWithdraw(enrolled(), lessonsRead: 1, attempts: 0), isFalse);
      expect(TrainingController.canWithdraw(enrolled(), lessonsRead: 0, attempts: 1), isFalse);
      expect(TrainingController.canWithdraw(enrolled(progress: 0.3), lessonsRead: 0, attempts: 0), isFalse);
    });

    test('not from a mandatory or completed programme', () {
      expect(TrainingController.canWithdraw(enrolled(mandatory: true), lessonsRead: 0, attempts: 0), isFalse);
      expect(TrainingController.canWithdraw(enrolled(completed: true), lessonsRead: 0, attempts: 0), isFalse);
    });

    test('not when not enrolled', () {
      const notEnrolled = TrainingProgram(dbId: 7, title: 'x', category: 'Technical', description: 'd', duration: '1h');
      expect(TrainingController.canWithdraw(notEnrolled, lessonsRead: 0, attempts: 0), isFalse);
    });
  });
}
