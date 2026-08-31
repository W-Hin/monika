import 'package:flutter/foundation.dart';
import '../connection/policy_service.dart';

/// The system defaults every field in [PolicyController] starts at and
/// that "Reset to Default" (Policy Config screen) restores — kept as one
/// canonical source instead of duplicating literals in both places, which
/// is exactly how they drifted out of sync with the actual migration
/// before (schema.sql's policy_settings defaults vs. this file). Must be
/// kept in sync with policy_settings' column defaults in schema.sql /
/// migration 0032 by hand — there's no way to read a column default back
/// out over PostgREST.
class Defaults {
  Defaults._();

  static const double lateWeight = 10;
  static const double outOfZoneWeight = 20;
  static const double sharedDeviceWeight = 35;
  static const double wifiMismatchWeight = 12;
  static const double earlyClockoutWeight = 8;
  static const double unexplainedAbsenceWeight = 15;

  static const int riskResetPeriodMonths = 2;
  static const double riskPenaltyPercent = 5.00;

  static const double lateDeduction = 25.00;
  static const double absentDeduction = 120.00;
  static const double unpaidLeaveDailyRate = 120.00;

  static const double leadershipThreshold = 60;
  static const double technicalThreshold = 65;
  static const double behaviouralThreshold = 60;
  static const int minTenureMonths = 6;
}

/// State-management pattern: ChangeNotifier singleton, consumed via
/// ListenableBuilder — same convention as every other controller in this
/// app (no `provider` package).
///
/// Known gap, not something this controller can fix on its own: several
/// of these values are now genuinely persisted and readable, but nothing
/// in the app *consumes* all of them yet. `lateDeduction` is already read
/// by Payroll generation (lib/connection/payroll_service.dart), so
/// changing it here has a real effect next time payroll is generated.
/// `lateWeight` / `outOfZoneWeight` / `sharedDeviceWeight` /
/// `wifiMismatchWeight` / `earlyClockoutWeight` (risk score deduction
/// weights) are now consumed for real too — `trg_apply_risk_deduction`
/// (migration 0022) reads them straight from `policy_settings` every time
/// an anomaly_events row is inserted, so changing a slider here changes
/// risk_score deductions on the very next anomaly. The PE training-trigger
/// thresholds are read for real by both hr_pe.dart's KPI-hit badge and
/// `PeController._triggerTrainingRecommendations`, which also gates on
/// `minTenureMonths` — an employee hired more recently than this is never
/// auto-enrolled in training off a low PE score.
class PolicyController extends ChangeNotifier {
  bool loading = false;
  bool loaded = false;
  String? errorMessage;

  String workStartTime = '09:00';
  String workEndTime = '18:00';
  int gracePeriodMinutes = 10;
  int geofenceRadiusMeters = 100;
  String officeWifiSsid = 'MONIKA-OFFICE-5G';

  double lateWeight = Defaults.lateWeight;
  double outOfZoneWeight = Defaults.outOfZoneWeight;
  double sharedDeviceWeight = Defaults.sharedDeviceWeight;
  double wifiMismatchWeight = Defaults.wifiMismatchWeight;
  double earlyClockoutWeight = Defaults.earlyClockoutWeight;
  double unexplainedAbsenceWeight = Defaults.unexplainedAbsenceWeight;

  // How often (months) a risk score resets to 100 on its own, and what
  // percentage of that month's salary is deducted the moment a score hits
  // 0 — both enforced server-side (apply_risk_deduction() trigger,
  // reset_stale_risk_scores() cron job, migration 0032), not just here.
  int riskResetPeriodMonths = Defaults.riskResetPeriodMonths;
  double riskPenaltyPercent = Defaults.riskPenaltyPercent;

  double lateDeduction = Defaults.lateDeduction;
  double absentDeduction = Defaults.absentDeduction;
  double unpaidLeaveDailyRate = Defaults.unpaidLeaveDailyRate;

  double leadershipThreshold = Defaults.leadershipThreshold;
  double technicalThreshold = Defaults.technicalThreshold;
  double behaviouralThreshold = Defaults.behaviouralThreshold;
  int minTenureMonths = Defaults.minTenureMonths;

  String _timeToHHmm(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

  Future<void> load() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final row = await PolicyService.fetch();

      workStartTime = _timeToHHmm(row['work_start_time'] as String);
      workEndTime = _timeToHHmm(row['work_end_time'] as String);
      gracePeriodMinutes = row['grace_period_minutes'] as int;
      geofenceRadiusMeters = row['geofence_radius_meters'] as int;
      officeWifiSsid = row['office_wifi_ssid'] as String;

      lateWeight = (row['late_weight'] as num).toDouble();
      outOfZoneWeight = (row['out_of_zone_weight'] as num).toDouble();
      sharedDeviceWeight = (row['shared_device_weight'] as num).toDouble();
      wifiMismatchWeight = (row['wifi_mismatch_weight'] as num).toDouble();
      earlyClockoutWeight = (row['early_clockout_weight'] as num).toDouble();
      unexplainedAbsenceWeight = (row['unexplained_absence_weight'] as num).toDouble();
      riskResetPeriodMonths = row['risk_reset_period_months'] as int;
      riskPenaltyPercent = (row['risk_penalty_percent'] as num).toDouble();

      lateDeduction = (row['late_deduction'] as num).toDouble();
      absentDeduction = (row['absent_deduction'] as num).toDouble();
      unpaidLeaveDailyRate = (row['unpaid_leave_daily_rate'] as num).toDouble();

      leadershipThreshold = (row['leadership_threshold'] as num).toDouble();
      technicalThreshold = (row['technical_threshold'] as num).toDouble();
      behaviouralThreshold = (row['behavioural_threshold'] as num).toDouble();
      minTenureMonths = row['min_tenure_months'] as int;
      loaded = true;
    } catch (e) {
      errorMessage = 'Could not load policy configuration: $e';
    }
    loading = false;
    notifyListeners();
  }

  Future<bool> save({
    required String workStartTime,
    required String workEndTime,
    required int gracePeriodMinutes,
    required int geofenceRadiusMeters,
    required String officeWifiSsid,
    required double lateWeight,
    required double outOfZoneWeight,
    required double sharedDeviceWeight,
    required double wifiMismatchWeight,
    required double earlyClockoutWeight,
    required double unexplainedAbsenceWeight,
    required int riskResetPeriodMonths,
    required double riskPenaltyPercent,
    required double lateDeduction,
    required double absentDeduction,
    required double unpaidLeaveDailyRate,
    required double leadershipThreshold,
    required double technicalThreshold,
    required double behaviouralThreshold,
    required int minTenureMonths,
  }) async {
    errorMessage = null;
    try {
      await PolicyService.update({
        'work_start_time': workStartTime,
        'work_end_time': workEndTime,
        'grace_period_minutes': gracePeriodMinutes,
        'geofence_radius_meters': geofenceRadiusMeters,
        'office_wifi_ssid': officeWifiSsid,
        'late_weight': lateWeight,
        'out_of_zone_weight': outOfZoneWeight,
        'shared_device_weight': sharedDeviceWeight,
        'wifi_mismatch_weight': wifiMismatchWeight,
        'early_clockout_weight': earlyClockoutWeight,
        'unexplained_absence_weight': unexplainedAbsenceWeight,
        'risk_reset_period_months': riskResetPeriodMonths,
        'risk_penalty_percent': riskPenaltyPercent,
        'late_deduction': lateDeduction,
        'absent_deduction': absentDeduction,
        'unpaid_leave_daily_rate': unpaidLeaveDailyRate,
        'leadership_threshold': leadershipThreshold,
        'technical_threshold': technicalThreshold,
        'behavioural_threshold': behaviouralThreshold,
        'min_tenure_months': minTenureMonths,
      });
      await load();
      return true;
    } catch (e) {
      errorMessage = 'Could not save policy configuration: $e';
      notifyListeners();
      return false;
    }
  }
}

final policyController = PolicyController();
