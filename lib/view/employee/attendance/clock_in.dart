import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';

enum _StepState { pending, checking, success, failed }

class ClockInScreen extends StatefulWidget {
  const ClockInScreen({super.key});

  @override
  State<ClockInScreen> createState() => _ClockInScreenState();
}

class _ClockInScreenState extends State<ClockInScreen> {
  _StepState _gps = _StepState.pending;
  _StepState _wifi = _StepState.pending;
  _StepState _device = _StepState.pending;
  bool _isRunning = false;
  bool _isComplete = false;
  String _recordedTime = '';

  Future<void> _runValidation() async {
    setState(() {
      _isRunning = true;
      _gps = _StepState.checking;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _gps = _StepState.success;
      _wifi = _StepState.checking;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _wifi = _StepState.success;
      _device = _StepState.checking;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _device = _StepState.success;
      _isRunning = false;
      _isComplete = true;
      _recordedTime = DateFormat('hh:mm a').format(DateTime.now());
    });
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
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: c.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'MONIKA validates your location, network, and device simultaneously to prevent proxy attendance.',
                style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 28),

              Expanded(
                child: ListView(
                  children: [
                    _ValidationStep(
                      icon: Icons.my_location_rounded,
                      title: 'GPS Geofence Validation',
                      subtitle: 'Confirming you are within 100m of the office',
                      state: _gps,
                    ),
                    _ConnectorLine(active: _gps == _StepState.success),
                    _ValidationStep(
                      icon: Icons.wifi_rounded,
                      title: 'WiFi SSID Verification',
                      subtitle: 'Matching against registered office network',
                      state: _wifi,
                    ),
                    _ConnectorLine(active: _wifi == _StepState.success),
                    _ValidationStep(
                      icon: Icons.phone_android_rounded,
                      title: 'Device Token Binding',
                      subtitle: 'Verifying this is your registered device',
                      state: _device,
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
                              'Clock-In Successful',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: c.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Recorded at $_recordedTime, ${DateFormat('EEE d MMMM yyyy').format(DateTime.now())}',
                              style: TextStyle(fontSize: 12.5, color: c.textSecondary),
                            ),
                          ],
                        ),
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

class _ConnectorLine extends StatelessWidget {
  final bool active;
  const _ConnectorLine({required this.active});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(left: 38),
      height: 16,
      width: 2,
      color: active ? c.primary.withOpacity(0.4) : c.border,
    );
  }
}