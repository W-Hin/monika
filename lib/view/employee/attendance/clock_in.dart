import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../../controller/attendance_controller.dart';
import '../../../model/models.dart';

enum _StepState { pending, checking, success, failed }

class ClockInScreen extends StatefulWidget {
  const ClockInScreen({super.key});

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  _StepState _gpsState = _StepState.pending;
  _StepState _wifiState = _StepState.pending;
  _StepState _deviceState = _StepState.pending;
  String _gpsDetail = 'Confirming you are within the office geofence';
  String _wifiDetail = 'Matching against registered office network';
  String _deviceDetail = 'Verifying this is your registered device';

  bool _isRunning = false;
  bool _isComplete = false;
  String _recordedTime = '';
  bool _flagged = false;
  String? _flagReason;
  String? _submitError;

  GpsCheckResult? _gpsResult;
  WifiCheckResult? _wifiResult;
  bool _showWifiPrompt = false;

  Future<void> _runValidation() async {
    setState(() {
      _isRunning = true;
      _submitError = null;
      _gpsState = _StepState.checking;
    });

    final gpsDelay = Future.delayed(const Duration(milliseconds: 500));
    final gpsResult = await attendanceController.runGpsCheck();
    await gpsDelay;
    if (!mounted) return;
    _gpsResult = gpsResult;
    setState(() {
      _gpsState = gpsResult.passed ? _StepState.success : _StepState.failed;
      _gpsDetail = gpsResult.detail;
    });

    await _runWifiStep();
  }

  Future<void> _runWifiStep() async {
    setState(() {
      _isRunning = true;
      _showWifiPrompt = false;
      _wifiState = _StepState.checking;
    });

    final wifiDelay = Future.delayed(const Duration(milliseconds: 500));
    final wifiResult = await attendanceController.runWifiCheck();
    await wifiDelay;
    if (!mounted) return;
    _wifiResult = wifiResult;
    setState(() {
      _wifiState = wifiResult.passed ? _StepState.success : _StepState.failed;
      _wifiDetail = wifiResult.detail;
    });

    if (!wifiResult.passed) {
      // Give the employee a chance to actually connect and retry before
      // this becomes a flagged record — most WiFi misses are a forgotten
      // toggle, not a genuine anomaly.
      setState(() {
        _isRunning = false;
        _showWifiPrompt = true;
      });
      return;
    }

    await _finishDeviceCheckAndSubmit();
  }

  Future<void> _continueWithoutWifi() async {
    setState(() {
      _isRunning = true;
      _showWifiPrompt = false;
    });
    await _finishDeviceCheckAndSubmit();
  }

  Future<void> _finishDeviceCheckAndSubmit() async {
    setState(() => _deviceState = _StepState.checking);

    final deviceDelay = Future.delayed(const Duration(milliseconds: 500));
    final deviceResult = await attendanceController.runDeviceCheck();
    await deviceDelay;
    if (!mounted) return;
    setState(() {
      _deviceState = deviceResult.passed
          ? _StepState.success
          : _StepState.failed;
      _deviceDetail = deviceResult.detail;
    });

    try {
      final record = await attendanceController.submitClockIn(
        gpsPassed: _gpsResult!.passed,
        gpsLat: _gpsResult!.lat,
        gpsLng: _gpsResult!.lng,
        wifiPassed: _wifiResult!.passed,
        wifiSsid: _wifiResult!.ssid,
        devicePassed: deviceResult.passed,
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _isComplete = true;
        _recordedTime = record.clockIn;
        _flagged = record.status == AttendanceStatus.flagged;
        _flagReason = record.flagReason;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _submitError =
            'Could not save your attendance — check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Clock In'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Triple-Layer Verification',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: c.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'MONIKA validates your location, network, and device to prevent proxy attendance.',
                style: TextStyle(
                  fontSize: 13,
                  color: c.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              Expanded(
                child: ListView(
                  children: [
                    _ValidationStep(
                      icon: Icons.my_location_rounded,
                      title: 'GPS Geofence Validation',
                      subtitle: _gpsDetail,
                      state: _gpsState,
                    ),
                    const SizedBox(height: 12),
                    _ValidationStep(
                      icon: Icons.wifi_rounded,
                      title: 'WiFi SSID Verification',
                      subtitle: _wifiDetail,
                      state: _wifiState,
                    ),
                    if (_showWifiPrompt) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: c.riskMediumBg,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.wifi_off_rounded,
                                  color: c.riskMedium,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Connect to "${attendanceController.officeWifiSsid}" and try again',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Switch to the office WiFi in your device settings, then retry — this is usually just a forgotten connection, not flagged unless it happens again.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: SecondaryButton(
                                    label: 'Retry',
                                    icon: Icons.refresh_rounded,
                                    onPressed: _runWifiStep,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextButton(
                                    onPressed: _continueWithoutWifi,
                                    child: const Text('Continue Anyway'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _ValidationStep(
                      icon: Icons.phone_android_rounded,
                      title: 'Device Token Binding',
                      subtitle: _deviceDetail,
                      state: _deviceState,
                    ),

                    if (_isComplete) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _flagged ? c.riskHighBg : c.riskLowBg,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [c.shadowTinted()],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: _flagged ? c.riskHigh : c.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _flagged
                                    ? Icons.flag_rounded
                                    : Icons.check_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _flagged
                                  ? 'Clock-In Recorded — Flagged for Review'
                                  : 'Clock-In Successful',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recorded at $_recordedTime',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: c.textSecondary,
                              ),
                            ),
                            if (_flagged && _flagReason != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                _flagReason!,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.riskHigh,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_submitError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.riskHighBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _submitError!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: c.riskHigh,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (!_isComplete && !_showWifiPrompt)
                PrimaryButton(
                  label: _isRunning ? 'Verifying…' : 'Start Verification',
                  icon: _isRunning ? null : Icons.play_arrow_rounded,
                  isLoading: _isRunning,
                  onPressed: _isRunning ? null : _runValidation,
                )
              else if (_isComplete)
                PrimaryButton(
                  label: 'Done',
                  icon: Icons.check_rounded,
                  onPressed: () => Navigator.of(context).pop(_recordedTime),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValidationStep extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final _StepState state;

  const _ValidationStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Color iconColor;
    Color iconBg;
    Widget trailing;

    switch (state) {
      case _StepState.pending:
        iconColor = c.textMuted;
        iconBg = c.surfaceMuted;
        trailing = Icon(
          Icons.radio_button_unchecked_rounded,
          color: c.textMuted,
          size: 22,
        );
        break;
      case _StepState.checking:
        iconColor = c.primary;
        iconBg = c.primaryLight;
        trailing = SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: c.primary),
        );
        break;
      case _StepState.success:
        iconColor = c.primary;
        iconBg = c.primaryLight;
        trailing = Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 15),
        );
        break;
      case _StepState.failed:
        iconColor = c.riskHigh;
        iconBg = c.riskHighBg;
        trailing = Icon(Icons.cancel_rounded, color: c.riskHigh, size: 22);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          state == _StepState.success ? c.shadowTinted() : c.shadowNeutral,
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11.5, color: c.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}
