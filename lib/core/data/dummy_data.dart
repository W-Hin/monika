import '../../model/models.dart';

/// Centralised dummy data source for the Phase 1 UI Prototype.
/// In Phase 2+, these static getters will be replaced by calls to the
/// PHP RESTful API backed by MySQL.
class DummyData {
  DummyData._();

  static final AppUser employeeUser = const AppUser(
    id: 'EMP-1042',
    name: 'Hin Chen Wei',
    email: 'hin.chenwei@monika-demo.com',
    department: 'Software Engineering',
    role: 'Mobile Developer',
    userRole: UserRole.employee,
    riskLevel: RiskLevel.low,
    avatarInitials: 'HC',
    employmentDuration: '1 yr 8 mo',
  );

  static final AppUser hrUser = const AppUser(
    id: 'HR-0007',
    name: 'Aisyah Rahman',
    email: 'aisyah.rahman@monika-demo.com',
    department: 'Human Resources',
    role: 'HR Administrator',
    userRole: UserRole.hrAdmin,
    riskLevel: RiskLevel.low,
    avatarInitials: 'AR',
    employmentDuration: '3 yr 2 mo',
  );

  static final List<AttendanceRecord> attendanceHistory = [
    const AttendanceRecord(date: 'Mon, 22 Jun', clockIn: '08:57 AM', clockOut: '06:02 PM', status: AttendanceStatus.onTime),
    const AttendanceRecord(date: 'Fri, 19 Jun', clockIn: '09:08 AM', clockOut: '06:00 PM', status: AttendanceStatus.late, flagReason: 'Clocked in 8 min after grace period'),
    const AttendanceRecord(date: 'Thu, 18 Jun', clockIn: '08:50 AM', clockOut: '05:58 PM', status: AttendanceStatus.onTime),
    const AttendanceRecord(date: 'Wed, 17 Jun', clockIn: '—', clockOut: '—', status: AttendanceStatus.leave),
    const AttendanceRecord(date: 'Tue, 16 Jun', clockIn: '08:45 AM', clockOut: '06:10 PM', status: AttendanceStatus.onTime),
    const AttendanceRecord(date: 'Mon, 15 Jun', clockIn: '09:02 AM', clockOut: '—', status: AttendanceStatus.flagged, flagReason: 'GPS outside geofence radius'),
  ];

  static final List<LeaveApplication> employeeLeaveApplications = [
    const LeaveApplication(id: 'LV-2201', employeeName: 'Hin Chen Wei', leaveType: 'Annual Leave', startDate: '02 Jul', endDate: '04 Jul', days: 3, reason: 'Family trip to Langkawi', status: LeaveStatus.pending),
    const LeaveApplication(id: 'LV-2187', employeeName: 'Hin Chen Wei', leaveType: 'Medical Leave', startDate: '12 Jun', endDate: '12 Jun', days: 1, reason: 'Fever, MC attached', status: LeaveStatus.approved),
    const LeaveApplication(id: 'LV-2150', employeeName: 'Hin Chen Wei', leaveType: 'Unpaid Leave', startDate: '02 May', endDate: '02 May', days: 1, reason: 'Personal matters', status: LeaveStatus.rejected),
  ];

  static final List<LeaveApplication> pendingApprovalsForHr = [
    const LeaveApplication(id: 'LV-2201', employeeName: 'Hin Chen Wei', leaveType: 'Annual Leave', startDate: '02 Jul', endDate: '04 Jul', days: 3, reason: 'Family trip to Langkawi', status: LeaveStatus.pending),
    const LeaveApplication(id: 'LV-2202', employeeName: 'Nur Aina Zulkifli', leaveType: 'Medical Leave', startDate: '23 Jun', endDate: '24 Jun', days: 2, reason: 'Dental surgery recovery', status: LeaveStatus.pending),
    const LeaveApplication(id: 'LV-2203', employeeName: 'Ramesh Kumar', leaveType: 'Annual Leave', startDate: '30 Jun', endDate: '02 Jul', days: 3, reason: 'Wedding anniversary', status: LeaveStatus.pending),
    const LeaveApplication(id: 'LV-2204', employeeName: 'Tan Wei Ming', leaveType: 'Emergency Leave', startDate: '21 Jun', endDate: '21 Jun', days: 1, reason: 'Family emergency', status: LeaveStatus.pending),
  ];

  static final PerformanceEvaluation currentPE = PerformanceEvaluation(
    year: '2025',
    comments: 'Strong technical delivery this cycle. Continue developing stakeholder communication skills.',
    kpis: const [
      KpiItem(name: 'Attendance Rate', weightage: 20, score: 92),
      KpiItem(name: 'Task Delivery Quality', weightage: 30, score: 88),
      KpiItem(name: 'Project Output', weightage: 25, score: 81),
      KpiItem(name: 'Teamwork & Communication', weightage: 15, score: 74),
      KpiItem(name: 'Leadership Initiative', weightage: 10, score: 58),
    ],
  );

  static final List<PerformanceEvaluation> peHistory = [
    currentPE,
    PerformanceEvaluation(
      year: '2024',
      comments: 'Solid first full year. Recommend leadership training.',
      kpis: const [
        KpiItem(name: 'Attendance Rate', weightage: 20, score: 85),
        KpiItem(name: 'Task Delivery Quality', weightage: 30, score: 79),
        KpiItem(name: 'Project Output', weightage: 25, score: 75),
        KpiItem(name: 'Teamwork & Communication', weightage: 15, score: 70),
        KpiItem(name: 'Leadership Initiative', weightage: 10, score: 50),
      ],
    ),
  ];

  static final List<TrainingProgram> recommendedTrainings = [
    const TrainingProgram(
      title: 'Leadership Fundamentals',
      category: 'Leadership',
      description: 'Build core skills in delegation, decision-making, and team motivation.',
      isRecommended: true,
      recommendationReason: 'Low Leadership Initiative KPI score (58/100) in your latest evaluation',
      duration: '4 weeks · Self-paced',
    ),
    const TrainingProgram(
      title: 'Effective Stakeholder Communication',
      category: 'Behavioural',
      description: 'Practical techniques for clear, confident communication with cross-functional teams.',
      isRecommended: true,
      recommendationReason: 'Suggested by ML engine based on your performance profile',
      duration: '2 weeks · Self-paced',
    ),
  ];

  static final List<TrainingProgram> mandatoryTrainings = [
    const TrainingProgram(
      title: 'Workplace Data Privacy & Security',
      category: 'Technical',
      description: 'Annual mandatory compliance training for all engineering staff.',
      isMandatory: true,
      progress: 0.6,
      duration: '1 week · Due 30 Jun',
    ),
  ];

  static final List<TrainingProgram> availableTrainings = [
    const TrainingProgram(
      title: 'Advanced Flutter Architecture',
      category: 'Technical',
      description: 'Deep dive into state management, clean architecture, and testing.',
      duration: '6 weeks · Self-paced',
    ),
    const TrainingProgram(
      title: 'Time Management Essentials',
      category: 'Behavioural',
      description: 'Practical strategies for prioritisation and avoiding burnout.',
      duration: '1 week · Self-paced',
    ),
    ...recommendedTrainings,
    ...mandatoryTrainings,
  ];

  static final PayrollSummary currentPayroll = const PayrollSummary(
    month: 'June 2026',
    baseSalary: 4500.00,
    deductions: 145.00,
    netPay: 4355.00,
    items: [
      PayrollDeductionItem(label: 'Late arrival (1 day, beyond grace period)', amount: 25.00),
      PayrollDeductionItem(label: 'Unpaid leave (1 day)', amount: 120.00),
    ],
  );

  static final List<AnomalyEvent> anomalyFeed = [
    const AnomalyEvent(employeeName: 'Faiz Hidayat', type: 'Shared-device violation', date: 'Today, 09:14 AM', details: 'Device token already bound to another employee account', severity: RiskLevel.high),
    const AnomalyEvent(employeeName: 'Lim Jia Hui', type: 'Out-of-zone clock-in', date: 'Today, 08:51 AM', details: 'GPS coordinates 340m outside geofence radius', severity: RiskLevel.medium),
    const AnomalyEvent(employeeName: 'Ramesh Kumar', type: 'Repeated late arrival', date: 'Yesterday', details: '4th late arrival in the past 14 days', severity: RiskLevel.medium),
    const AnomalyEvent(employeeName: 'Tan Wei Ming', type: 'WiFi SSID mismatch', date: '2 days ago', details: 'Connected to unrecognised network during clock-in attempt', severity: RiskLevel.low),
  ];

  static final List<TeamMemberSummary> teamOverview = [
    const TeamMemberSummary(name: 'Hin Chen Wei', department: 'Engineering', risk: RiskLevel.low, attendanceRate: 0.96, avatarInitials: 'HC'),
    const TeamMemberSummary(name: 'Nur Aina Zulkifli', department: 'Design', risk: RiskLevel.low, attendanceRate: 0.94, avatarInitials: 'NA'),
    const TeamMemberSummary(name: 'Ramesh Kumar', department: 'Sales', risk: RiskLevel.medium, attendanceRate: 0.85, avatarInitials: 'RK'),
    const TeamMemberSummary(name: 'Tan Wei Ming', department: 'Engineering', risk: RiskLevel.medium, attendanceRate: 0.81, avatarInitials: 'TW'),
    const TeamMemberSummary(name: 'Faiz Hidayat', department: 'Operations', risk: RiskLevel.high, attendanceRate: 0.68, avatarInitials: 'FH'),
    const TeamMemberSummary(name: 'Lim Jia Hui', department: 'Marketing', risk: RiskLevel.medium, attendanceRate: 0.83, avatarInitials: 'LJ'),
  ];

  // Dashboard quick stats (HR)
  static const int totalEmployees = 86;
  static const double overallAttendanceRate = 0.91;
  static const int pendingLeaveCount = 4;
  static const int flaggedEventsToday = 2;
  static const Map<RiskLevel, int> riskDistribution = {
    RiskLevel.low: 61,
    RiskLevel.medium: 19,
    RiskLevel.high: 6,
  };

  static const List<double> weeklyAttendanceTrend = [0.88, 0.91, 0.93, 0.90, 0.95, 0.91, 0.89];
  static const List<String> weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}