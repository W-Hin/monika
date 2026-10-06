import 'package:flutter/foundation.dart';
import '../connection/certificate_service.dart';
import '../model/models.dart';

/// The signed-in employee's training certificates. Same ChangeNotifier
/// singleton convention as every other controller in this app.
class CertificateController extends ChangeNotifier {
  List<TrainingCertificate> mine = [];
  bool loading = false;
  String? errorMessage;

  Future<void> loadMine() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      mine = (await CertificateService.fetchMine()).map(TrainingCertificate.fromJson).toList();
    } catch (e) {
      errorMessage = 'Could not load your certificates: $e';
    }
    loading = false;
    notifyListeners();
  }

  /// Null if none has been issued for this enrolment (yet).
  Future<TrainingCertificate?> forEnrollment(int enrollmentId) async {
    try {
      final row = await CertificateService.fetchForEnrollment(enrollmentId);
      return row == null ? null : TrainingCertificate.fromJson(row);
    } catch (_) {
      return null;
    }
  }
}

final certificateController = CertificateController();
