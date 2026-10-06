import 'package:supabase_flutter/supabase_flutter.dart';
import '../model/models.dart';

/// Reads the ML training recommender's prediction for one employee. The
/// model is trained offline (ml/train.py) and scored inside Postgres, so
/// this is a single RPC — there is no model server.
class TrainingInsightService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Null when no model has been uploaded yet.
  static Future<TrainingInsight?> fetch(String userUuid) async {
    final res = await _client.rpc('ml_predict_training_category', params: {'p_user': userUuid});
    if (res is! Map) return null;
    return TrainingInsight.fromJson(Map<String, dynamic>.from(res));
  }
}
