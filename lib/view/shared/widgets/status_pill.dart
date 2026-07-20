import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../../model/models.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const StatusPill({super.key, required this.label, required this.color, required this.background, this.icon});

  static StatusPill risk(BuildContext context, RiskLevel level) {
    final c = context.colors;
    return _riskPill(level, (label, color, background, icon) => StatusPill(label: label, color: color, background: background, icon: icon), c);
  }

  static StatusPill leave(BuildContext context, LeaveStatus status) {
    final c = context.colors;
    return _leavePill(status, (label, color, background, icon) => StatusPill(label: label, color: color, background: background, icon: icon), c);
  }

  static StatusPill attendance(BuildContext context, AttendanceStatus status) {
    final c = context.colors;
    return _attendancePill(status, (label, color, background, icon) => StatusPill(label: label, color: color, background: background, icon: icon), c);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
          Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Small 6px dot + label — used inline in list/table rows (attendance
/// status, leave status, risk flags). StatusPill is reserved for
/// chip/tag/filter contexts.
class StatusDot extends StatelessWidget {
  final String label;
  final Color color;

  const StatusDot({super.key, required this.label, required this.color});

  static StatusDot risk(BuildContext context, RiskLevel level) {
    final c = context.colors;
    return _riskPill(level, (label, color, background, icon) => StatusDot(label: label, color: color), c);
  }

  static StatusDot leave(BuildContext context, LeaveStatus status) {
    final c = context.colors;
    return _leavePill(status, (label, color, background, icon) => StatusDot(label: label, color: color), c);
  }

  static StatusDot attendance(BuildContext context, AttendanceStatus status) {
    final c = context.colors;
    return _attendancePill(status, (label, color, background, icon) => StatusDot(label: label, color: color), c);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// Shared factory logic — takes a constructor function so both StatusPill
// and StatusDot can build from the same label/color mapping without
// duplicating the switch statements.
T _riskPill<T>(RiskLevel level, T Function(String, Color, Color, IconData?) make, AppColorsExtension colors) {
  switch (level) {
    case RiskLevel.low:
      return make('Low Risk', colors.riskLow, colors.riskLowBg, Icons.shield_outlined);
    case RiskLevel.medium:
      return make('Medium Risk', colors.riskMedium, colors.riskMediumBg, Icons.warning_amber_rounded);
    case RiskLevel.high:
      return make('High Risk', colors.riskHigh, colors.riskHighBg, Icons.error_outline_rounded);
  }
}

T _leavePill<T>(LeaveStatus status, T Function(String, Color, Color, IconData?) make, AppColorsExtension colors) {
  switch (status) {
    case LeaveStatus.approved:
      return make('Approved', colors.statusApproved, colors.riskLowBg, Icons.check_circle_outline);
    case LeaveStatus.pending:
      return make('Pending', colors.statusPending, colors.riskMediumBg, Icons.schedule);
    case LeaveStatus.rejected:
      return make('Rejected', colors.statusRejected, colors.riskHighBg, Icons.cancel_outlined);
  }
}

T _attendancePill<T>(AttendanceStatus status, T Function(String, Color, Color, IconData?) make, AppColorsExtension colors) {
  switch (status) {
    case AttendanceStatus.onTime:
      return make('On Time', colors.statusApproved, colors.riskLowBg, Icons.check_circle_outline);
    case AttendanceStatus.late:
      return make('Late', colors.statusPending, colors.riskMediumBg, Icons.schedule);
    case AttendanceStatus.flagged:
      return make('Flagged', colors.statusRejected, colors.riskHighBg, Icons.flag_outlined);
    case AttendanceStatus.leave:
      return make('On Leave', colors.infoBlue, colors.infoBlueBg, Icons.beach_access_outlined);
  }
}