import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';

/// Full-width primary action button with consistent height & loading state
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  const PrimaryButton({super.key, required this.label, required this.onPressed, this.icon, this.isLoading = false, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                Text(label),
              ],
            ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary (tinted-fill) button
class SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool expand;

  const SecondaryButton({super.key, required this.label, required this.onPressed, this.icon, this.expand = true});

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
          Text(label),
        ],
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Standard screen app bar with greeting + notification + avatar
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String greeting;
  final String name;
  final String initials;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onAvatarTap;
  final int notificationCount;

  const HomeAppBar({super.key, required this.greeting, required this.name, required this.initials, this.onNotificationTap, this.onAvatarTap, this.notificationCount = 0});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Row(
          children: [
            GestureDetector(
              onTap: onAvatarTap,
              child: CircleAvatar(
                radius: 21,
                backgroundColor: c.primaryLight,
                child: Text(initials, style: TextStyle(color: c.primaryDark, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting, style: TextStyle(fontSize: 12.5, color: c.textMuted, fontWeight: FontWeight.w500)),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16.5, color: c.textPrimary, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onNotificationTap,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(Icons.notifications_none_rounded, color: c.textPrimary, size: 22),
                    if (notificationCount > 0)
                      Positioned(
                        top: 9,
                        right: 10,
                        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: c.riskHigh, shape: BoxShape.circle)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple back-button app bar for sub-screens
class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const SimpleAppBar({super.key, required this.title, this.actions});

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppBar(
      title: Text(title),
      actions: actions,
      leading: IconButton(
        icon: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
        ),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}