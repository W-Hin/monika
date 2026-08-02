import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../connection/auth_service.dart';
import '../core/data/dummy_data.dart';
import '../model/models.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// App-facing auth state. Matches the singleton + ChangeNotifier/ValueNotifier
/// pattern already established by theme_controller.dart — no `provider`
/// package, consumed via AnimatedBuilder/ListenableBuilder.
class AuthController extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  UserRole? role;
  bool mustChangePassword = false;
  String? errorMessage;

  /// Call once at app startup. If Supabase already has a persisted session
  /// (previous login), this loads the profile and signs the user straight
  /// in without them re-entering credentials.
  Future<void> restoreSession() async {
    if (AuthService.currentSession == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    await _loadProfile();
  }

  Future<bool> signIn({required String email, required String password}) async {
    errorMessage = null;
    try {
      await AuthService.signIn(email: email, password: password);
      await _loadProfile();
      return status == AuthStatus.signedIn;
    } on AuthException catch (e) {
      errorMessage = e.message;
      status = AuthStatus.signedOut;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await AuthService.signOut();
    status = AuthStatus.signedOut;
    role = null;
    notifyListeners();
  }

  Future<void> _loadProfile() async {
    final row = await AuthService.fetchMyProfile();
    if (row == null) {
      errorMessage = 'No profile found for this account. Contact HR.';
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }

    final user = _mapToAppUser(row);
    role = user.userRole;
    mustChangePassword = row['must_change_password'] as bool? ?? false;
    // Every account is "an employee" first — HR admins can use the
    // shell-switcher to view their own self-service tools (clock in, leave,
    // training), so employeeUser must reflect their real profile too, not
    // stay on leftover dummy placeholder data.
    DummyData.employeeUser = user;
    if (role == UserRole.hrAdmin) {
      DummyData.hrUser = user;
    }
    status = AuthStatus.signedIn;
    notifyListeners();

    if (row['email'] != user.email && user.email.isNotEmpty) {
      // Fire-and-forget — HR's employee list reads this, but it's not on
      // the critical path for the current user's own login.
      unawaited(AuthService.syncOwnEmail(user.email));
    }
  }

  AppUser _mapToAppUser(Map<String, dynamic> row) {
    final riskLevel = RiskLevel.values.firstWhere(
      (r) => r.name == row['risk_level'],
      orElse: () => RiskLevel.low,
    );
    final userRole = row['user_role'] == 'hr_admin' ? UserRole.hrAdmin : UserRole.employee;
    final departmentName = (row['departments'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unassigned';
    final hireDate = DateTime.tryParse(row['hire_date'] as String? ?? '');
    final deviceBoundAt = row['device_bound_at'] as String?;

    return AppUser(
      id: row['employee_code'] as String,
      name: row['name'] as String,
      email: (AuthService.currentUser?.email ?? '').trim(),
      department: departmentName,
      role: row['job_title'] as String,
      userRole: userRole,
      riskLevel: riskLevel,
      avatarInitials: row['avatar_initials'] as String,
      employmentDuration: hireDate != null ? _formatEmploymentDuration(hireDate) : '—',
      registeredDevice: row['registered_device_name'] as String? ?? 'Not yet registered',
      deviceBoundSince: deviceBoundAt != null ? DateFormat('d MMM yyyy').format(DateTime.parse(deviceBoundAt)) : '—',
    );
  }

  String _formatEmploymentDuration(DateTime hireDate) {
    final now = DateTime.now();
    var months = (now.year - hireDate.year) * 12 + (now.month - hireDate.month);
    if (now.day < hireDate.day) months--;
    if (months < 0) months = 0;
    final years = months ~/ 12;
    final remMonths = months % 12;
    if (years == 0) return '$remMonths mo';
    if (remMonths == 0) return '$years yr';
    return '$years yr $remMonths mo';
  }
}

final authController = AuthController();
