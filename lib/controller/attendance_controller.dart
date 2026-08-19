import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:intl/intl.dart';
import '../connection/attendance_service.dart';
import '../connection/auth_service.dart';
import '../connection/anomaly_service.dart';
import '../model/models.dart';
import 'auth_controller.dart';

class GpsCheckResult {
  final bool passed;
  final double? lat;
  final double? lng;
  final String detail;
  const GpsCheckResult({required this.passed, this.lat, this.lng, required this.detail});
}

class WifiCheckResult {
  final bool passed;
  final String? ssid;
  final String detail;
  const WifiCheckResult({required this.passed, this.ssid, required this.detail});
}

class DeviceCheckResult {
  final bool passed;
  final String? deviceToken;
  final String deviceName;
  final String detail;
  // True only for the shared-device-with-another-account case — unlike a
  // normal failed device check (which still lets the clock-in through as
  // a flagged record for HR to review), this one has no legitimate
  // self-correction and must stop the clock-in outright.
  final bool blocked;
  const DeviceCheckResult({
    required this.passed,
    this.deviceToken,
    required this.deviceName,
    required this.detail,
    this.blocked = false,
  });
}

/// Real IoT attendance validation (GPS geofence + WiFi SSID + device token)
/// plus Supabase persistence. This is inherently a mobile-sensor feature —
/// GPS/WiFi-name/device-id APIs are Android/iOS-first; other platforms fall
/// back to honest "unavailable on this platform" results rather than faking
/// a pass, since silently faking it would defeat the point of the checks.
class AttendanceController extends ChangeNotifier {
  AttendanceRecord? todayRecord;
  int? _todayRecordId;
  List<AttendanceRecord> history = [];

  // All-time fraction of clock-ins that were on_time or late (not flagged),
  // across every attendance record — 0% before the first-ever clock-in,
  // rather than a misleading placeholder.
  double attendanceRate = 0;

  Future<void> loadAttendanceRate() async {
    try {
      final rows = await AttendanceService.fetchAllStatuses();
      if (rows.isEmpty) {
        attendanceRate = 0;
      } else {
        final present = rows.where((r) => r['status'] == 'on_time' || r['status'] == 'late').length;
        attendanceRate = present / rows.length;
      }
    } catch (_) {
      // Best-effort, same reasoning as loadToday.
    }
    notifyListeners();
  }

  // 90-day window for the Risk Classification card — separate from
  // `history` because that's capped to the most recent 30 rows for the
  // Recent Records list, which would understate the window for anyone
  // with more than 30 records in the last 90 days.
  List<AttendanceRecord> riskWindow = [];
  int get riskViolations => riskWindow.where((r) => r.status == AttendanceStatus.flagged).length;
  int get riskLateDays => riskWindow.where((r) => r.status == AttendanceStatus.late).length;

  double _officeLat = 3.1390;
  double _officeLng = 101.6869;
  int _geofenceRadius = 100;
  String _officeWifiSsid = 'MONIKA-OFFICE-5G';
  String _workStart = '09:00:00';
  String _workEnd = '18:00:00';
  int _gracePeriodMinutes = 10;
  bool _policyLoaded = false;

  int get geofenceRadius => _geofenceRadius;
  String get officeWifiSsid => _officeWifiSsid;

  Future<void> loadPolicy() async {
    if (_policyLoaded) return;
    try {
      final row = await AttendanceService.fetchPolicySettings();
      if (row != null) {
        _officeLat = double.tryParse('${row['office_lat']}') ?? _officeLat;
        _officeLng = double.tryParse('${row['office_lng']}') ?? _officeLng;
        _geofenceRadius = (row['geofence_radius_meters'] as num?)?.toInt() ?? _geofenceRadius;
        _officeWifiSsid = row['office_wifi_ssid'] as String? ?? _officeWifiSsid;
        _workStart = row['work_start_time'] as String? ?? _workStart;
        _workEnd = row['work_end_time'] as String? ?? _workEnd;
        _gracePeriodMinutes = (row['grace_period_minutes'] as num?)?.toInt() ?? _gracePeriodMinutes;
      }
      _policyLoaded = true;
    } catch (_) {
      // Best-effort, same reasoning as loadToday — callers just keep using
      // the hardcoded defaults above until the next successful fetch.
    }
  }

  Future<void> loadToday() async {
    try {
      await loadPolicy();
      final row = await AttendanceService.fetchTodayRecord();
      _todayRecordId = row?['id'] as int?;
      todayRecord = row != null ? _mapRecord(row) : null;
    } catch (_) {
      // Best-effort — the Home dashboard just shows "Not Clocked In" if
      // this fails, no error state needed for a background refresh.
    }
    notifyListeners();
  }

  Future<void> loadHistory() async {
    try {
      final rows = await AttendanceService.fetchHistory();
      history = rows.map(_mapRecord).toList();
    } catch (_) {
      // Best-effort, same reasoning as loadToday.
    }
    notifyListeners();
  }

  // Attendance History screen's month filter — a dedicated, uncapped
  // per-month query rather than filtering `history` (capped to the most
  // recent 30 rows, which would silently hide older months once an
  // account passes that many total records).
  List<AttendanceRecord> monthRecords = [];
  bool loadingMonth = false;

  Future<void> loadForMonth(DateTime month) async {
    loadingMonth = true;
    notifyListeners();
    try {
      final rows = await AttendanceService.fetchForMonth(month);
      monthRecords = rows.map(_mapRecord).toList();
    } catch (_) {
      // Best-effort, same reasoning as loadToday.
    }
    loadingMonth = false;
    notifyListeners();
  }

  Future<void> loadRiskWindow() async {
    try {
      final rows = await AttendanceService.fetchWindow(days: 90);
      riskWindow = rows.map(_mapRecord).toList();
    } catch (_) {
      // Best-effort, same reasoning as loadToday.
    }
    notifyListeners();
  }

  // Separate from riskWindow (fixed 90-day risk-classification scope) —
  // "Days Present" is meant to read as "so far this calendar year".
  List<AttendanceRecord> yearWindow = [];
  int get daysPresentThisYear => yearWindow.where((r) => r.status == AttendanceStatus.onTime || r.status == AttendanceStatus.late).length;

  Future<void> loadYearWindow() async {
    try {
      final now = DateTime.now();
      final daysSinceJan1 = now.difference(DateTime(now.year, 1, 1)).inDays + 1;
      final rows = await AttendanceService.fetchWindow(days: daysSinceJan1);
      yearWindow = rows.map(_mapRecord).toList();
    } catch (_) {
      // Best-effort, same reasoning as loadToday.
    }
    notifyListeners();
  }

  AttendanceRecord _mapRecord(Map<String, dynamic> row) {
    final workDate = DateTime.parse(row['work_date'] as String);
    final clockInAt = DateTime.parse(row['clock_in_at'] as String).toLocal();
    final clockOutAtRaw = row['clock_out_at'] as String?;
    final status = AttendanceStatus.values.firstWhere(
      (s) => s.name == _camelFromSnake(row['status'] as String),
      orElse: () => AttendanceStatus.onTime,
    );
    return AttendanceRecord(
      workDate: workDate,
      date: DateFormat('EEE, d MMM').format(workDate),
      clockIn: DateFormat('hh:mm a').format(clockInAt),
      clockOut: clockOutAtRaw != null ? DateFormat('hh:mm a').format(DateTime.parse(clockOutAtRaw).toLocal()) : null,
      status: status,
      flagReason: row['flag_reason'] as String?,
    );
  }

  String _camelFromSnake(String s) {
    final parts = s.split('_');
    if (parts.length == 1) return parts[0];
    return parts.first + parts.skip(1).map((p) => p[0].toUpperCase() + p.substring(1)).join();
  }

  Future<GpsCheckResult> runGpsCheck() async {
    await loadPolicy();
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const GpsCheckResult(passed: false, detail: 'Location permission denied');
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const GpsCheckResult(passed: false, detail: 'Location services are turned off');
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final distance = Geolocator.distanceBetween(_officeLat, _officeLng, pos.latitude, pos.longitude);
      final passed = distance <= _geofenceRadius;
      return GpsCheckResult(
        passed: passed,
        lat: pos.latitude,
        lng: pos.longitude,
        detail: passed
            ? 'Within ${distance.toStringAsFixed(0)}m of the office'
            : '${distance.toStringAsFixed(0)}m from the office — outside the ${_geofenceRadius}m radius',
      );
    } catch (e) {
      return GpsCheckResult(passed: false, detail: 'Location unavailable on this device ($e)');
    }
  }

  Future<WifiCheckResult> runWifiCheck() async {
    await loadPolicy();
    try {
      final info = NetworkInfo();
      var ssid = await info.getWifiName();
      ssid = ssid?.replaceAll('"', '');
      final passed = ssid != null && ssid.toLowerCase() == _officeWifiSsid.toLowerCase();
      return WifiCheckResult(
        passed: passed,
        ssid: ssid,
        detail: ssid == null
            ? 'Could not read the WiFi network name on this device'
            : passed
                ? 'Connected to $ssid'
                : 'Connected to "$ssid" — expected "$_officeWifiSsid"',
      );
    } catch (e) {
      return WifiCheckResult(passed: false, detail: 'WiFi check unavailable on this device ($e)');
    }
  }

  Future<(String token, String name)> _currentDeviceIdentity() async {
    final deviceInfo = DeviceInfoPlugin();
    if (kIsWeb) {
      final info = await deviceInfo.webBrowserInfo;
      return (info.vendor ?? info.userAgent ?? 'web-device', '${info.browserName.name} browser');
    } else if (Platform.isAndroid) {
      final info = await deviceInfo.androidInfo;
      return (info.id, '${info.manufacturer} ${info.model}');
    } else if (Platform.isIOS) {
      final info = await deviceInfo.iosInfo;
      return (info.identifierForVendor ?? 'ios-device', info.utsname.machine);
    } else if (Platform.isWindows) {
      final info = await deviceInfo.windowsInfo;
      return (info.deviceId, info.computerName);
    }
    return ('unknown-device', 'Unknown device');
  }

  Future<DeviceCheckResult> runDeviceCheck() async {
    try {
      final (token, name) = await _currentDeviceIdentity();
      final profile = await AuthService.fetchMyProfile();
      final storedToken = profile?['device_token'] as String?;

      if (storedToken == null) {
        final boundToOther = await AttendanceService.isDeviceBoundToOther(token);
        if (boundToOther) {
          return DeviceCheckResult(
            passed: false,
            blocked: true,
            deviceToken: token,
            deviceName: name,
            detail: 'This device is already registered to another employee\'s account. Please contact HR by email to appeal.',
          );
        }
        await AttendanceService.bindDevice(deviceToken: token, deviceName: name);
        // Refresh the cached profile so Attendance/Profile screens show the
        // newly-bound device immediately instead of only after re-login.
        unawaited(authController.refreshProfile());
        return DeviceCheckResult(passed: true, deviceToken: token, deviceName: name, detail: 'Registered as your device ($name)');
      }
      final passed = storedToken == token;
      return DeviceCheckResult(
        passed: passed,
        deviceToken: token,
        deviceName: name,
        detail: passed
            ? 'Matches your registered device ($name)'
            : 'This device ($name) does not match your registered device — possible shared-device attempt',
      );
    } catch (e) {
      return DeviceCheckResult(passed: false, deviceName: 'Unknown', detail: 'Device check unavailable ($e)');
    }
  }

  /// Read-only variant for display purposes (e.g. the Attendance tab's IoT
  /// Verification card) — never binds an unregistered device the way
  /// runDeviceCheck() does, since merely viewing that screen shouldn't
  /// silently pair a new device; only an actual clock-in should.
  Future<DeviceCheckResult> checkDeviceStatus() async {
    try {
      final (token, name) = await _currentDeviceIdentity();
      final profile = await AuthService.fetchMyProfile();
      final storedToken = profile?['device_token'] as String?;

      if (storedToken == null) {
        return DeviceCheckResult(passed: false, deviceToken: token, deviceName: name, detail: 'No device registered yet — this device will be registered on your next successful clock-in');
      }
      final passed = storedToken == token;
      return DeviceCheckResult(
        passed: passed,
        deviceToken: token,
        deviceName: name,
        detail: passed
            ? 'Matches your registered device ($name)'
            : 'This device ($name) does not match your registered device',
      );
    } catch (e) {
      return DeviceCheckResult(passed: false, deviceName: 'Unknown', detail: 'Device check unavailable ($e)');
    }
  }

  Future<AttendanceRecord> submitClockIn({
    required bool gpsPassed,
    double? gpsLat,
    double? gpsLng,
    required bool wifiPassed,
    String? wifiSsid,
    required bool devicePassed,
  }) async {
    await loadPolicy();
    final now = DateTime.now();
    String status;
    String? flagReason;

    if (!gpsPassed) {
      status = 'flagged';
      flagReason = 'GPS outside geofence radius';
    } else if (!wifiPassed) {
      status = 'flagged';
      flagReason = 'Connected to unrecognised network during clock-in attempt';
    } else if (!devicePassed) {
      status = 'flagged';
      flagReason = 'Device token mismatch — possible shared-device attempt';
    } else {
      final startParts = _workStart.split(':');
      final workStartMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final nowMinutes = now.hour * 60 + now.minute;
      if (nowMinutes > workStartMinutes + _gracePeriodMinutes) {
        status = 'late';
        flagReason = 'Clocked in ${nowMinutes - workStartMinutes} min after grace period';
      } else {
        status = 'on_time';
      }
    }

    final row = await AttendanceService.clockIn(
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      gpsPassed: gpsPassed,
      wifiSsid: wifiSsid,
      wifiPassed: wifiPassed,
      devicePassed: devicePassed,
      status: status,
      flagReason: flagReason,
    );
    _todayRecordId = row['id'] as int;
    todayRecord = _mapRecord(row);
    // Keep the Recent Records list and Home's Attendance Rate stat in sync
    // with today's just-created row — without this they only show up after
    // the screen is freshly re-created (e.g. a full app restart).
    await loadHistory();
    await loadAttendanceRate();

    await _raiseAnomalies(
      attendanceRecordId: _todayRecordId!,
      gpsPassed: gpsPassed,
      wifiPassed: wifiPassed,
      wifiSsid: wifiSsid,
      devicePassed: devicePassed,
      status: status,
    );
    // Anomalies above may have just deducted this employee's risk_score
    // server-side — refresh so the Risk Classification card reflects it
    // immediately instead of only after the next login.
    unawaited(authController.refreshProfile());

    return todayRecord!;
  }

  /// Best-effort: each failed IoT check raises its own anomaly_events row
  /// (not mutually exclusive — GPS and WiFi can both fail on one attempt),
  /// plus a repeated-late pattern check. Failures here don't roll back the
  /// clock-in itself, since the attendance record is already saved.
  Future<void> _raiseAnomalies({
    required int attendanceRecordId,
    required bool gpsPassed,
    required bool wifiPassed,
    String? wifiSsid,
    required bool devicePassed,
    required String status,
  }) async {
    try {
      if (!gpsPassed) {
        await AnomalyService.createEvent(
          type: 'out_of_zone',
          details: 'GPS coordinates outside the configured geofence radius',
          severity: 'medium',
          attendanceRecordId: attendanceRecordId,
        );
      }
      if (!wifiPassed) {
        await AnomalyService.createEvent(
          type: 'wifi_mismatch',
          details: wifiSsid != null
              ? 'Connected to "$wifiSsid" instead of the registered office network'
              : 'Could not verify the WiFi network during clock-in',
          severity: 'low',
          attendanceRecordId: attendanceRecordId,
        );
      }
      if (!devicePassed) {
        await AnomalyService.createEvent(
          type: 'shared_device',
          details: "Device token does not match this employee's registered device",
          severity: 'high',
          attendanceRecordId: attendanceRecordId,
        );
      }
      if (status == 'late') {
        final lateCount = await AttendanceService.countRecentLate();
        if (lateCount >= 3) {
          await AnomalyService.createEvent(
            type: 'late',
            details: '${_ordinal(lateCount)} late arrival in the past 14 days',
            severity: 'medium',
            attendanceRecordId: attendanceRecordId,
          );
        }
      }
    } catch (_) {
      // Anomaly bookkeeping is secondary to the attendance record itself —
      // don't let a transient failure here surface as a clock-in error.
    }
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  Future<AttendanceRecord?> submitClockOut() async {
    if (_todayRecordId == null) return null;
    await loadPolicy();
    final endParts = _workEnd.split(':');
    final workEndMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;
    final early = nowMinutes < workEndMinutes - _gracePeriodMinutes;

    final row = await AttendanceService.clockOut(_todayRecordId!, early: early);
    todayRecord = _mapRecord(row);
    notifyListeners();

    if (early) {
      try {
        await AnomalyService.createEvent(
          type: 'early_clockout',
          details: 'Clocked out ${workEndMinutes - nowMinutes} min before the scheduled end time',
          severity: 'low',
          attendanceRecordId: _todayRecordId!,
        );
      } catch (_) {
        // Anomaly bookkeeping is secondary to the clock-out itself.
      }
    }

    return todayRecord;
  }
}

final attendanceController = AttendanceController();
