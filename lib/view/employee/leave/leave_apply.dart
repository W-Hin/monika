import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors_extension.dart';
import '../../shared/widgets/buttons.dart';
import '../../../controller/leave_controller.dart';

class LeaveApplyScreen extends StatefulWidget {
  const LeaveApplyScreen({super.key});

  @override
  State<LeaveApplyScreen> createState() => _LeaveApplyScreenState();
}

class _LeaveApplyScreenState extends State<LeaveApplyScreen> {
  String _selectedType = 'Annual Leave';
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  final _leaveTypes = const ['Annual Leave', 'Medical Leave', 'Emergency Leave', 'Unpaid Leave'];
  static final _dateFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    leaveController.loadMy();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _days => _endDate.difference(_startDate).inDays + 1;

  int? get _remainingForType {
    final balance = leaveController.myBalance;
    if (balance == null) return null;
    return switch (_selectedType) {
      'Annual Leave' => balance.annualRemaining,
      'Medical Leave' => balance.medicalRemaining,
      'Emergency Leave' => balance.emergencyRemaining,
      _ => null, // Unpaid Leave has no balance pool
    };
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _startDate : _endDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      } else {
        _endDate = picked;
        if (_startDate.isAfter(_endDate)) _startDate = _endDate;
      }
    });
  }

  Future<void> _submit() async {
    if (_reasonController.text.trim().isEmpty) {
      setState(() => _errorText = 'Please describe the reason for your leave');
      return;
    }
    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    final success = await leaveController.submit(
      displayLeaveType: _selectedType,
      startDate: _startDate,
      endDate: _endDate,
      reason: _reasonController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(leaveController.errorMessage ?? 'Could not submit application')),
      );
      return;
    }

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
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final remaining = _remainingForType;
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
                  Expanded(
                    child: _DatePickerField(
                      label: 'Start Date',
                      value: _dateFormat.format(_startDate),
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DatePickerField(
                      label: 'End Date',
                      value: _dateFormat.format(_endDate),
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
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
                    Expanded(
                      child: Text(
                        remaining != null
                            ? 'Total: $_days day(s)  ·  Balance after: ${remaining - _days} day(s)'
                            : 'Total: $_days day(s)',
                        style: TextStyle(fontSize: 12, color: c.infoBlue, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              const Text('Reason', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _reasonController,
                maxLines: 4,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
                decoration: InputDecoration(
                  hintText: 'Briefly describe the reason for your leave...',
                  errorText: _errorText,
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
  final VoidCallback onTap;
  const _DatePickerField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
      ),
    );
  }
}
