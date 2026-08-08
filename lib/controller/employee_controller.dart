import 'package:flutter/foundation.dart';
import '../connection/employee_service.dart';
import '../model/models.dart';

class EmployeeController extends ChangeNotifier {
  List<TeamMemberSummary> employees = [];
  bool loading = false;
  String? errorMessage;

  Future<void> loadEmployees() async {
    loading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final rows = await EmployeeService.fetchAll();
      final attendanceRows = await EmployeeService.fetchAllAttendanceStatuses();

      final totalByUser = <String, int>{};
      final presentByUser = <String, int>{};
      for (final r in attendanceRows) {
        final uid = r['user_id'] as String;
        totalByUser[uid] = (totalByUser[uid] ?? 0) + 1;
        if (r['status'] == 'on_time' || r['status'] == 'late') {
          presentByUser[uid] = (presentByUser[uid] ?? 0) + 1;
        }
      }

      employees = rows.map((row) => _mapEmployee(row, totalByUser, presentByUser)).toList();
    } catch (e) {
      errorMessage = 'Could not load employees: $e';
    }
    loading = false;
    notifyListeners();
  }

  TeamMemberSummary _mapEmployee(
    Map<String, dynamic> row,
    Map<String, int> totalByUser,
    Map<String, int> presentByUser,
  ) {
    final risk = RiskLevel.values.firstWhere(
      (r) => r.name == row['risk_level'],
      orElse: () => RiskLevel.low,
    );
    final deptName = (row['departments'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unassigned';
    final uuid = row['id'] as String;
    final total = totalByUser[uuid] ?? 0;
    final present = presentByUser[uuid] ?? 0;
    // Fraction of this employee's logged clock-ins that were on_time or
    // late (not flagged) - real now, computed from attendance_records.
    // No attendance history yet (e.g. a brand new hire) defaults to 1.0
    // rather than 0, so a new employee doesn't look like a risk before
    // they've ever had the chance to clock in.
    final attendanceRate = total == 0 ? 1.0 : present / total;
    return TeamMemberSummary(
      id: row['employee_code'] as String,
      uuid: uuid,
      name: row['name'] as String,
      email: row['email'] as String? ?? '',
      jobTitle: row['job_title'] as String,
      department: deptName,
      risk: risk,
      attendanceRate: attendanceRate,
      avatarInitials: row['avatar_initials'] as String,
      registeredDevice: row['registered_device_name'] as String? ?? 'Not yet registered',
      isActive: row['is_active'] as bool? ?? true,
      baseSalary: (row['base_salary'] as num?)?.toDouble(),
    );
  }

  void updateLocal(TeamMemberSummary updated) {
    final i = employees.indexWhere((e) => e.uuid == updated.uuid);
    if (i != -1) {
      employees[i] = updated;
      notifyListeners();
    }
  }
}

final employeeController = EmployeeController();
