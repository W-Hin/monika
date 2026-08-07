import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors_extension.dart';
import 'widgets/common_widgets.dart';
import 'widgets/buttons.dart';
import '../../model/models.dart';
import '../../controller/calendar_controller.dart';
import '../../controller/auth_controller.dart';

IconData _iconFor(String type) {
  switch (type) {
    case 'Public Holiday':
      return Icons.flag_rounded;
    case 'HR Event':
      return Icons.insights_rounded;
    default:
      return Icons.groups_rounded;
  }
}

AppHue _hueFor(String type) {
  switch (type) {
    case 'Public Holiday':
      return AppHue.primary;
    case 'HR Event':
      return AppHue.riskMedium;
    default:
      return AppHue.infoBlue;
  }
}

class CompanyCalendarScreen extends StatefulWidget {
  const CompanyCalendarScreen({super.key});

  @override
  State<CompanyCalendarScreen> createState() => _CompanyCalendarScreenState();
}

class _CompanyCalendarScreenState extends State<CompanyCalendarScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Public Holiday', 'Company Event', 'HR Event'];
  static final _dateFormat = DateFormat('d MMM yyyy');
  static final _monthFormat = DateFormat('MMM yyyy');

  @override
  void initState() {
    super.initState();
    calendarController.load();
  }

  bool get _isHr => authController.role == UserRole.hrAdmin;

  void _openEventForm({CalendarEvent? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(existing: existing),
    );
  }

  void _showEventOptions(CalendarEvent event) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Event'),
              onTap: () {
                Navigator.of(context).pop();
                _openEventForm(existing: event);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: context.colors.riskHigh),
              title: Text('Delete Event', style: TextStyle(color: context.colors.riskHigh)),
              onTap: () async {
                Navigator.of(context).pop();
                final success = await calendarController.delete(event);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? '✓ Event deleted' : calendarController.errorMessage ?? 'Could not delete event')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Company Calendar'),
        actions: [
          if (_isHr)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: IconButton(
                onPressed: () => _openEventForm(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: c.primary, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: calendarController,
          builder: (context, _) {
            if (calendarController.loading && calendarController.events.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final events = calendarController.events;
            final filtered = _filter == 'All' ? events : events.where((e) => e.type == _filter).toList();
            final holidayCount = events.where((e) => e.type == 'Public Holiday').length;
            final eventCount = events.where((e) => e.type == 'Company Event').length;
            final hrEventCount = events.where((e) => e.type == 'HR Event').length;

            final Map<String, List<CalendarEvent>> grouped = {};
            for (final e in filtered) {
              final monthYear = _monthFormat.format(e.eventDate);
              grouped.putIfAbsent(monthYear, () => []).add(e);
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: StatCard(label: 'Public Holidays', value: '$holidayCount', icon: Icons.flag_rounded, iconColor: c.primary, iconBg: c.primaryLight)),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'Company Events', value: '$eventCount', icon: Icons.groups_rounded, iconColor: c.infoBlue, iconBg: c.infoBlueBg)),
                          const SizedBox(width: 12),
                          Expanded(child: StatCard(label: 'HR Events', value: '$hrEventCount', icon: Icons.insights_rounded, iconColor: c.amber, iconBg: c.amberBg)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _filters.map((f) {
                            final sel = _filter == f;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _filter = f),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: sel ? c.primary : c.surfaceMuted,
                                    borderRadius: BorderRadius.circular(100),
                                  ),
                                  child: Text(f, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : c.textSecondary)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const EmptyState(icon: Icons.calendar_month_outlined, title: 'No events found', subtitle: 'Try a different filter.')
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          children: grouped.entries.map((entry) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary),
                                  ),
                                ),
                                ...entry.value.map((e) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _EventTile(
                                        event: e,
                                        dateFormat: _dateFormat,
                                        onTap: _isHr ? () => _showEventOptions(e) : null,
                                      ),
                                    )),
                                const SizedBox(height: 8),
                              ],
                            );
                          }).toList(),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final CalendarEvent event;
  final DateFormat dateFormat;
  final VoidCallback? onTap;
  const _EventTile({required this.event, required this.dateFormat, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (color, bg) = resolveHue(c, _hueFor(event.type));
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
              child: Icon(_iconFor(event.type), color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 12, color: c.textMuted),
                      const SizedBox(width: 5),
                      Text(
                        event.endDate != null ? '${dateFormat.format(event.eventDate)} – ${dateFormat.format(event.endDate!)}' : dateFormat.format(event.eventDate),
                        style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
                    child: Text(event.type, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
                  ),
                ],
              ),
            ),
            if (onTap != null) Icon(Icons.more_vert_rounded, size: 18, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  final CalendarEvent? existing;
  const _EventFormSheet({this.existing});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title);
  late DateTime _eventDate = widget.existing?.eventDate ?? DateTime.now();
  DateTime? _endDate;
  late String _type = widget.existing?.type ?? 'Company Event';
  bool _saving = false;
  static final _dateFormat = DateFormat('d MMM yyyy');

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _endDate = widget.existing?.endDate;
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isEnd ? (_endDate ?? _eventDate) : _eventDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _eventDate = picked;
        if (_endDate != null && _endDate!.isBefore(_eventDate)) _endDate = _eventDate;
      }
    });
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an event title')),
      );
      return;
    }
    setState(() => _saving = true);
    final success = _isEditing
        ? await calendarController.update(
            existing: widget.existing!,
            title: _title.text.trim(),
            eventDate: _eventDate,
            endDate: _endDate,
            displayType: _type,
          )
        : await calendarController.create(
            title: _title.text.trim(),
            eventDate: _eventDate,
            endDate: _endDate,
            displayType: _type,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(calendarController.errorMessage ?? 'Could not save event')),
      );
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? '✓ Event updated' : '✓ Event added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(100)),
              ),
            ),
            const SizedBox(height: 20),
            Text(_isEditing ? 'Edit Event' : 'Add Event', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 20),

            Text('Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            TextField(controller: _title, decoration: const InputDecoration(hintText: 'e.g. Annual Team Building')),
            const SizedBox(height: 14),

            Text('Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['Public Holiday', 'Company Event', 'HR Event'].map((t) {
                final sel = _type == t;
                return ChoiceChip(
                  label: Text(t),
                  selected: sel,
                  onSelected: (_) => setState(() => _type = t),
                  selectedColor: c.primaryLight,
                  labelStyle: TextStyle(color: sel ? c.primaryDark : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 12.5),
                  side: BorderSide(color: sel ? c.primary : Colors.transparent),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _DatePickerField(label: 'Date', value: _dateFormat.format(_eventDate), onTap: () => _pickDate(isEnd: false)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerField(
                    label: 'End Date (optional)',
                    value: _endDate != null ? _dateFormat.format(_endDate!) : '—',
                    onTap: () => _pickDate(isEnd: true),
                  ),
                ),
              ],
            ),
            if (_endDate != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() => _endDate = null),
                  child: const Text('Clear end date'),
                ),
              ),
            ],
            const SizedBox(height: 20),

            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Add Event',
              icon: _isEditing ? Icons.save_rounded : Icons.calendar_month_rounded,
              onPressed: _save,
              isLoading: _saving,
            ),
          ],
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
