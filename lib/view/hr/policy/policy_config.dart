import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';

class PolicyConfigScreen extends StatefulWidget {
  const PolicyConfigScreen({super.key});

  @override
  State<PolicyConfigScreen> createState() => _PolicyConfigScreenState();
}

class _PolicyConfigScreenState extends State<PolicyConfigScreen> {
  // Attendance policy
  final _workStart = TextEditingController(text: '09:00');
  final _workEnd = TextEditingController(text: '18:00');
  final _gracePeriod = TextEditingController(text: '10');
  final _geofenceRadius = TextEditingController(text: '100');
  final _officeWifi = TextEditingController(text: 'MONIKA-OFFICE-5G');

  // Risk score weights
  double _lateWeight = 1;
  double _outOfZoneWeight = 2;
  double _sharedDeviceWeight = 3;
  double _wifiMismatchWeight = 1;

  // Payroll deductions
  final _lateDeduction = TextEditingController(text: '25.00');
  final _absentDeduction = TextEditingController(text: '120.00');
  final _unpaidLeaveRate = TextEditingController(text: '120.00');

  // Training trigger thresholds
  double _leadershipThreshold = 60;
  double _technicalThreshold = 65;
  double _behaviouralThreshold = 60;

  bool _saving = false;

  void _save() {
    setState(() => _saving = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Policy configuration saved successfully')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Policy & Configuration'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PrimaryButton(label: 'Save', onPressed: _save, isLoading: _saving, expand: false),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [

            // ── Attendance Policy ──────────────────────────────────
            _SectionCard(
              icon: Icons.fingerprint_rounded,
              color: AppColors.primary,
              bg: AppColors.primaryLight,
              title: 'Attendance Policy',
              subtitle: 'Configure working hours, grace period, and IoT verification settings',
              children: [
                Row(
                  children: [
                    Expanded(child: _Field(label: 'Work Start Time', controller: _workStart, hint: '09:00', icon: Icons.login_rounded)),
                    const SizedBox(width: 12),
                    Expanded(child: _Field(label: 'Work End Time', controller: _workEnd, hint: '18:00', icon: Icons.logout_rounded)),
                  ],
                ),
                const SizedBox(height: 14),
                _Field(label: 'Grace Period (minutes)', controller: _gracePeriod, hint: '10', icon: Icons.timer_outlined, keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _Field(label: 'Geofence Radius (metres)', controller: _geofenceRadius, hint: '100', icon: Icons.my_location_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 14),
                _Field(label: 'Registered Office WiFi SSID', controller: _officeWifi, hint: 'OFFICE-WIFI-5G', icon: Icons.wifi_rounded),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: AppColors.primaryDark),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clock-in requires: GPS within geofence radius AND connected to office WiFi AND registered device token. All three must pass.',
                          style: TextStyle(fontSize: 11.5, color: AppColors.primaryDark, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Risk Score Weights ─────────────────────────────────
            _SectionCard(
              icon: Icons.shield_outlined,
              color: AppColors.riskHigh,
              bg: AppColors.riskHighBg,
              title: 'Risk Score Deduction Weights',
              subtitle: 'Points deducted from employee risk score per violation type',
              children: [
                _SliderRow(label: 'Late Arrival', value: _lateWeight, min: 1, max: 5, onChanged: (v) => setState(() => _lateWeight = v), color: AppColors.riskLow),
                _SliderRow(label: 'WiFi SSID Mismatch', value: _wifiMismatchWeight, min: 1, max: 5, onChanged: (v) => setState(() => _wifiMismatchWeight = v), color: AppColors.riskMedium),
                _SliderRow(label: 'Out-of-Zone Clock-In', value: _outOfZoneWeight, min: 1, max: 5, onChanged: (v) => setState(() => _outOfZoneWeight = v), color: AppColors.riskMedium),
                _SliderRow(label: 'Shared-Device Attempt', value: _sharedDeviceWeight, min: 1, max: 5, onChanged: (v) => setState(() => _sharedDeviceWeight = v), color: AppColors.riskHigh),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Risk Tiers: Score ≥ 80 = Low Risk   |   50–79 = Medium Risk   |   < 50 = High Risk',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // ── Payroll Deductions ─────────────────────────────────
            _SectionCard(
              icon: Icons.account_balance_wallet_outlined,
              color: AppColors.purple,
              bg: AppColors.purpleBg,
              title: 'Payroll Deduction Rules',
              subtitle: 'Configurable deduction amounts applied during payroll computation (RM)',
              children: [
                _Field(label: 'Late Arrival Deduction (per occurrence)', controller: _lateDeduction, hint: '25.00', icon: Icons.remove_circle_outline_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 14),
                _Field(label: 'Unauthorised Absence (per day)', controller: _absentDeduction, hint: '120.00', icon: Icons.event_busy_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 14),
                _Field(label: 'Unpaid Leave Daily Rate (RM)', controller: _unpaidLeaveRate, hint: '120.00', icon: Icons.money_off_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.purpleBg, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Approved Annual and Medical leave will not trigger deductions. Deductions are applied automatically at payroll computation time.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.purple, height: 1.4),
                  ),
                ),
              ],
            ),

            // ── Training Trigger Thresholds ────────────────────────
            _SectionCard(
              icon: Icons.auto_awesome_rounded,
              color: AppColors.amber,
              bg: AppColors.amberBg,
              title: 'Training Recommendation Triggers',
              subtitle: 'KPI scores below these thresholds automatically trigger training recommendations in the ML engine',
              children: [
                _SliderRow(label: 'Leadership KPI trigger threshold', value: _leadershipThreshold, min: 40, max: 80, divisions: 8, onChanged: (v) => setState(() => _leadershipThreshold = v), color: AppColors.purple, suffix: '/100'),
                _SliderRow(label: 'Technical KPI trigger threshold', value: _technicalThreshold, min: 40, max: 80, divisions: 8, onChanged: (v) => setState(() => _technicalThreshold = v), color: AppColors.infoBlue, suffix: '/100'),
                _SliderRow(label: 'Behavioural KPI trigger threshold', value: _behaviouralThreshold, min: 40, max: 80, divisions: 8, onChanged: (v) => setState(() => _behaviouralThreshold = v), color: AppColors.amber, suffix: '/100'),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppColors.amberBg, borderRadius: BorderRadius.circular(10)),
                  child: const Text(
                    'Example: If Leadership threshold is 60 and an employee scores 55 on Leadership KPI, a Leadership training programme will be automatically recommended.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.amber, height: 1.4),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save All Changes',
              icon: Icons.save_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.color,
    required this.bg,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: AppColors.textMuted),
          ),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;
  final Color color;
  final String suffix;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.color,
    this.divisions,
    this.suffix = ' pts',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(100)),
                child: Text('${value.toInt()}$suffix', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withOpacity(0.15),
              overlayColor: color.withOpacity(0.1),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions ?? (max - min).toInt(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}