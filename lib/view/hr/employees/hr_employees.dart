import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';

class HrEmployeesScreen extends StatelessWidget {
  const HrEmployeesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final employees = DummyData.teamOverview;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => _showAddEmployeeSheet(context),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search employees...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: AppColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                itemCount: employees.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _EmployeeTile(emp: employees[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEmployeeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddEmployeeSheet(),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  final TeamMemberSummary emp;
  const _EmployeeTile({required this.emp});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          InitialsAvatar(initials: emp.avatarInitials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(emp.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(emp.department, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusPill.risk(emp.risk),
              const SizedBox(height: 4),
              Text('${(emp.attendanceRate * 100).toInt()}% attendance', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddEmployeeSheet extends StatelessWidget {
  const _AddEmployeeSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Add New Employee', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 16),
          const TextField(decoration: InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_outline_rounded, size: 20))),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.mail_outline_rounded, size: 20))),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'Department', prefixIcon: Icon(Icons.apartment_rounded, size: 20))),
          const SizedBox(height: 12),
          const TextField(decoration: InputDecoration(labelText: 'Job Title / Role', prefixIcon: Icon(Icons.work_outline_rounded, size: 20))),
          const SizedBox(height: 24),
          PrimaryButton(label: 'Create Account & Send Invite', onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}