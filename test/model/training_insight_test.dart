import 'package:flutter_test/flutter_test.dart';
import 'package:monika/model/models.dart';

void main() {
  group('TrainingInsight.fromJson', () {
    final json = {
      'category': 'leadership',
      'confidence': 0.71,
      'probabilities': {'technical': 0.2, 'behavioural': 0.09, 'leadership': 0.71},
      'top_factors': [
        {'feature': 'tenure_months', 'value': 48, 'z': 0.9, 'contribution': 0.8},
      ],
      'model_version': 'lr-20261006-abc123',
      'model_accuracy': 0.7833,
      'min_confidence': 0.65,
    };

    test('reads the prediction the database returns', () {
      final i = TrainingInsight.fromJson(json);
      expect(i.category, 'leadership');
      expect(i.probabilities['technical'], 0.2);
      expect(i.factors.single.feature, 'tenure_months');
      expect(i.modelAccuracy, 0.7833);
      expect(i.isConfident, isTrue);
    });

    test('is not confident below the model threshold', () {
      final i = TrainingInsight.fromJson({...json, 'confidence': 0.5});
      expect(i.isConfident, isFalse);
    });

    test('copes with no factors and no recorded accuracy', () {
      final i = TrainingInsight.fromJson({...json, 'top_factors': [], 'model_accuracy': null});
      expect(i.factors, isEmpty);
      expect(i.modelAccuracy, isNull);
    });
  });

  group('InsightFactor.description', () {
    InsightFactor f(String feature, double? value, double z) =>
        InsightFactor(feature: feature, value: value, z: z, contribution: 1);

    test('says which way the signal points', () {
      expect(f('attendance_rate', 81.5, -2).description, 'Attendance is low (81.5% over 90 days)');
      expect(f('attendance_rate', 99, 1).description, 'Attendance is strong (99% over 90 days)');
      expect(f('tenure_months', 2, -1).description, 'Relatively new to the company (2 months)');
      expect(f('risk_score', 70, -1).description, 'Risk score has dropped (70/100)');
    });

    test('names the review area for PE scores', () {
      expect(f('pe_behavioural', 55, -1.5).description, 'Low Behavioural score in the last review (55)');
      expect(f('pe_technical', 91.2, 1.6).description, 'Strong Technical score in the last review (91.2)');
    });
  });
}
