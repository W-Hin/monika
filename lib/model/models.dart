enum UserRole { employee, hrAdmin }

enum RiskLevel { low, medium, high }

enum LeaveStatus { pending, approved, rejected }

enum AttendanceStatus { onTime, late, flagged, leave }

class AppUser {
  final String id;
  final String name;
  final String email;
  final String department;
  final String role; // job title
  final UserRole userRole;
  final RiskLevel riskLevel;
  final String avatarInitials;
  final String employmentDuration;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.userRole,
    required this.riskLevel,
    required this.avatarInitials,
    required this.employmentDuration,
  });
}

class AttendanceRecord {
  final String date;
  final String clockIn;
  final String? clockOut;
  final AttendanceStatus status;
  final String? flagReason;

  const AttendanceRecord({
    required this.date,
    required this.clockIn,
    this.clockOut,
    required this.status,
    this.flagReason,
  });
}

class LeaveApplication {
  final String id;
  final String employeeName;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int days;
  final String reason;
  final LeaveStatus status;

  const LeaveApplication({
    required this.id,
    required this.employeeName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.reason,
    required this.status,
  });
}

class KpiItem {
  final String name;
  final double weightage;
  final double score; // out of 100
  const KpiItem({required this.name, required this.weightage, required this.score});
}

class PerformanceEvaluation {
  final String year;
  final List<KpiItem> kpis;
  final String comments;

  const PerformanceEvaluation({
    required this.year,
    required this.kpis,
    required this.comments,
  });

  double get weightedTotal {
    double total = 0;
    for (final k in kpis) {
      total += (k.score * k.weightage / 100);
    }
    return total;
  }
}

class TrainingProgram {
  final String title;
  final String category; // Technical, Behavioural, Leadership
  final String description;
  final bool isMandatory;
  final bool isRecommended;
  final String? recommendationReason;
  final double progress; // 0..1
  final String duration;

  const TrainingProgram({
    required this.title,
    required this.category,
    required this.description,
    this.isMandatory = false,
    this.isRecommended = false,
    this.recommendationReason,
    this.progress = 0,
    required this.duration,
  });
}

class PayrollSummary {
  final String month;
  final double baseSalary;
  final double deductions;
  final double netPay;
  final List<PayrollDeductionItem> items;

  const PayrollSummary({
    required this.month,
    required this.baseSalary,
    required this.deductions,
    required this.netPay,
    required this.items,
  });
}

class PayrollDeductionItem {
  final String label;
  final double amount;
  const PayrollDeductionItem({required this.label, required this.amount});
}

class AnomalyEvent {
  final String employeeName;
  final String type; // Out-of-zone, Shared-device, Late
  final String date;
  final String details;
  final RiskLevel severity;

  const AnomalyEvent({
    required this.employeeName,
    required this.type,
    required this.date,
    required this.details,
    required this.severity,
  });
}

class TeamMemberSummary {
  final String name;
  final String department;
  final RiskLevel risk;
  final double attendanceRate;
  final String avatarInitials;
  const TeamMemberSummary({
    required this.name,
    required this.department,
    required this.risk,
    required this.attendanceRate,
    required this.avatarInitials,
  });
}