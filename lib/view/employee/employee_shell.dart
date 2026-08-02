import 'package:flutter/material.dart';
import '../../core/theme/app_colors_extension.dart';
import 'home/employee_home.dart';
import 'attendance/employee_attendance.dart';
import 'leave/employee_leave.dart';
import 'training/employee_training.dart';
import 'profile/employee_profile.dart';

class EmployeeShell extends StatefulWidget {
  /// True when an HR admin reached this shell via the "Switch to My
  /// Employee View" entry point rather than logging in as a plain
  /// employee. Shows a small exit banner, since this shell has no back
  /// button of its own otherwise (each tab manages its own AppBar).
  final bool viewingAsHr;

  const EmployeeShell({super.key, this.viewingAsHr = false});

  @override
  State<EmployeeShell> createState() => _EmployeeShellState();
}

class _EmployeeShellState extends State<EmployeeShell> {
  int _index = 0;

  final _screens = const [
    EmployeeHomeScreen(),
    EmployeeAttendanceScreen(),
    EmployeeLeaveScreen(),
    EmployeeTrainingScreen(),
    EmployeeProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.background,
      body: Column(
        children: [
          if (widget.viewingAsHr)
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
                        'Viewing as employee (your own account)',
                        style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)),
                      child: const Text('Back to HR', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
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
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.fingerprint_outlined), selectedIcon: Icon(Icons.fingerprint), label: 'Attendance'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), selectedIcon: Icon(Icons.event_note_rounded), label: 'Leave'),
          NavigationDestination(icon: Icon(Icons.school_outlined), selectedIcon: Icon(Icons.school_rounded), label: 'Training'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}