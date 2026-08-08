import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors_extension.dart';
import 'widgets/common_widgets.dart';
import 'widgets/buttons.dart';
import '../../model/models.dart';
import '../../controller/calendar_controller.dart';
import '../../controller/employee_controller.dart';

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
  // Explicit, not derived from authController.role — an HR admin using
  // "Switch to Employee View" is still role == hrAdmin, so gating on role
  // alone let them add events from the employee-facing screen too. This
  // reflects which shell/context the screen was opened from instead.
  final bool isAdminView;
  const CompanyCalendarScreen({super.key, this.isAdminView = false});

  @override
  State<CompanyCalendarScreen> createState() => _CompanyCalendarScreenState();
}

class _CompanyCalendarScreenState extends State<CompanyCalendarScreen> {
  String _filter = 'All';
  final _filters = ['All', 'Public Holiday', 'Company Event', 'HR Event'];
  static final _dateFormat = DateFormat('d MMM yyyy');
  static final _monthFormat = DateFormat('MMM yyyy');
  bool _gridView = false;
  DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    calendarController.load();
  }

  bool get _isHr => widget.isAdminView;

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
          IconButton(
            tooltip: _gridView ? 'List view' : 'Month view',
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(_gridView ? Icons.view_agenda_outlined : Icons.calendar_view_month_rounded),
          ),
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
            if (calendarController.errorMessage != null && calendarController.events.isEmpty) {
              return Center(
                child: EmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Could not load the calendar',
                  subtitle: calendarController.errorMessage!,
                  onRetry: calendarController.load,
                ),
              );
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
                  child: _gridView
                      ? _MonthGridView(
                          visibleMonth: _visibleMonth,
                          selectedDay: _selectedDay,
                          events: filtered,
                          onMonthChanged: (m) => setState(() {
                            _visibleMonth = m;
                            _selectedDay = null;
                          }),
                          onDaySelected: (d) => setState(() => _selectedDay = d),
                          onClose: () => setState(() => _selectedDay = null),
                          dateFormat: _dateFormat,
                          isHr: _isHr,
                          onEventTap: _isHr ? _showEventOptions : null,
                        )
                      : filtered.isEmpty
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

class _MonthGridView extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime? selectedDay;
  final List<CalendarEvent> events;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDaySelected;
  final VoidCallback onClose;
  final DateFormat dateFormat;
  final bool isHr;
  final ValueChanged<CalendarEvent>? onEventTap;

  const _MonthGridView({
    required this.visibleMonth,
    required this.selectedDay,
    required this.events,
    required this.onMonthChanged,
    required this.onDaySelected,
    required this.onClose,
    required this.dateFormat,
    required this.isHr,
    this.onEventTap,
  });

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<CalendarEvent> _eventsOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return events.where((e) {
      final start = DateTime(e.eventDate.year, e.eventDate.month, e.eventDate.day);
      final end = e.endDate != null ? DateTime(e.endDate!.year, e.endDate!.month, e.endDate!.day) : start;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final today = DateTime.now();
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leadingBlank = firstOfMonth.weekday - 1; // Monday-first week
    final totalCells = ((leadingBlank + daysInMonth) / 7).ceil() * 7;
    final selectedEvents = selectedDay != null ? _eventsOn(selectedDay!) : const <CalendarEvent>[];

    return Stack(
      children: [
        // The grid itself scrolls (rather than being squeezed into a fixed
        // Expanded region) so it's never clipped on shorter screens — event
        // details for the selected day now float over it instead of
        // competing with it for vertical space.
        SingleChildScrollView(
          padding: EdgeInsets.only(bottom: selectedDay != null ? 160 : 24),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month - 1)),
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Text(DateFormat('MMMM yyyy').format(visibleMonth), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    IconButton(
                      onPressed: () => onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month + 1)),
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                      .map((d) => Expanded(child: Center(child: Text(d, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.textMuted)))))
                      .toList(),
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.95),
                  itemCount: totalCells,
                  itemBuilder: (context, i) {
                    if (i < leadingBlank) return const SizedBox.shrink();
                    final dayNum = i - leadingBlank + 1;
                    if (dayNum > daysInMonth) return const SizedBox.shrink();
                    final day = DateTime(visibleMonth.year, visibleMonth.month, dayNum);
                    final dayEvents = _eventsOn(day);
                    final isToday = _sameDay(day, today);
                    final isSelected = selectedDay != null && _sameDay(day, selectedDay!);
                    return GestureDetector(
                      onTap: dayEvents.isEmpty ? null : () => onDaySelected(day),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: isSelected ? c.primary : (isToday ? c.primaryLight : null),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$dayNum',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: (isToday || isSelected) ? FontWeight.w800 : FontWeight.w500,
                                color: isSelected ? Colors.white : (isToday ? c.primaryDark : c.textPrimary),
                              ),
                            ),
                            if (dayEvents.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: dayEvents.take(3).map((e) {
                                  final (color, _) = resolveHue(c, _hueFor(e.type));
                                  return Container(
                                    width: 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(horizontal: 1),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: isSelected ? Colors.white : color),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (selectedDay == null) ...[
                const SizedBox(height: 20),
                Center(child: Text('Tap a day with a dot to see its events', style: TextStyle(fontSize: 12.5, color: c.textMuted))),
              ],
            ],
          ),
        ),
        if (selectedDay != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _FloatingDayBanner(
              day: selectedDay!,
              events: selectedEvents,
              dateFormat: dateFormat,
              isHr: isHr,
              onEventTap: onEventTap,
              onClose: onClose,
            ),
          ),
      ],
    );
  }
}

class _FloatingDayBanner extends StatelessWidget {
  final DateTime day;
  final List<CalendarEvent> events;
  final DateFormat dateFormat;
  final bool isHr;
  final ValueChanged<CalendarEvent>? onEventTap;
  final VoidCallback onClose;

  const _FloatingDayBanner({
    required this.day,
    required this.events,
    required this.dateFormat,
    required this.isHr,
    required this.onClose,
    this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    DateFormat('EEEE, d MMMM').format(day),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  icon: Icon(Icons.close_rounded, size: 20, color: c.textMuted),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: events.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Text('No events on this day', style: TextStyle(fontSize: 12.5, color: c.textMuted)),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: events
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _EventTile(event: e, dateFormat: dateFormat, onTap: isHr ? () => onEventTap?.call(e) : null),
                            ))
                        .toList(),
                  ),
          ),
        ],
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
                  if (event.assignedTo.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded, size: 12, color: c.textMuted),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Assigned to: ${event.assignedTo.map((a) => a.name).join(', ')}',
                            style: TextStyle(fontSize: 11, color: c.textMuted, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
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
  late final Map<String, String> _assigned = {
    for (final a in widget.existing?.assignedTo ?? const <AssignedEmployee>[]) a.uuid: a.name,
  };

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _endDate = widget.existing?.endDate;
    if (employeeController.employees.isEmpty) {
      employeeController.loadEmployees();
    }
  }

  Future<void> _pickAssignees() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssigneePickerSheet(initiallySelected: _assigned),
    );
    if (result != null) {
      setState(() {
        _assigned
          ..clear()
          ..addAll(result);
      });
    }
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
            assignedUuids: _assigned.keys.toList(),
          )
        : await calendarController.create(
            title: _title.text.trim(),
            eventDate: _eventDate,
            endDate: _endDate,
            displayType: _type,
            assignedUuids: _assigned.keys.toList(),
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
            const SizedBox(height: 14),

            Text('Assign To (optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('Leave empty for everyone to see this event.', style: TextStyle(fontSize: 11.5, color: c.textMuted)),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickAssignees,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: c.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded, size: 16, color: c.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _assigned.isEmpty ? 'Everyone (company-wide)' : '${_assigned.length} employee${_assigned.length > 1 ? 's' : ''} selected',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                    ),
                    Text('Choose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: c.primary)),
                  ],
                ),
              ),
            ),
            if (_assigned.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _assigned.entries.map((e) => Chip(
                  label: Text(e.value, style: const TextStyle(fontSize: 11.5)),
                  visualDensity: VisualDensity.compact,
                  onDeleted: () => setState(() => _assigned.remove(e.key)),
                )).toList(),
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

class _AssigneePickerSheet extends StatefulWidget {
  final Map<String, String> initiallySelected;
  const _AssigneePickerSheet({required this.initiallySelected});

  @override
  State<_AssigneePickerSheet> createState() => _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends State<_AssigneePickerSheet> {
  late final Map<String, String> _selected = Map.of(widget.initiallySelected);
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListenableBuilder(
      listenable: employeeController,
      builder: (context, _) {
        final q = _query.trim().toLowerCase();
        final employees = q.isEmpty
            ? employeeController.employees
            : employeeController.employees.where((e) =>
                e.name.toLowerCase().contains(q) ||
                e.jobTitle.toLowerCase().contains(q) ||
                e.department.toLowerCase().contains(q)).toList();
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Assign To', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: const Text('Done'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search by name, role, or department',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: employees.isEmpty
                    ? Center(
                        child: Text(
                          q.isEmpty ? 'No employees found.' : 'No employees match "$_query".',
                          style: TextStyle(fontSize: 12.5, color: c.textMuted),
                        ),
                      )
                    : ListView.separated(
                        itemCount: employees.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final e = employees[i];
                          final checked = _selected.containsKey(e.uuid);
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                            subtitle: Text('${e.jobTitle} · ${e.department}', style: TextStyle(fontSize: 12, color: c.textMuted)),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selected[e.uuid] = e.name;
                              } else {
                                _selected.remove(e.uuid);
                              }
                            }),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
