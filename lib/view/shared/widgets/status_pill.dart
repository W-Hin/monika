import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../model/models.dart';

class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.background,
    this.icon,
  });

  factory StatusPill.risk(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return StatusPill(label: 'Low Risk', color: AppColors.riskLow, background: AppColors.riskLowBg, icon: Icons.shield_outlined);
      case RiskLevel.medium:
        return StatusPill(label: 'Medium Risk', color: AppColors.riskMedium, background: AppColors.riskMediumBg, icon: Icons.warning_amber_rounded);
      case RiskLevel.high:
        return StatusPill(label: 'High Risk', color: AppColors.riskHigh, background: AppColors.riskHighBg, icon: Icons.error_outline_rounded);
    }
  }

  factory StatusPill.leave(LeaveStatus status) {
    switch (status) {
      case LeaveStatus.approved:
        return StatusPill(label: 'Approved', color: AppColors.statusApproved, background: AppColors.riskLowBg, icon: Icons.check_circle_outline);
      case LeaveStatus.pending:
        return StatusPill(label: 'Pending', color: AppColors.statusPending, background: AppColors.riskMediumBg, icon: Icons.schedule);
      case LeaveStatus.rejected:
        return StatusPill(label: 'Rejected', color: AppColors.statusRejected, background: AppColors.riskHighBg, icon: Icons.cancel_outlined);
    }
  }

  factory StatusPill.attendance(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.onTime:
        return StatusPill(label: 'On Time', color: AppColors.statusApproved, background: AppColors.riskLowBg, icon: Icons.check_circle_outline);
      case AttendanceStatus.late:
        return StatusPill(label: 'Late', color: AppColors.statusPending, background: AppColors.riskMediumBg, icon: Icons.schedule);
      case AttendanceStatus.flagged:
        return StatusPill(label: 'Flagged', color: AppColors.statusRejected, background: AppColors.riskHighBg, icon: Icons.flag_outlined);
      case AttendanceStatus.leave:
        return StatusPill(label: 'On Leave', color: AppColors.infoBlue, background: AppColors.infoBlueBg, icon: Icons.beach_access_outlined);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}