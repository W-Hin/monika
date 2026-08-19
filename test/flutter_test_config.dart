import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'test_helpers/supabase_test_setup.dart';

/// Flutter auto-discovers this file and wraps every test in this directory
/// tree with it — see supabase_test_setup.dart for why this is needed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeTestSupabase();
  await testMain();
}
