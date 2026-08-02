import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../../controller/attendance_controller.dart';

enum _StepState { pending, checking, success, failed }

class ClockOutScreen extends StatefulWidget {
  const ClockOutScreen({super.key});

  @override
  State<ClockOutScreen> createState() => _ClockOutScreenState();
}

class _ClockOutScreenState extends State<ClockOutScreen> {
  _StepState _gpsState = _StepState.pending;
  String _gpsDetail = 'Confirming you are within the office geofence';
  bool _isRunning = false;
  bool _isComplete = false;
  String _recordedTime = '';
  String? _submitError;

  Future<void> _runValidation() async {
    setState(() {
      _isRunning = true;
      _submitError = null;
      _gpsState = _StepState.checking;
    });

    final delay = Future.delayed(const Duration(milliseconds: 500));
    final gpsResult = await attendanceController.runGpsCheck();
    await delay;
    if (!mounted) return;
    setState(() {
      _gpsState = gpsResult.passed ? _StepState.success : _StepState.failed;
      _gpsDetail = gpsResult.detail;
    });

    try {
      final record = await attendanceController.submitClockOut();
      if (!mounted) return;
      if (record == null) {
        setState(() {
          _isRunning = false;
          _submitError = 'No clock-in record found for today — clock in first.';
        });
        return;
      }
      setState(() {
        _isRunning = false;
        _isComplete = true;
        _recordedTime = record.clockOut ?? '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _submitError = 'Could not save your clock-out — check your connection and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Clock Out'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'End of Day Clock-Out',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'MONIKA confirms your location before recording your clock-out time.',
                style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
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
                    if (_isComplete) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.riskLowBg,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [c.shadowTinted()],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(color: c.primary, shape: BoxShape.circle),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 30),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Clock-Out Successful',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recorded at $_recordedTime',
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_submitError != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(12)),
                        child: Text(_submitError!, style: TextStyle(fontSize: 12.5, color: c.riskHigh, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
              if (!_isComplete)
                PrimaryButton(
                  label: _isRunning ? 'Verifying…' : 'Start Verification',
                  icon: _isRunning ? null : Icons.play_arrow_rounded,
                  isLoading: _isRunning,
                  onPressed: _isRunning ? null : _runValidation,
                )
              else
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
        trailing = Icon(Icons.radio_button_unchecked_rounded, color: c.textMuted, size: 22);
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
        boxShadow: [state == _StepState.success ? c.shadowTinted() : c.shadowNeutral],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                const SizedBox(height: 3),
                Text(subtitle, style: TextStyle(fontSize: 11.5, color: c.textMuted)),
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
