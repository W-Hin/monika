import 'package:flutter/foundation.dart';
import '../connection/employee_service.dart';
import '../model/models.dart';

class EmployeeController extends ChangeNotifier {
  List<TeamMemberSummary> employees = [];
  bool loading = false;

  Future<void> loadEmployees() async {
    loading = true;
    notifyListeners();
    final rows = await EmployeeService.fetchAll();
    employees = rows.map(_mapEmployee).toList();
    loading = false;
    notifyListeners();
  }

  TeamMemberSummary _mapEmployee(Map<String, dynamic> row) {
    final risk = RiskLevel.values.firstWhere(
      (r) => r.name == row['risk_level'],
      orElse: () => RiskLevel.low,
    );
    final deptName = (row['departments'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unassigned';
    // attendanceRate isn't a stored column (deliberately — it's a derived
    // aggregate per the schema's own notes); approximated from risk_score
    // until Analytics wiring computes it for real from attendance_records.
    final riskScore = (row['risk_score'] as num?)?.toDouble() ?? 100;
    return TeamMemberSummary(
      id: row['employee_code'] as String,
      uuid: row['id'] as String,
      name: row['name'] as String,
      email: row['email'] as String? ?? '',
      jobTitle: row['job_title'] as String,
      department: deptName,
      risk: risk,
      attendanceRate: (riskScore / 100).clamp(0.0, 1.0),
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
