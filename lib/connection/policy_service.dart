import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin wrapper over the single-row `policy_settings` table (id is always
/// 1). Holds no state of its own — PolicyController owns app-facing state.
class PolicyService {
  PolicyService._();
  static final _client = Supabase.instance.client;

  static Future<Map<String, dynamic>> fetch() async {
    return await _client.from('policy_settings').select().eq('id', 1).single();
  }

  static Future<void> update(Map<String, dynamic> values) async {
    await _client.from('policy_settings').update(values).eq('id', 1);
  }
}
