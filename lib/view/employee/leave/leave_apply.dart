import 'package:flutter/material.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';

class LeaveApplyScreen extends StatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  String _selectedType = 'Annual Leave';
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final _leaveTypes = const ['Annual Leave', 'Medical Leave', 'Emergency Leave', 'Unpaid Leave'];

  void _submit() {
    setState(() => _isSubmitting = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      showDialog(
        context: context,
        builder: (ctx) {
          final c = ctx.colors;
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(color: c.primaryLight, shape: BoxShape.circle),
                  child: Icon(Icons.check_circle_rounded, color: c.primary, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Application Submitted', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                  'Your leave application has been sent to HR for review. You can track its status anytime.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: c.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      appBar: const SimpleAppBar(title: 'Apply for Leave'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Leave Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _leaveTypes.map((type) {
                  final selected = _selectedType == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedType = type),
                    selectedColor: c.primaryLight,
                    backgroundColor: c.surfaceMuted,
                    labelStyle: TextStyle(
                      color: selected ? c.primaryDark : c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                    side: BorderSide(color: selected ? c.primary : Colors.transparent),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              const Text('Date Range', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _DatePickerField(label: 'Start Date', value: '02 Jul 2026')),
                  const SizedBox(width: 12),
                  Expanded(child: _DatePickerField(label: 'End Date', value: '04 Jul 2026')),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: c.infoBlueBg, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 15, color: c.infoBlue),
                    const SizedBox(width: 8),
                    Text('Total: 3 days  ·  Balance after: 6 days', style: TextStyle(fontSize: 12, color: c.infoBlue, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Briefly describe the reason for your leave...',
                ),
              ),
              const SizedBox(height: 22),

              const Text('Attachment (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () {},
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    border: Border.all(color: c.border, width: 1.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.upload_file_rounded, color: c.textMuted, size: 24),
                      const SizedBox(height: 6),
                      Text('Tap to upload MC or supporting document', style: TextStyle(fontSize: 12, color: c.textMuted)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                label: 'Submit Application',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final String value;
  const _DatePickerField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 10.5, color: c.textMuted, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Icon(Icons.calendar_today_rounded, size: 16, color: c.textMuted),
        ],
      ),
    );
  }
}