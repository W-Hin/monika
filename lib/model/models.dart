enum UserRole { employee, hrAdmin }

enum RiskLevel { low, medium, high }

enum LeaveStatus { pending, approved, rejected }

enum AttendanceStatus { onTime, late, flagged }

class AssignedEmployee {
  final String uuid;
  final String name;
  const AssignedEmployee({required this.uuid, required this.name});
}

class CalendarEvent {
  final int? dbId; // company_events.id - null for a not-yet-saved local draft
  final String title;
  final DateTime eventDate;
  final DateTime? endDate;
  final String type; // 'Public Holiday' | 'Company Event' | 'HR Event' (display)
  final List<AssignedEmployee> assignedTo; // empty = visible to everyone
  // Explicit flag rather than inferring "no time" from eventDate's clock
  // digits being 00:00 — that heuristic false-positives for pre-migration
  // rows cast from `date` to `timestamptz`, which land on midnight UTC and
  // read back as a non-midnight local hour outside the UTC timezone.
  final bool hasTime;

  const CalendarEvent({
    this.dbId,
    required this.title,
    required this.eventDate,
    this.endDate,
    required this.type,
    this.assignedTo = const [],
    this.hasTime = true,
  });
}

class AppUser {
  final String id;
  final String name;
  final String email;
  final String department;
  final String role; // job title
  final UserRole userRole;
  final RiskLevel riskLevel;
  final int riskScore; // 0-100, the real server-computed value riskLevel is banded from
  final String avatarInitials;
  final String employmentDuration;
  final String registeredDevice;
  final String deviceBoundSince;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.role,
    required this.userRole,
    required this.riskLevel,
    required this.riskScore,
    required this.avatarInitials,
    required this.employmentDuration,
    required this.registeredDevice,
    required this.deviceBoundSince,
  });

  AppUser copyWith({String? email, String? registeredDevice, String? deviceBoundSince}) => AppUser(
        id: id,
        name: name,
        email: email ?? this.email,
        department: department,
        role: role,
        userRole: userRole,
        riskLevel: riskLevel,
        riskScore: riskScore,
        avatarInitials: avatarInitials,
        employmentDuration: employmentDuration,
        registeredDevice: registeredDevice ?? this.registeredDevice,
        deviceBoundSince: deviceBoundSince ?? this.deviceBoundSince,
      );
}

class AttendanceRecord {
  final DateTime workDate;
  final String date;
  final String clockIn;
  final String? clockOut;
  final AttendanceStatus status;
  final String? flagReason;

  const AttendanceRecord({
    required this.workDate,
    required this.date,
    required this.clockIn,
    this.clockOut,
    required this.status,
    this.flagReason,
  });
}

class LeaveApplication {
  final int? dbId; // leave_applications.id - null for dummy/local-only rows
  final String? userUuid; // profiles.id of the applicant - null for dummy rows
  final String id; // reference_code, e.g. LV-2201 (display)
  final String employeeName;
  final String leaveType;
  final String startDate;
  final String endDate;
  final int days;
  final String reason;
  final LeaveStatus status;

  const LeaveApplication({
    this.dbId,
    this.userUuid,
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
  final String category; // 'Technical' | 'Behavioural' | 'Leadership'
  const KpiItem({required this.name, required this.weightage, required this.score, this.category = 'Technical'});
}

class PerformanceEvaluation {
  final int? dbId; // performance_evaluations.id - null for dummy/local-only rows
  final String? userUuid;
  final int? templateId;
  final String year;
  final List<KpiItem> kpis;
  final String comments;

  const PerformanceEvaluation({
    this.dbId,
    this.userUuid,
    this.templateId,
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
  final int? dbId; // training_programs.id - null for dummy/local-only rows
  final int? enrollmentId; // training_enrollments.id - null if not enrolled
  final int enrolledCount; // real count across all employees, HR view only
  final String title;
  final String category; // Technical, Behavioural, Leadership
  final String description;
  final bool isMandatory;
  final bool isRecommended;
  final String? recommendationReason;
  final double progress; // 0..1
  final String duration;
  final bool isCompleted;
  final double? performanceScore; // out of 100, set once completed
  final String? department; // null = all departments

  const TrainingProgram({
    this.dbId,
    this.enrollmentId,
    this.enrolledCount = 0,
    required this.title,
    required this.category,
    required this.description,
    this.isMandatory = false,
    this.isRecommended = false,
    this.recommendationReason,
    this.progress = 0,
    required this.duration,
    this.isCompleted = false,
    this.performanceScore,
    this.department,
  });

  TrainingProgram copyWith({
    double? progress,
    bool? isCompleted,
    double? performanceScore,
    String? department,
  }) =>
      TrainingProgram(
        dbId: dbId,
        enrollmentId: enrollmentId,
        enrolledCount: enrolledCount,
        title: title,
        category: category,
        description: description,
        isMandatory: isMandatory,
        isRecommended: isRecommended,
        recommendationReason: recommendationReason,
        progress: progress ?? this.progress,
        duration: duration,
        isCompleted: isCompleted ?? this.isCompleted,
        performanceScore: performanceScore ?? this.performanceScore,
        department: department ?? this.department,
      );
}

class PayrollSummary {
  final int? dbId; // payroll_summaries.id - null for dummy/local-only rows
  final String? userUuid; // profiles.id - null for dummy rows
  final String month;
  final double baseSalary;
  final double deductions;
  final double netPay;
  final List<PayrollDeductionItem> items;
  final String employeeName;

  const PayrollSummary({
    this.dbId,
    this.userUuid,
    required this.month,
    required this.baseSalary,
    required this.deductions,
    required this.netPay,
    required this.items,
    this.employeeName = '',
  });
}

class PayrollDeductionItem {
  final String label;
  final double amount;
  const PayrollDeductionItem({required this.label, required this.amount});
}

class AnomalyEvent {
  final int id;
  final String employeeName;
  final String type; // Out-of-zone, Shared-device, Late
  final String date;
  final String details;
  final RiskLevel severity;
  final bool reviewed;

  const AnomalyEvent({
    required this.id,
    required this.employeeName,
    required this.type,
    required this.date,
    required this.details,
    required this.severity,
    this.reviewed = false,
  });

  AnomalyEvent copyWith({bool? reviewed}) => AnomalyEvent(
        id: id,
        employeeName: employeeName,
        type: type,
        date: date,
        details: details,
        severity: severity,
        reviewed: reviewed ?? this.reviewed,
      );
}

class TeamMemberSummary {
  final String id; // display employee_code, e.g. EMP-1042
  final String uuid; // real profiles.id (auth.users uuid) — empty for dummy/unbacked rows
  final String name;
  final String email;
  final String jobTitle;
  final String department;
  final RiskLevel risk;
  final double attendanceRate;
  final String avatarInitials;
  final String registeredDevice;
  final bool isActive;
  final double? baseSalary;

  const TeamMemberSummary({
    required this.id,
    this.uuid = '',
    required this.name,
    required this.email,
    required this.jobTitle,
    required this.department,
    required this.risk,
    required this.attendanceRate,
    required this.avatarInitials,
    required this.registeredDevice,
    this.isActive = true,
    this.baseSalary,
  });

  TeamMemberSummary copyWith({
    String? jobTitle,
    String? department,
    bool? isActive,
    String? registeredDevice,
    double? baseSalary,
    RiskLevel? risk,
  }) =>
      TeamMemberSummary(
        id: id,
        uuid: uuid,
        name: name,
        email: email,
        jobTitle: jobTitle ?? this.jobTitle,
        department: department ?? this.department,
        risk: risk ?? this.risk,
        attendanceRate: attendanceRate,
        avatarInitials: avatarInitials,
        registeredDevice: registeredDevice ?? this.registeredDevice,
        isActive: isActive ?? this.isActive,
        baseSalary: baseSalary ?? this.baseSalary,
      );
}

class KpiTemplateItem {
  final String name;
  final double weightage;
  final String category; // 'Technical' | 'Behavioural' | 'Leadership'
  const KpiTemplateItem({required this.name, required this.weightage, this.category = 'Technical'});
}

class KpiTemplate {
  final int? dbId; // kpi_templates.id - null for dummy/local-only rows
  final String name;
  final String department; // 'All Departments' if not department-specific
  final List<KpiTemplateItem> items;
  const KpiTemplate({this.dbId, required this.name, required this.department, required this.items});
}

class TrainingCompletionRecord {
  final int? enrollmentId; // training_enrollments.id - null for dummy/local-only rows
  final String employeeName;
  final String department;
  final String programTitle;
  final double progress;
  final double? performanceScore;

  const TrainingCompletionRecord({
    this.enrollmentId,
    required this.employeeName,
    required this.department,
    required this.programTitle,
    required this.progress,
    this.performanceScore,
  });
}

class DeviceChangeRequest {
  final int id;
  final String userUuid;
  final String employeeName;
  final String reason;
  final String status; // 'pending' | 'approved' | 'rejected'
  final DateTime createdAt;

  const DeviceChangeRequest({
    required this.id,
    required this.userUuid,
    required this.employeeName,
    required this.reason,
    required this.status,
    required this.createdAt,
  });
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String type; // 'leave_decision' | 'training' | 'payroll' | 'anomaly' | 'pe'
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
      );
}

class LeaveBalance {
  final String? userUuid; // profiles.id - null for dummy/local-only rows
  final String employeeName;
  final String department;
  final int annualTotal;
  final int annualUsed;
  final int medicalTotal;
  final int medicalUsed;
  final int emergencyTotal;
  final int emergencyUsed;

  const LeaveBalance({
    this.userUuid,
    required this.employeeName,
    this.department = 'Unassigned',
    required this.annualTotal,
    required this.annualUsed,
    required this.medicalTotal,
    required this.medicalUsed,
    required this.emergencyTotal,
    required this.emergencyUsed,
  });

  int get annualRemaining => annualTotal - annualUsed;
  int get medicalRemaining => medicalTotal - medicalUsed;
  int get emergencyRemaining => emergencyTotal - emergencyUsed;
}