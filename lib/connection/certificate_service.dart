import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads `training_certificates`. Certificates are only ever written by the
/// database itself when an enrolment is completed (migration 0041), so
/// there is nothing to create or edit from the app.
class CertificateService {
  CertificateService._();
  static final _client = Supabase.instance.client;

  /// The signed-in employee's certificates, newest first.
  static Future<List<Map<String, dynamic>>> fetchMine() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return [];
    final rows = await _client
        .from('training_certificates')
        .select()
        .eq('user_id', uid)
        .order('issued_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  static Future<Map<String, dynamic>?> fetchForEnrollment(int enrollmentId) async {
    return await _client
        .from('training_certificates')
        .select()
        .eq('enrollment_id', enrollmentId)
        .maybeSingle();
  }
}
