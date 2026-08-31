import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../../connection/employee_service.dart';

/// FR2.5 — bulk-import employees via CSV. Paste-based rather than an OS
/// file-picker dialog: adding a native file-picker plugin (new pubspec
/// dependency, platform permission config on both Android and iOS) is a
/// meaningfully bigger and riskier lift than this screen's actual job, and
/// isn't verifiable in this project's test environment (flutter test has
/// no platform channels — see attendance_screens_test.dart's own comment
/// on the same limitation). Pasting CSV text copied from Excel/Sheets is
/// still genuinely CSV-formatted bulk input, just without the extra
/// dependency surface — a deliberate scope trade-off, not an oversight.
///
/// Each valid row calls the same create-employee Edge Function
/// AddEmployeeScreen uses, once per row — always creates an 'employee'
/// account (never 'hr_admin'; that stays a deliberate one-at-a-time action
/// via Add Employee) with an auto-generated temp password and employee
/// code, exactly like a single manual add.
class BulkImportEmployeesScreen extends StatefulWidget {
  const BulkImportEmployeesScreen({super.key});

  @override
  State<BulkImportEmployeesScreen> createState() => _BulkImportEmployeesScreenState();
}

enum _RowStatus { pending, importing, success, failed }

class _ImportRow {
  final int lineNumber;
  final String name;
  final String email;
  final String department;
  final String jobTitle;
  final double? baseSalary;
  String? validationError;
  _RowStatus status = _RowStatus.pending;
  String? resultError;

  _ImportRow({
    required this.lineNumber,
    required this.name,
    required this.email,
    required this.department,
    required this.jobTitle,
    required this.baseSalary,
    required this.validationError,
  });

  bool get isValid => validationError == null;
}

class _BulkImportEmployeesScreenState extends State<BulkImportEmployeesScreen> {
  final _csvController = TextEditingController();
  List<_ImportRow> _rows = [];
  List<String> _knownDepartments = [];
  bool _importing = false;
  bool _done = false;

  static const _example = 'name,email,department,job_title,base_salary\n'
      'Ahmad Faizi bin Ismail,ahmad.faizi@company.com,Engineering,Software Engineer,3500\n'
      'Siti Nurhaliza binti Yusof,siti.nurhaliza@company.com,Sales,Sales Executive,3200';

  @override
  void initState() {
    super.initState();
    EmployeeService.fetchDepartmentNames().then((d) {
      if (mounted) setState(() => _knownDepartments = d);
    });
  }

  @override
  void dispose() {
    _csvController.dispose();
    super.dispose();
  }

  /// Splits one CSV line on commas outside of double-quoted spans, then
  /// strips a wrapping pair of quotes from each field — enough for the
  /// realistic case (a department or name never needs deep RFC 4180 escape
  /// handling) without pulling in a CSV parsing package for one screen.
  List<String> _splitLine(String line) {
    final parts = line.split(RegExp(r',(?=(?:[^"]*"[^"]*")*[^"]*$)'));
    return parts.map((p) {
      final t = p.trim();
      return (t.startsWith('"') && t.endsWith('"') && t.length >= 2) ? t.substring(1, t.length - 1) : t;
    }).toList();
  }

  String _initialsFrom(String name) {
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join();
    return initials.isEmpty ? '??' : initials;
  }

  String _generateTempPassword() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(10, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  void _parse() {
    final lines = _csvController.text.split('\n').map((l) => l.trimRight()).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) {
      setState(() => _rows = []);
      return;
    }

    final header = _splitLine(lines.first).map((h) => h.toLowerCase().replaceAll(RegExp(r'[\s_]'), '')).toList();
    final nameIdx = header.indexOf('name');
    final emailIdx = header.indexOf('email');
    final deptIdx = header.indexOf('department');
    final jobIdx = header.indexWhere((h) => h == 'jobtitle' || h == 'role');
    final salaryIdx = header.indexWhere((h) => h == 'basesalary' || h == 'salary');

    if (nameIdx == -1 || emailIdx == -1 || deptIdx == -1) {
      setState(() => _rows = []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Header row must include at least: name, email, department'), backgroundColor: context.colors.riskHigh),
      );
      return;
    }

    final parsed = <_ImportRow>[];
    for (var i = 1; i < lines.length; i++) {
      final fields = _splitLine(lines[i]);
      String field(int idx) => (idx >= 0 && idx < fields.length) ? fields[idx].trim() : '';

      final name = field(nameIdx);
      final email = field(emailIdx);
      final department = field(deptIdx);
      final jobTitle = jobIdx == -1 || field(jobIdx).isEmpty ? 'Employee' : field(jobIdx);
      final salaryRaw = field(salaryIdx);
      final baseSalary = salaryRaw.isEmpty ? null : double.tryParse(salaryRaw);

      String? error;
      if (name.isEmpty) {
        error = 'Missing name';
      } else if (email.isEmpty) {
        error = 'Missing email';
      } else if (!_emailPattern.hasMatch(email)) {
        error = 'Invalid email format ("$email")';
      } else if (department.isEmpty) {
        error = 'Missing department';
      } else if (_knownDepartments.isNotEmpty && !_knownDepartments.contains(department)) {
        error = 'Unknown department "$department"';
      } else if (salaryRaw.isNotEmpty && baseSalary == null) {
        error = 'Invalid base salary "$salaryRaw"';
      }

      parsed.add(_ImportRow(
        lineNumber: i + 1,
        name: name,
        email: email,
        department: department,
        jobTitle: jobTitle,
        baseSalary: baseSalary,
        validationError: error,
      ));
    }

    // A second pass, after every row's own fields are checked individually —
    // two rows can each look perfectly valid on their own but still conflict
    // with each other. Every row sharing a duplicate email is rejected
    // (not just the second occurrence) rather than silently guessing which
    // one HR actually meant to keep.
    final emailCounts = <String, int>{};
    for (final row in parsed) {
      if (row.email.isEmpty) continue;
      final key = row.email.toLowerCase();
      emailCounts[key] = (emailCounts[key] ?? 0) + 1;
    }
    for (final row in parsed) {
      if (row.email.isEmpty || row.validationError != null) continue;
      if ((emailCounts[row.email.toLowerCase()] ?? 0) > 1) {
        row.validationError = 'Duplicate email — used by more than one row in this file';
      }
    }

    setState(() {
      _rows = parsed;
      _done = false;
    });
  }

  /// The Edge Function already returns reasonably plain-language errors —
  /// only the known Supabase Auth error strings get rewritten to something
  /// less technical, same mapping as AddEmployeeScreen's own
  /// _friendlyCreateError, so a duplicate/existing account reads the same
  /// way whether it was added one at a time or via this screen.
  String _friendlyImportError(String raw) {
    final message = raw.toLowerCase();
    if (message.contains('already') && (message.contains('registered') || message.contains('exists'))) {
      return 'An account with this email already exists';
    }
    if (message.contains('invalid') && message.contains('email')) {
      return 'Invalid email address';
    }
    return raw;
  }

  Future<void> _importAll() async {
    setState(() => _importing = true);
    for (final row in _rows.where((r) => r.isValid)) {
      setState(() => row.status = _RowStatus.importing);
      try {
        final response = await Supabase.instance.client.functions.invoke(
          'create-employee',
          body: {
            'email': row.email,
            'password': _generateTempPassword(),
            'name': row.name,
            'employeeCode': 'EMP-${DateTime.now().microsecondsSinceEpoch % 1000000}',
            'userRole': 'employee',
            'jobTitle': row.jobTitle,
            'departmentName': row.department,
            'avatarInitials': _initialsFrom(row.name),
            'hireDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
            'baseSalary': row.baseSalary,
          },
        );
        final data = response.data;
        if (data is Map && data['error'] != null) {
          setState(() {
            row.status = _RowStatus.failed;
            row.resultError = _friendlyImportError(data['error'].toString());
          });
        } else {
          setState(() => row.status = _RowStatus.success);
        }
      } catch (e) {
        setState(() {
          row.status = _RowStatus.failed;
          row.resultError = 'Network error — could not reach the server';
        });
      }
      // Small gap between calls so distinct rows created in the same
      // second still get distinct employeeCode suffixes.
      await Future.delayed(const Duration(milliseconds: 30));
    }
    if (!mounted) return;
    setState(() {
      _importing = false;
      _done = true;
    });

    // A durable per-row list already sits right below (it never
    // auto-dismisses), but a failure can easily land below the fold in a
    // long import — this SnackBar is the immediate, hard-to-miss cue that
    // something needs attention, on top of that permanent detail.
    final failedNow = _rows.where((r) => r.status == _RowStatus.failed).length;
    if (failedNow > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('⚠ $failedNow account${failedNow == 1 ? '' : 's'} failed to create — see details below'),
          backgroundColor: context.colors.riskHigh,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final validCount = _rows.where((r) => r.isValid).length;
    final invalidCount = _rows.length - validCount;
    final successCount = _rows.where((r) => r.status == _RowStatus.success).length;
    final failedCount = _rows.where((r) => r.status == _RowStatus.failed).length;

    return Scaffold(
      appBar: const SimpleAppBar(title: 'Bulk Import (CSV)'),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('Paste CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 6),
            Text(
              'First row is the header. Required columns: name, email, department. Optional: job_title, base_salary. Every row creates a regular Employee account (not HR Admin) with an auto-generated temporary password, same as Add Employee.',
              style: TextStyle(fontSize: 11.5, color: c.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _csvController,
              maxLines: 8,
              minLines: 4,
              style: const TextStyle(fontSize: 12.5, fontFeatures: [FontFeature.tabularFigures()]),
              decoration: InputDecoration(hintText: _example),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _csvController.text = _example),
                    icon: const Icon(Icons.description_outlined, size: 16),
                    label: const Text('Fill Example'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PrimaryButton(label: 'Preview', icon: Icons.visibility_outlined, onPressed: _parse),
                ),
              ],
            ),
            if (_rows.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionHeader(title: 'Preview — $validCount ready${invalidCount > 0 ? ', $invalidCount with errors' : ''}'),
              ListRow(
                children: _rows.map((r) => _ImportRowTile(row: r)).toList(),
              ),
              const SizedBox(height: 16),
              if (_done)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: failedCount > 0 ? c.riskHighBg : c.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${failedCount > 0 ? '⚠' : '✓'} Import complete: $successCount account${successCount == 1 ? '' : 's'} created.',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: failedCount > 0 ? c.riskHigh : c.primaryDark),
                      ),
                      if (failedCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$failedCount failed during creation — see the row${failedCount == 1 ? '' : 's'} marked with a red icon above for the reason.',
                          style: TextStyle(fontSize: 11.5, color: c.riskHigh, height: 1.4),
                        ),
                      ],
                      if (invalidCount > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '$invalidCount row${invalidCount == 1 ? '' : 's'} skipped and never attempted — fix and paste again to retry just those.',
                          style: TextStyle(fontSize: 11.5, color: c.textSecondary, height: 1.4),
                        ),
                      ],
                    ],
                  ),
                )
              else
                PrimaryButton(
                  label: validCount == 0 ? 'No Valid Rows to Import' : 'Import $validCount Employee${validCount == 1 ? '' : 's'}',
                  icon: Icons.upload_rounded,
                  onPressed: validCount == 0 ? null : _importAll,
                  isLoading: _importing,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ImportRowTile extends StatelessWidget {
  final _ImportRow row;
  const _ImportRowTile({required this.row});

  /// "{name}: account creation failed — {reason}" for anything rejected,
  /// whether that happened before import even started (validationError) or
  /// the server rejected it during creation (resultError) — one consistent
  /// message shape regardless of which stage caught the problem.
  String? get _errorText {
    final reason = row.validationError ?? row.resultError;
    if (reason == null) return null;
    final who = row.name.isEmpty ? 'This row' : row.name;
    return '$who: account creation failed — $reason';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final Widget trailing;
    switch (row.status) {
      case _RowStatus.pending:
        trailing = row.isValid
            ? Icon(Icons.check_circle_outline_rounded, size: 18, color: c.textMuted)
            : Icon(Icons.error_outline_rounded, size: 18, color: c.riskHigh);
        break;
      case _RowStatus.importing:
        trailing = SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: c.primary));
        break;
      case _RowStatus.success:
        trailing = Icon(Icons.check_circle_rounded, size: 18, color: c.primary);
        break;
      case _RowStatus.failed:
        trailing = Icon(Icons.error_rounded, size: 18, color: c.riskHigh);
        break;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name.isEmpty ? 'Line ${row.lineNumber}' : row.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _errorText ?? '${row.email} · ${row.department}',
                  style: TextStyle(fontSize: 11.5, color: _errorText != null ? c.riskHigh : c.textMuted),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
