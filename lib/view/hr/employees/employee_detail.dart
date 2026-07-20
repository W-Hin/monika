import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../model/models.dart';

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
  late String _department;
  late String _jobTitle;

  final _departments = ['Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];
  final _jobTitles = ['Employee', 'Senior Engineer', 'Team Lead', 'Manager', 'Designer', 'Analyst', 'Consultant', 'Mobile Developer', 'Backend Engineer', 'UI/UX Designer', 'Sales Executive', 'Operations Executive', 'Marketing Executive'];

  @override
  void initState() {
    super.initState();
    _emp = widget.employee;
    _department = _emp.department;
    _jobTitle = _emp.jobTitle;
    if (!_departments.contains(_department)) _departments.add(_department);
    if (!_jobTitles.contains(_jobTitle)) _jobTitles.add(_jobTitle);
  }

  void _saveRoleAndDept() {
    setState(() {
      _emp = _emp.copyWith(department: _department, jobTitle: _jobTitle);
      _isEditing = false;
    });
    widget.onUpdate(_emp);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✓ Role & department updated')),
    );
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
              onPressed: () {
                setState(() => _emp = _emp.copyWith(isActive: activating));
                widget.onUpdate(_emp);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(activating ? '✓ Account reactivated' : '✓ Account deactivated')),
                );
              },
              child: Text(activating ? 'Reactivate' : 'Deactivate'),
            ),
          ],
        );
      },
    );
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
              onPressed: () {
                setState(() => _emp = _emp.copyWith(registeredDevice: 'Not yet registered'));
                widget.onUpdate(_emp);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✓ Device binding reset')),
                );
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Details'),
        actions: [
          if (!_isEditing)
            IconButton(onPressed: () => setState(() => _isEditing = true), icon: const Icon(Icons.edit_outlined))
          else
            TextButton(onPressed: _saveRoleAndDept, child: const Text('Save')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
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
                  ],
                ),
              ),
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
                  TextButton(onPressed: _resetDeviceBinding, child: const Text('Reset')),
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
          Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: c.textSecondary))),
          Flexible(
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
