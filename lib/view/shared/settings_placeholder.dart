import 'package:flutter/material.dart';
import 'widgets/buttons.dart';
import 'widgets/common_widgets.dart';

/// Generic placeholder for Phase 1 settings screens (Notification Preferences,
/// Change Password, Help & Support) that have no dedicated design yet.
class SettingsPlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;

  const SettingsPlaceholderScreen({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleAppBar(title: title),
      body: SafeArea(
        child: EmptyState(
          icon: icon,
          title: '$title coming soon',
          subtitle: 'This section will be available once the Phase 2 backend is connected.',
        ),
      ),
    );
  }
}
