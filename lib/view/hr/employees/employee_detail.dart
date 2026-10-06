import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../model/models.dart';
import '../../../connection/employee_service.dart';
import '../../../connection/training_insight_service.dart';

class EmployeeDetailScreen extends StatefulWidget {
  final TeamMemberSummary employee;
  final ValueChanged<TeamMemberSummary> onUpdate;

  const EmployeeDetailScreen({super.key, required this.employee, required this.onUpdate});

  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  late TeamMemberSummary _emp;
  bool _isEditing = false;
  bool _isSaving = false;
  late String _department;
  late String _jobTitle;
  late TextEditingController _salaryController;

  // ML training insight: loading until the first fetch finishes; null
  // insight with no error means no model has been uploaded yet.
  bool _insightLoading = true;
  bool _insightFailed = false;
  TrainingInsight? _insight;

  final _departments = ['Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];
  final _jobTitles = ['Employee', 'Senior Engineer', 'Team Lead', 'Manager', 'Designer', 'Analyst', 'Consultant', 'Mobile Developer', 'Backend Engineer', 'UI/UX Designer', 'Sales Executive', 'Operations Executive', 'Marketing Executive', 'Intern'];

  @override
  void initState() {
    super.initState();
    _emp = widget.employee;
    _department = _emp.department;
    _jobTitle = _emp.jobTitle;
    _salaryController = TextEditingController(text: _emp.baseSalary?.toStringAsFixed(2) ?? '');
    _salaryController.addListener(() => setState(() {}));
    if (!_departments.contains(_department)) _departments.add(_department);
    if (!_jobTitles.contains(_jobTitle)) _jobTitles.add(_jobTitle);
    _loadInsight();
  }

  Future<void> _loadInsight() async {
    try {
      final insight = await TrainingInsightService.fetch(_emp.uuid);
      if (!mounted) return;
      setState(() {
        _insight = insight;
        _insightFailed = false;
        _insightLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _insightFailed = true;
        _insightLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _salaryController.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _isEditing &&
      (_department != _emp.department ||
          _jobTitle != _emp.jobTitle ||
          _salaryController.text != (_emp.baseSalary?.toStringAsFixed(2) ?? ''));

  /// The 1st of next calendar month — used as the "official" effective
  /// date communicated in the change-notification email. The database
  /// itself updates immediately (HR sees the new role/department/salary
  /// right away); this date is purely what's told to the employee as when
  /// the change is administratively/payroll effective.
  DateTime get _nextMonthFirst {
    final now = DateTime.now();
    return DateTime(now.year, now.month + 1, 1);
  }

  static const _monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  String _formatDate(DateTime date) => '${date.day} ${_monthNames[date.month - 1]} ${date.year}';

  /// HR admins must not be able to change their own job title, department,
  /// or salary — that's a self-approval/conflict-of-interest hole. Enforced
  /// here (hides the edit affordance) and at the RLS layer (migration 0007)
  /// so a bypassed client can't do it either. Any change to an HR admin's
  /// own record must come from another HR admin.
  bool get _isSelf => Supabase.instance.client.auth.currentUser?.id == _emp.uuid;

  Future<void> _saveChanges() async {
    final oldJobTitle = _emp.jobTitle;
    final oldDepartment = _emp.department;
    final oldSalary = _emp.baseSalary;
    final newSalary = double.tryParse(_salaryController.text.trim());

    final changed = oldJobTitle != _jobTitle || oldDepartment != _department || oldSalary != newSalary;
    if (!changed) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await EmployeeService.updateEmployment(
        uuid: _emp.uuid,
        jobTitle: _jobTitle,
        departmentName: _department,
        baseSalary: newSalary,
      );
      if (!mounted) return;
      setState(() {
        _emp = _emp.copyWith(department: _department, jobTitle: _jobTitle, baseSalary: newSalary, isIntern: _jobTitle == 'Intern');
        _isEditing = false;
        _isSaving = false;
      });
      widget.onUpdate(_emp);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✓ Employment details updated')),
      );

      // Best-effort — a failed notification email doesn't undo the save.
      unawaited(_sendChangeNotification(
        oldJobTitle: oldJobTitle,
        oldDepartment: oldDepartment,
        oldSalary: oldSalary,
        newSalary: newSalary,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save changes: $e')),
      );
    }
  }

  Future<void> _sendChangeNotification({
    required String oldJobTitle,
    required String oldDepartment,
    required double? oldSalary,
    required double? newSalary,
  }) async {
    if (_emp.email.isEmpty) return;
    try {
      await Supabase.instance.client.functions.invoke(
        'notify-employee-change',
        body: {
          'email': _emp.email,
          'name': _emp.name,
          'oldJobTitle': oldJobTitle,
          'newJobTitle': _jobTitle,
          'oldDepartment': oldDepartment,
          'newDepartment': _department,
          'oldSalary': oldSalary,
          'newSalary': newSalary,
          'effectiveDate': _nextMonthFirst.toIso8601String().split('T').first,
        },
      );
    } catch (_) {
      // Silent — this is a courtesy notification, not visible feedback HR
      // is waiting on. The change itself already saved successfully.
    }
  }

  void _toggleActive() {
    final activating = !_emp.isActive;
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(activating ? 'Reactivate Account' : 'Deactivate Account'),
          content: Text(
            activating
                ? '${_emp.name} will regain access to MONIKA immediately.'
                : '${_emp.name} will lose access to MONIKA immediately. This can be reversed at any time.',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: activating ? c.primary : c.riskHigh),
              onPressed: () async {
                try {
                  await EmployeeService.setActive(uuid: _emp.uuid, isActive: activating);
                  if (!mounted) return;
                  setState(() => _emp = _emp.copyWith(isActive: activating));
                  widget.onUpdate(_emp);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(activating ? '✓ Account reactivated' : '✓ Account deactivated')),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not update account: $e')),
                  );
                }
              },
              child: Text(activating ? 'Reactivate' : 'Deactivate'),
            ),
          ],
        );
      },
    );
  }

  void _resetRiskScore() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Risk Score'),
          content: Text(
            '${_emp.name}\'s risk score will be reset to 100 (Low Risk). This does not undo any past anomaly events — it only clears the accumulated score, typically after they\'ve addressed whatever drove it down.',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: c.primary),
              onPressed: () async {
                try {
                  await EmployeeService.resetRiskScore(_emp.uuid);
                  if (!mounted) return;
                  setState(() => _emp = _emp.copyWith(risk: RiskLevel.low));
                  widget.onUpdate(_emp);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Risk score reset to 100 (Low Risk)')),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not reset risk score: $e')),
                  );
                }
              },
              child: const Text('Reset to 100'),
            ),
          ],
        );
      },
    );
  }

  /// Best-effort — picks up changes another HR admin may have made to this
  /// employee concurrently (role, department, salary, risk score, device,
  /// active status). Skipped while actively editing so an in-progress edit
  /// isn't silently overwritten mid-pull.
  Future<void> _refresh() async {
    if (_isEditing) return;
    unawaited(_loadInsight());
    try {
      final row = await EmployeeService.fetchOne(_emp.uuid);
      if (row == null || !mounted) return;
      final risk = RiskLevel.values.firstWhere((r) => r.name == row['risk_level'], orElse: () => _emp.risk);
      final deptName = (row['departments'] as Map<String, dynamic>?)?['name'] as String? ?? _emp.department;
      setState(() {
        _emp = _emp.copyWith(
          jobTitle: row['job_title'] as String? ?? _emp.jobTitle,
          department: deptName,
          risk: risk,
          isActive: row['is_active'] as bool? ?? _emp.isActive,
          registeredDevice: row['registered_device_name'] as String? ?? 'Not yet registered',
          baseSalary: (row['base_salary'] as num?)?.toDouble(),
          isIntern: row['is_intern'] as bool? ?? _emp.isIntern,
        );
        _department = _emp.department;
        _jobTitle = _emp.jobTitle;
            _salaryController.text = _emp.baseSalary?.toStringAsFixed(2) ?? '';
      });
      widget.onUpdate(_emp);
    } catch (_) {
      // Best-effort — worst case the screen just keeps showing stale data
      // until the next successful refresh.
    }
  }

  void _resetDeviceBinding() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final c = dialogContext.colors;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Reset Device Binding'),
          content: Text(
            'This will unbind "${_emp.registeredDevice}" from ${_emp.name}\'s account. They will need to register a new device on their next clock-in attempt.',
            style: TextStyle(fontSize: 13, color: c.textSecondary, height: 1.4),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: c.riskHigh),
              onPressed: () async {
                try {
                  await EmployeeService.resetDeviceBinding(_emp.uuid);
                  if (!mounted) return;
                  setState(() => _emp = _emp.copyWith(registeredDevice: 'Not yet registered'));
                  widget.onUpdate(_emp);
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✓ Device binding reset')),
                  );
                } catch (e) {
                  Navigator.of(dialogContext).pop();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not reset device binding: $e')),
                  );
                }
              },
              child: const Text('Reset Binding'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return UnsavedChangesGuard(
      isDirty: _isDirty,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        actions: [
          if (!_isSelf)
            if (!_isEditing)
              IconButton(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit_outlined))
            else
              TextButton(onPressed: _isSaving ? null : _saveChanges, child: Text(_isSaving ? 'Saving…' : 'Save')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Center(
              child: Column(
                children: [
                  InitialsAvatar(initials: _emp.avatarInitials, size: 72),
                  const SizedBox(height: 12),
                  Text(_emp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('${_emp.jobTitle} · ${_emp.department}', style: TextStyle(fontSize: 12.5, color: c.textSecondary)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StatusPill.risk(_emp.risk),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _emp.isActive ? c.riskLowBg : c.surfaceMuted,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          _emp.isActive ? 'Active' : 'Deactivated',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _emp.isActive ? c.primary : c.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Account Information'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _InfoRow(icon: Icons.badge_outlined, label: 'Employee ID', value: _emp.id),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.mail_outline_rounded, label: 'Email', value: _emp.email),
                  const Divider(height: 1, indent: 56),
                  _InfoRow(icon: Icons.event_available_rounded, label: 'Attendance Rate', value: '${(_emp.attendanceRate * 100).toInt()}%'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Role & Department'),
            if (_isEditing)
              AppCard(
                child: Column(
                  children: [
                    _DropdownField(label: 'Job Title', value: _jobTitle, items: _jobTitles, onChanged: (v) => setState(() => _jobTitle = v!)),
                    const SizedBox(height: 14),
                    _DropdownField(label: 'Department', value: _department, items: _departments, onChanged: (v) => setState(() => _department = v!)),
                    const SizedBox(height: 14),
                    const SizedBox(height: 14),
                    Text('Basic Monthly Salary (RM)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _salaryController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: '3500.00', prefixText: 'RM '),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: c.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        'Any change is saved immediately, and the employee is emailed with an official effective date of ${_formatDate(_nextMonthFirst)}.',
                        style: TextStyle(fontSize: 11.5, color: c.infoBlue, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )
            else
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _InfoRow(icon: Icons.work_outline_rounded, label: 'Job Title', value: _emp.jobTitle),
                    const Divider(height: 1, indent: 56),
                    _InfoRow(icon: Icons.apartment_rounded, label: 'Department', value: _emp.department),
                    const Divider(height: 1, indent: 56),
                    _InfoRow(icon: Icons.payments_outlined, label: 'Basic Monthly Salary', value: _emp.baseSalary != null ? 'RM ${_emp.baseSalary!.toStringAsFixed(2)}' : 'Not set'),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Risk Score'),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.shield_outlined, color: c.riskHigh, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill.risk(_emp.risk),
                        const SizedBox(height: 4),
                        Text(
                          'Deducted automatically per anomaly; only HR can reset it',
                          style: TextStyle(fontSize: 11, color: c.textMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _emp.risk == RiskLevel.low ? null : _resetRiskScore,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Training Insight'),
            _TrainingInsightCard(loading: _insightLoading, failed: _insightFailed, insight: _insight),
            const SizedBox(height: 24),

            const SectionHeader(title: 'Device Binding'),
            AppCard(
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: c.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.phone_iphone_rounded, color: c.primaryDark, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_emp.registeredDevice, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                  ),
                  TextButton(
                    onPressed: _emp.registeredDevice == 'Not yet registered' ? null : _resetDeviceBinding,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _toggleActive,
                icon: Icon(_emp.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined, size: 18, color: _emp.isActive ? c.riskHigh : c.primary),
                label: Text(_emp.isActive ? 'Deactivate Account' : 'Reactivate Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _emp.isActive ? c.riskHigh : c.primary,
                  side: BorderSide(color: _emp.isActive ? c.riskHigh : c.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          ),
        ),
      ),
      ),
    );
  }
}

/// What the offline-trained ML model suggests this employee's next
/// training area should be, and the signals behind it.
class _TrainingInsightCard extends StatelessWidget {
  final bool loading;
  final bool failed;
  final TrainingInsight? insight;
  const _TrainingInsightCard({required this.loading, required this.failed, required this.insight});

  static const _areas = ['technical', 'behavioural', 'leadership'];

  static String _label(String area) => '${area[0].toUpperCase()}${area.substring(1)}';

  static Color _areaColor(AppColorsExtension c, String area) {
    switch (area) {
      case 'leadership':
        return c.purple;
      case 'behavioural':
        return c.amber;
      default:
        return c.infoBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (loading) {
      return const AppCard(child: Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2))));
    }
    if (failed || insight == null) {
      return AppCard(
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, size: 20, color: c.textMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                failed ? 'Training insight is unavailable right now.' : 'No training model has been uploaded yet.',
                style: TextStyle(fontSize: 12.5, color: c.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    final i = insight!;
    final color = _areaColor(c, i.category);
    final pct = (i.confidence * 100).round().clamp(0, 99);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.auto_awesome_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Suggested focus: ${_label(i.category)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('$pct% confidence', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final area in _areas) ...[
            Row(
              children: [
                SizedBox(width: 86, child: Text(_label(area), style: TextStyle(fontSize: 11.5, color: c.textSecondary))),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: i.probabilities[area] ?? 0,
                      minHeight: 6,
                      backgroundColor: c.surfaceMuted,
                      color: _areaColor(c, area),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${((i.probabilities[area] ?? 0) * 100).round()}%',
                      textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5, color: c.textSecondary)),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          if (i.factors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Why', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary)),
            const SizedBox(height: 4),
            for (final f in i.factors)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('• ${f.description}', style: TextStyle(fontSize: 12, color: c.textSecondary, height: 1.35)),
              ),
          ],
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: c.infoBlueBg, borderRadius: BorderRadius.circular(10)),
            child: Text(
              i.isConfident
                  ? 'Confident enough to recommend a ${_label(i.category).toLowerCase()} programme automatically in the daily sweep.'
                  : 'Below the ${(i.minConfidence * 100).round()}% confidence needed, so no programme is recommended automatically.',
              style: TextStyle(fontSize: 11.5, color: c.infoBlue, height: 1.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Model ${i.modelVersion}${i.modelAccuracy != null ? ' · ${(i.modelAccuracy! * 100).round()}% accurate on test data' : ''}',
            style: TextStyle(fontSize: 10.5, color: c.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c.textMuted),
          const SizedBox(width: 14),
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
          Expanded(
            flex: 3,
            child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownField({required this.label, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 13.5)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
