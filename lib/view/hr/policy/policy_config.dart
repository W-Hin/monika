import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../controller/policy_controller.dart';

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
  double _lateWeight = Defaults.lateWeight;
  double _outOfZoneWeight = Defaults.outOfZoneWeight;
  double _sharedDeviceWeight = Defaults.sharedDeviceWeight;
  double _wifiMismatchWeight = Defaults.wifiMismatchWeight;
  double _earlyClockoutWeight = Defaults.earlyClockoutWeight;
  double _unexplainedAbsenceWeight = Defaults.unexplainedAbsenceWeight;
  double _riskResetPeriodMonths = Defaults.riskResetPeriodMonths.toDouble();
  double _riskPenaltyPercent = Defaults.riskPenaltyPercent;

  // Payroll deductions
  final _lateDeduction = TextEditingController(text: '25.00');
  final _absentDeduction = TextEditingController(text: '120.00');
  final _unpaidLeaveRate = TextEditingController(text: '120.00');

  // Training trigger thresholds
  double _leadershipThreshold = 60;
  double _technicalThreshold = 65;
  double _behaviouralThreshold = 60;
  double _minTenureMonths = 6;

  bool _saving = false;
  bool _hydrated = false;
  bool _hasEdited = false;

  @override
  void initState() {
    super.initState();
    policyController.load();
    for (final controller in [_workStart, _workEnd, _gracePeriod, _geofenceRadius, _officeWifi, _lateDeduction, _absentDeduction, _unpaidLeaveRate]) {
      controller.addListener(_markEdited);
    }
  }

  @override
  void dispose() {
    for (final controller in [_workStart, _workEnd, _gracePeriod, _geofenceRadius, _officeWifi, _lateDeduction, _absentDeduction, _unpaidLeaveRate]) {
      controller.dispose();
    }
    super.dispose();
  }

  // Only counts as an edit once the fields have been hydrated from the
  // real loaded values — the programmatic `.text = ...` assignments inside
  // _hydrateFromController() also fire this listener, and that's not a
  // user edit.
  void _markEdited() {
    if (_hydrated && !_hasEdited) setState(() => _hasEdited = true);
  }

  /// Populates the local editable fields from the just-loaded real
  /// values. Guarded by _hydrated so it only runs once — after that,
  /// the fields are the user's own in-progress edits, not something to
  /// keep overwriting every time the controller notifies.
  void _hydrateFromController() {
    final p = policyController;
    _workStart.text = p.workStartTime;
    _workEnd.text = p.workEndTime;
    _gracePeriod.text = '${p.gracePeriodMinutes}';
    _geofenceRadius.text = '${p.geofenceRadiusMeters}';
    _officeWifi.text = p.officeWifiSsid;
    _lateWeight = p.lateWeight;
    _outOfZoneWeight = p.outOfZoneWeight;
    _sharedDeviceWeight = p.sharedDeviceWeight;
    _wifiMismatchWeight = p.wifiMismatchWeight;
    _earlyClockoutWeight = p.earlyClockoutWeight;
    _unexplainedAbsenceWeight = p.unexplainedAbsenceWeight;
    _riskResetPeriodMonths = p.riskResetPeriodMonths.toDouble();
    _riskPenaltyPercent = p.riskPenaltyPercent;
    _lateDeduction.text = p.lateDeduction.toStringAsFixed(2);
    _absentDeduction.text = p.absentDeduction.toStringAsFixed(2);
    _unpaidLeaveRate.text = p.unpaidLeaveDailyRate.toStringAsFixed(2);
    _leadershipThreshold = p.leadershipThreshold;
    _technicalThreshold = p.technicalThreshold;
    _behaviouralThreshold = p.behaviouralThreshold;
    _minTenureMonths = p.minTenureMonths.toDouble();
    _hydrated = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final success = await policyController.save(
      workStartTime: _workStart.text.trim(),
      workEndTime: _workEnd.text.trim(),
      gracePeriodMinutes: int.tryParse(_gracePeriod.text.trim()) ?? policyController.gracePeriodMinutes,
      geofenceRadiusMeters: int.tryParse(_geofenceRadius.text.trim()) ?? policyController.geofenceRadiusMeters,
      officeWifiSsid: _officeWifi.text.trim(),
      lateWeight: _lateWeight,
      outOfZoneWeight: _outOfZoneWeight,
      sharedDeviceWeight: _sharedDeviceWeight,
      wifiMismatchWeight: _wifiMismatchWeight,
      earlyClockoutWeight: _earlyClockoutWeight,
      unexplainedAbsenceWeight: _unexplainedAbsenceWeight,
      riskResetPeriodMonths: _riskResetPeriodMonths.round(),
      riskPenaltyPercent: _riskPenaltyPercent,
      lateDeduction: double.tryParse(_lateDeduction.text.trim()) ?? policyController.lateDeduction,
      absentDeduction: double.tryParse(_absentDeduction.text.trim()) ?? policyController.absentDeduction,
      unpaidLeaveDailyRate: double.tryParse(_unpaidLeaveRate.text.trim()) ?? policyController.unpaidLeaveDailyRate,
      leadershipThreshold: _leadershipThreshold,
      technicalThreshold: _technicalThreshold,
      behaviouralThreshold: _behaviouralThreshold,
      minTenureMonths: _minTenureMonths.round(),
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (success) _hasEdited = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✓ Policy configuration saved successfully' : policyController.errorMessage ?? 'Could not save policy configuration'),
      ),
    );
  }

  /// Restores every field to Defaults (the same constants policy_settings'
  /// columns default to) and saves immediately — HR confirms once via the
  /// dialog rather than a silent local-only reset they'd still need to
  /// remember to press Save on.
  Future<void> _confirmResetToDefaults() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset to Default?'),
        content: const Text('Every field on this screen will be restored to MONIKA\'s system default values and saved immediately. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Reset', style: TextStyle(color: context.colors.riskHigh)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _workStart.text = '09:00';
      _workEnd.text = '18:00';
      _gracePeriod.text = '10';
      _geofenceRadius.text = '100';
      _officeWifi.text = 'MONIKA-OFFICE-5G';
      _lateWeight = Defaults.lateWeight;
      _outOfZoneWeight = Defaults.outOfZoneWeight;
      _sharedDeviceWeight = Defaults.sharedDeviceWeight;
      _wifiMismatchWeight = Defaults.wifiMismatchWeight;
      _earlyClockoutWeight = Defaults.earlyClockoutWeight;
      _unexplainedAbsenceWeight = Defaults.unexplainedAbsenceWeight;
      _riskResetPeriodMonths = Defaults.riskResetPeriodMonths.toDouble();
      _riskPenaltyPercent = Defaults.riskPenaltyPercent;
      _lateDeduction.text = Defaults.lateDeduction.toStringAsFixed(2);
      _absentDeduction.text = Defaults.absentDeduction.toStringAsFixed(2);
      _unpaidLeaveRate.text = Defaults.unpaidLeaveDailyRate.toStringAsFixed(2);
      _leadershipThreshold = Defaults.leadershipThreshold;
      _technicalThreshold = Defaults.technicalThreshold;
      _behaviouralThreshold = Defaults.behaviouralThreshold;
      _minTenureMonths = Defaults.minTenureMonths.toDouble();
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return UnsavedChangesGuard(
      isDirty: _hasEdited,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Policy & Configuration'),
        actions: [
          IconButton(
            tooltip: 'Reset to Default',
            onPressed: _confirmResetToDefaults,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: policyController,
          builder: (context, _) {
            if (!policyController.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!_hydrated) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(_hydrateFromController);
              });
            }
            return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            // ── Attendance Policy ──────────────────────────────────
            _SectionCard(
              icon: Icons.fingerprint_rounded,
              color: c.primary,
              bg: c.primaryLight,
              title: 'Attendance Policy',
              subtitle:
                  'Configure working hours, grace period, and IoT verification settings',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _Field(
                        label: 'Work Start Time',
                        controller: _workStart,
                        hint: '09:00',
                        icon: Icons.login_rounded,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Field(
                        label: 'Work End Time',
                        controller: _workEnd,
                        hint: '18:00',
                        icon: Icons.logout_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Grace Period (minutes)',
                  controller: _gracePeriod,
                  hint: '10',
                  icon: Icons.timer_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Geofence Radius (metres)',
                  controller: _geofenceRadius,
                  hint: '100',
                  icon: Icons.my_location_rounded,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Registered Office WiFi SSID',
                  controller: _officeWifi,
                  hint: 'OFFICE-WIFI-5G',
                  icon: Icons.wifi_rounded,
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14,
                        color: c.primaryDark,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Clock-in requires: GPS within geofence radius AND connected to office WiFi AND registered device token. All three must pass.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: c.primaryDark,
                            height: 1.4,
                          ),
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
              color: c.riskHigh,
              bg: c.riskHighBg,
              title: 'Risk Score Deduction Weights',
              subtitle:
                  'Points deducted from employee risk score per violation type',
              children: [
                _SliderRow(
                  label: 'Late Arrival',
                  value: _lateWeight,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() { _lateWeight = v; _hasEdited = true; }),
                  color: c.riskLow,
                ),
                _SliderRow(
                  label: 'WiFi SSID Mismatch',
                  value: _wifiMismatchWeight,
                  min: 1,
                  max: 25,
                  onChanged: (v) => setState(() { _wifiMismatchWeight = v; _hasEdited = true; }),
                  color: c.riskMedium,
                ),
                _SliderRow(
                  label: 'Out-of-Zone Clock-In',
                  value: _outOfZoneWeight,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() { _outOfZoneWeight = v; _hasEdited = true; }),
                  color: c.riskMedium,
                ),
                _SliderRow(
                  label: 'Shared-Device Attempt',
                  value: _sharedDeviceWeight,
                  min: 1,
                  max: 50,
                  onChanged: (v) => setState(() { _sharedDeviceWeight = v; _hasEdited = true; }),
                  color: c.riskHigh,
                ),
                _SliderRow(
                  label: 'Early Clock-Out',
                  value: _earlyClockoutWeight,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() { _earlyClockoutWeight = v; _hasEdited = true; }),
                  color: c.riskLow,
                ),
                _SliderRow(
                  label: 'Unexplained Absence',
                  value: _unexplainedAbsenceWeight,
                  min: 1,
                  max: 30,
                  onChanged: (v) => setState(() { _unexplainedAbsenceWeight = v; _hasEdited = true; }),
                  color: c.riskMedium,
                ),
                const SizedBox(height: 4),
                _SliderRow(
                  label: 'Automatic Reset Period',
                  value: _riskResetPeriodMonths,
                  min: 1,
                  max: 12,
                  divisions: 11,
                  onChanged: (v) => setState(() { _riskResetPeriodMonths = v; _hasEdited = true; }),
                  color: c.infoBlue,
                  suffix: ' mo',
                ),
                _SliderRow(
                  label: 'Salary Penalty at Score 0',
                  value: _riskPenaltyPercent,
                  min: 1,
                  max: 20,
                  onChanged: (v) => setState(() { _riskPenaltyPercent = v; _hasEdited = true; }),
                  color: c.riskHigh,
                  suffix: '%',
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Risk Tiers: Score ≥ 80 = Low Risk   |   50–79 = Medium Risk   |   < 50 = High Risk\n'
                    'A score hitting 0 immediately resets to 100 and applies the salary penalty above at the next payroll run. Every employee\'s score also resets to 100 on its own after the automatic reset period, even without hitting 0.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),

            // ── Payroll Deductions ─────────────────────────────────
            _SectionCard(
              icon: Icons.account_balance_wallet_outlined,
              color: c.purple,
              bg: c.purpleBg,
              title: 'Payroll Deduction Rules',
              subtitle:
                  'Configurable deduction amounts applied during payroll computation (RM)',
              children: [
                _Field(
                  label: 'Late Arrival Deduction (per occurrence)',
                  controller: _lateDeduction,
                  hint: '25.00',
                  icon: Icons.remove_circle_outline_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Unauthorised Absence (per day)',
                  controller: _absentDeduction,
                  hint: '120.00',
                  icon: Icons.event_busy_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                _Field(
                  label: 'Unpaid Leave Daily Rate (RM)',
                  controller: _unpaidLeaveRate,
                  hint: '120.00',
                  icon: Icons.money_off_rounded,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.purpleBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Approved Annual and Medical leave will not trigger deductions. Deductions are applied automatically at payroll computation time.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.purple,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),

            // ── Training Trigger Thresholds ────────────────────────
            _SectionCard(
              icon: Icons.auto_awesome_rounded,
              color: c.amber,
              bg: c.amberBg,
              title: 'Training Recommendation Triggers',
              subtitle:
                  'KPI scores below these thresholds automatically trigger training recommendations in the ML engine',
              children: [
                _SliderRow(
                  label: 'Leadership KPI trigger threshold',
                  value: _leadershipThreshold,
                  min: 40,
                  max: 80,
                  divisions: 8,
                  onChanged: (v) => setState(() { _leadershipThreshold = v; _hasEdited = true; }),
                  color: c.purple,
                  suffix: '/100',
                ),
                _SliderRow(
                  label: 'Technical KPI trigger threshold',
                  value: _technicalThreshold,
                  min: 40,
                  max: 80,
                  divisions: 8,
                  onChanged: (v) => setState(() { _technicalThreshold = v; _hasEdited = true; }),
                  color: c.infoBlue,
                  suffix: '/100',
                ),
                _SliderRow(
                  label: 'Behavioural KPI trigger threshold',
                  value: _behaviouralThreshold,
                  min: 40,
                  max: 80,
                  divisions: 8,
                  onChanged: (v) => setState(() { _behaviouralThreshold = v; _hasEdited = true; }),
                  color: c.amber,
                  suffix: '/100',
                ),
                _SliderRow(
                  label: 'Minimum tenure before eligible',
                  value: _minTenureMonths,
                  min: 0,
                  max: 24,
                  divisions: 24,
                  onChanged: (v) => setState(() { _minTenureMonths = v; _hasEdited = true; }),
                  color: c.textSecondary,
                  suffix: ' mo',
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: c.amberBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Example: If Leadership threshold is 60 and an employee scores 55 on Leadership KPI, a Leadership training programme will be automatically recommended. Employees below the minimum tenure are skipped entirely.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.amber,
                      height: 1.4,
                    ),
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
            );
          },
        ),
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
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [c.shadowNeutral],
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
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: c.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
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
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: c.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: c.textMuted),
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
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: c.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '${value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1)}$suffix',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              thumbColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.15),
              overlayColor: color.withValues(alpha: 0.1),
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
