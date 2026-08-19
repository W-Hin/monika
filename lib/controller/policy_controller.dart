import 'package:flutter/foundation.dart';
import '../connection/policy_service.dart';

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

  double lateWeight = 3;
  double outOfZoneWeight = 5;
  double sharedDeviceWeight = 10;
  double wifiMismatchWeight = 4;
  double earlyClockoutWeight = 2;

  double lateDeduction = 25.00;
  double absentDeduction = 120.00;
  double unpaidLeaveDailyRate = 120.00;

  double leadershipThreshold = 60;
  double technicalThreshold = 65;
  double behaviouralThreshold = 60;
  int minTenureMonths = 6;

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
