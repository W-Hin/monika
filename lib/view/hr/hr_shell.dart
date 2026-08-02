import 'package:flutter/material.dart';
import '../../core/theme/app_colors_extension.dart';
import 'home/hr_home.dart';
import 'employees/hr_employees.dart';
import 'approvals/hr_approvals.dart';
import 'analytics/hr_analytics.dart';
import 'profile/hr_profile.dart';

class HrShell extends StatefulWidget {
  /// True when an employee's account was elevated to HR admin and they
  /// reached this shell via "Switch to Admin View" rather than landing
  /// here directly after login. Shows a small exit banner, mirroring
  /// EmployeeShell's existing viewingAsHr flag — HrShell has no back
  /// button of its own otherwise (each tab manages its own AppBar).
  final bool viewingAsEmployee;

  const HrShell({super.key, this.viewingAsEmployee = false});

  @override
  State<HrShell> createState() => _HrShellState();
}

class _HrShellState extends State<HrShell> {
  int _index = 0;

  final _screens = const [
    HrHomeScreen(),
    HrEmployeesScreen(),
    HrApprovalsScreen(),
    HrAnalyticsScreen(),
    HrProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          if (widget.viewingAsEmployee)
            SafeArea(
              bottom: false,
              child: Container(
                width: double.infinity,
                color: c.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Viewing as HR Admin',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text('Back to Employee', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups_rounded), label: 'Employees'),
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Approvals'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}