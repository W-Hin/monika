import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/common_widgets.dart';
import '../../shared/widgets/status_pill.dart';
import '../../../core/data/dummy_data.dart';
import '../../../model/models.dart';
import 'add_employee.dart';
import 'employee_detail.dart';

class HrEmployeesScreen extends StatefulWidget {
  const HrEmployeesScreen({super.key});

  @override
  State<HrEmployeesScreen> createState() => _HrEmployeesScreenState();
}

class _HrEmployeesScreenState extends State<HrEmployeesScreen> {
  late List<TeamMemberSummary> _employees;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _employees = List.from(DummyData.teamOverview);
  }

  void _updateEmployee(TeamMemberSummary updated) {
    setState(() {
      final i = _employees.indexWhere((e) => e.id == updated.id);
      if (i != -1) _employees[i] = updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final filtered = _query.isEmpty
        ? _employees
        : _employees.where((e) => e.name.toLowerCase().contains(_query.toLowerCase()) || e.department.toLowerCase().contains(_query.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddEmployeeScreen())),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
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
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search employees...',
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: c.textMuted),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  ListRow(children: filtered.map((emp) => _EmployeeRow(
                    emp: emp,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EmployeeDetailScreen(employee: emp, onUpdate: _updateEmployee)),
                    ),
                  )).toList()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeRow extends StatelessWidget {
  final TeamMemberSummary emp;
  final VoidCallback onTap;
  const _EmployeeRow({required this.emp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            InitialsAvatar(initials: emp.avatarInitials),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(emp.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.textPrimary)),
                      if (!emp.isActive) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(100)),
                          child: Text('Deactivated', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: c.textMuted)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(emp.department, style: TextStyle(fontSize: 12, color: c.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusDot.risk(context, emp.risk),
                const SizedBox(height: 4),
                Text('${(emp.attendanceRate * 100).toInt()}% attendance', style: TextStyle(fontSize: 11, color: c.textMuted, fontFeatures: const [FontFeature.tabularFigures()])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}