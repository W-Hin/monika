import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../../core/data/dummy_data.dart';
import '../../../controller/notification_controller.dart';

class PostAnnouncementScreen extends StatefulWidget {
  const PostAnnouncementScreen({super.key});

  @override
  State<PostAnnouncementScreen> createState() => _PostAnnouncementScreenState();
}

class _PostAnnouncementScreenState extends State<PostAnnouncementScreen> {
  static const _departments = ['All Employees', 'Engineering', 'Sales', 'Operations', 'Marketing', 'Design', 'Human Resources', 'Finance'];

  final _title = TextEditingController();
  final _message = TextEditingController();
  String _target = 'All Employees';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final title = _title.text.trim();
    final message = _message.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Enter a title for the announcement.');
      return;
    }
    if (message.isEmpty) {
      setState(() => _error = 'Enter a message.');
      return;
    }

    setState(() {
      _error = null;
      _sending = true;
    });

    final hr = DummyData.hrUser;
    final body = '$message\n\nPosted by ${hr.name} | HR Administrator';
    final count = await notificationController.postAnnouncement(
      title: title,
      body: body,
      departmentName: _target,
    );

    if (!mounted) return;
    setState(() => _sending = false);
    if (count == null) {
      setState(() => _error = notificationController.announcementError ?? 'Could not post announcement.');
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('✓ Announcement sent to $count employee${count == 1 ? '' : 's'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Post Announcement')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'e.g. Office closed for Public Holiday')),
            const SizedBox(height: 14),

            Text('Message', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            TextField(
              controller: _message,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'Write the announcement message...'),
            ),
            const SizedBox(height: 14),

            Text('Send To', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _departments.map((d) {
                final sel = _target == d;
                return ChoiceChip(
                  label: Text(d),
                  selected: sel,
                  onSelected: (_) => setState(() => _target = d),
                  selectedColor: c.primaryLight,
                  labelStyle: TextStyle(color: sel ? c.primaryDark : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  side: BorderSide(color: sel ? c.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.infoBlueBg, borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: c.infoBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Every recipient gets this as a notification, attributed to you as "Posted by ${DummyData.hrUser.name} | HR Administrator".',
                      style: TextStyle(fontSize: 11.5, color: c.infoBlue, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: c.riskHighBg, borderRadius: BorderRadius.circular(10)),
                child: Text(_error!, style: TextStyle(fontSize: 12.5, color: c.riskHigh, fontWeight: FontWeight.w600)),
              ),
            ],
            const SizedBox(height: 20),

            PrimaryButton(
              label: 'Post Announcement',
              icon: Icons.campaign_rounded,
              onPressed: _post,
              isLoading: _sending,
            ),
          ],
        ),
      ),
    );
  }
}
