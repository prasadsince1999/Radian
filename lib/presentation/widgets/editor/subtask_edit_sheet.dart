import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/models/subtask_item.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';

/// Dedicated single-subtask creation and editing modal sheet.
///
/// Ensures every subtask has full control over title, parent time block assignment,
/// dedicated timing, date, and notification reminders.
class SubtaskEditSheet extends ConsumerStatefulWidget {
  final SubtaskItem? existingSubtask;
  final String? initialParentEventId;
  final DateTime? initialDate;
  final TimeOfDay? parentStartTime;
  final TimeOfDay? parentEndTime;

  const SubtaskEditSheet({
    super.key,
    this.existingSubtask,
    this.initialParentEventId,
    this.initialDate,
    this.parentStartTime,
    this.parentEndTime,
  });

  static Future<SubtaskItem?> show(
    BuildContext context, {
    SubtaskItem? existingSubtask,
    SubtaskItem? subtask,
    String? initialParentEventId,
    DateTime? initialDate,
    TimeOfDay? parentStartTime,
    TimeOfDay? parentEndTime,
  }) {
    return showModalBottomSheet<SubtaskItem>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(
        maxWidth: AppLayoutConstants.modalMaxWidth,
      ),
      shape: ExpressiveShapes.modalSheet,
      builder: (_) => SubtaskEditSheet(
        existingSubtask: subtask ?? existingSubtask,
        initialParentEventId: initialParentEventId,
        initialDate: initialDate,
        parentStartTime: parentStartTime,
        parentEndTime: parentEndTime,
      ),
    );
  }

  @override
  ConsumerState<SubtaskEditSheet> createState() => _SubtaskEditSheetState();
}

class _SubtaskEditSheetState extends ConsumerState<SubtaskEditSheet> {
  late final TextEditingController _titleController;
  late String _selectedParentEventId;
  late DateTime _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  int? _selectedReminderMinutes;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingSubtask;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _selectedParentEventId =
        existing?.parentEventId ?? widget.initialParentEventId ?? '';
    _selectedDate = existing?.date ?? widget.initialDate ?? DateTime.now();
    _startTime = existing?.startTime;
    _endTime = existing?.endTime;

    // If creating new subtask with parent time bounds provided, default inside parent block
    if (existing == null && widget.parentStartTime != null) {
      _startTime = widget.parentStartTime;
      if (widget.parentEndTime != null) {
        final sMins =
            widget.parentStartTime!.hour * 60 + widget.parentStartTime!.minute;
        final eMins =
            widget.parentEndTime!.hour * 60 + widget.parentEndTime!.minute;
        final subEndMins = (sMins + 30 <= eMins) ? (sMins + 30) : eMins;
        _endTime = TimeOfDay(
          hour: (subEndMins ~/ 60) % 24,
          minute: subEndMins % 60,
        );
      } else {
        _endTime = TimeOfDay(
          hour:
              (widget.parentStartTime!.hour +
                  (widget.parentStartTime!.minute >= 30 ? 1 : 0)) %
              24,
          minute: (widget.parentStartTime!.minute + 30) % 60,
        );
      }
    }

    _selectedReminderMinutes = existing?.reminderMinutes;
    _isCompleted = existing?.isCompleted ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = (isStart ? _startTime : _endTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
          _endTime ??= TimeOfDay(
            hour: (picked.hour + (picked.minute >= 45 ? 1 : 0)) % 24,
            minute: (picked.minute + 15) % 60,
          );
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _applyQuickDuration(int minutes) {
    HapticFeedback.lightImpact();
    final baseStart = _startTime ?? TimeOfDay.now();
    final totalStartMinutes = baseStart.hour * 60 + baseStart.minute;
    final totalEndMinutes = totalStartMinutes + minutes;
    setState(() {
      _startTime = baseStart;
      _endTime = TimeOfDay(
        hour: (totalEndMinutes ~/ 60) % 24,
        minute: totalEndMinutes % 60,
      );
    });
  }

  void _save(List<SectorEvent> availableEvents) {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a subtask title'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (availableEvents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No time blocks available to save subtask into'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Determine target parent event
    SectorEvent? targetParent;
    if (_selectedParentEventId.isNotEmpty) {
      targetParent = availableEvents
          .where((e) => e.id == _selectedParentEventId)
          .firstOrNull;
    }
    targetParent ??= availableEvents.first;

    final repo = ref.read(eventRepositoryProvider);

    final subtask = SubtaskItem(
      id:
          widget.existingSubtask?.id ??
          SubtaskItem.create(parentEventId: targetParent.id, title: '').id,
      parentEventId: targetParent.id,
      title: title,
      isCompleted: _isCompleted,
      startTime: _startTime,
      endTime: _endTime,
      date: _selectedDate,
      reminderMinutes: _selectedReminderMinutes,
    );

    // If existing subtask moved from another parent, remove from old parent
    if (widget.existingSubtask != null &&
        widget.existingSubtask!.parentEventId != targetParent.id) {
      final oldParent = availableEvents
          .where((e) => e.id == widget.existingSubtask!.parentEventId)
          .firstOrNull;
      if (oldParent != null) {
        final updatedOldItems = oldParent.subtaskItems
            .where((s) => s.id != widget.existingSubtask!.id)
            .toList();
        repo.updateEvent(oldParent.copyWith(subtaskItems: updatedOldItems));
      }
    }

    // Add or update in target parent
    final currentSubtasks = List<SubtaskItem>.from(targetParent.subtaskItems);
    final existingIdx = currentSubtasks.indexWhere((s) => s.id == subtask.id);
    if (existingIdx != -1) {
      currentSubtasks[existingIdx] = subtask;
    } else {
      currentSubtasks.add(subtask);
    }

    final updatedParent = targetParent.copyWith(subtaskItems: currentSubtasks);
    repo.updateEvent(updatedParent);

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(subtask);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved subtask to "${targetParent.title}"'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final eventsAsync = ref.watch(eventsForDateProvider(_selectedDate));
    final availableEvents = (eventsAsync.value ?? const <SectorEvent>[])
        .where((e) => !e.isAllDay)
        .toList();

    // Ensure selected parent ID is valid
    if (_selectedParentEventId.isEmpty && availableEvents.isNotEmpty) {
      _selectedParentEventId = availableEvents.first.id;
    }

    final activeParent = availableEvents
        .where((e) => e.id == _selectedParentEventId)
        .firstOrNull;
    final parentColor = activeParent?.color ?? colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainerLow : colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottomInset),
      child: SafeArea(
        top: true,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Drag Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header: Back Button + Title + Save Check Button
              Row(
                children: [
                  BouncyPressable(
                    scaleDownFactor: 0.90,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 1.0,
                        ),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 20,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.existingSubtask == null
                          ? 'New Subtask'
                          : 'Edit Subtask',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Save Subtask',
                    child: BouncyPressable(
                      scaleDownFactor: 0.90,
                      onTap: () => _save(availableEvents),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: parentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: parentColor.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: parentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Subtask Title Input
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(Icons.task_alt_rounded, color: parentColor, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _titleController,
                        autofocus: widget.existingSubtask == null,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: 'What needs to be done?',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _save(availableEvents),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 1. Where to Save (Parent Time Block Selector)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          size: 18,
                          color: parentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'WHERE TO SAVE (PARENT BLOCK)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (availableEvents.isEmpty)
                      Text(
                        'No macro time blocks found for this date. Create a block on the dial first.',
                        style: TextStyle(
                          color: colorScheme.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                availableEvents.any(
                                  (e) => e.id == _selectedParentEventId,
                                )
                                ? _selectedParentEventId
                                : availableEvents.first.id,
                            isExpanded: true,
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              color: parentColor,
                            ),
                            items: availableEvents.map((ev) {
                              final is24 = ref
                                  .watch(dialSettingsProvider)
                                  .is24HourMode;
                              final timeStr =
                                  '${TimeFormatters.formatTime(ev.start, is24Hour: is24)} – ${TimeFormatters.formatTime(ev.end, is24Hour: is24)}';
                              return DropdownMenuItem<String>(
                                value: ev.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: ev.color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        ev.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          color: colorScheme.onSurface,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedParentEventId = val);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Timing Card (Start, End & Quick Durations)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: parentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SUBTASK TIMING',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (widget.parentStartTime != null &&
                        widget.parentEndTime != null) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: parentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 13,
                              color: parentColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Within block: ${widget.parentStartTime!.format(context)} – ${widget.parentEndTime!.format(context)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: parentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'START',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _startTime != null
                                        ? _startTime!.format(context)
                                        : 'Set Start',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickTime(false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'END',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _endTime != null
                                        ? _endTime!.format(context)
                                        : 'Set End',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (widget.parentStartTime != null &&
                              widget.parentEndTime != null) ...[
                            _DurationChip(
                              label: 'Full Block',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _startTime = widget.parentStartTime;
                                  _endTime = widget.parentEndTime;
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                            _DurationChip(
                              label: 'First 30m',
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final pStart = widget.parentStartTime!;
                                final pEnd = widget.parentEndTime!;
                                final sMins = pStart.hour * 60 + pStart.minute;
                                final eMins = pEnd.hour * 60 + pEnd.minute;
                                final subEndMins = (sMins + 30 <= eMins)
                                    ? (sMins + 30)
                                    : eMins;
                                setState(() {
                                  _startTime = pStart;
                                  _endTime = TimeOfDay(
                                    hour: (subEndMins ~/ 60) % 24,
                                    minute: subEndMins % 60,
                                  );
                                });
                              },
                            ),
                            const SizedBox(width: 6),
                          ],
                          _DurationChip(
                            label: '+15m',
                            onTap: () => _applyQuickDuration(15),
                          ),
                          const SizedBox(width: 6),
                          _DurationChip(
                            label: '+30m',
                            onTap: () => _applyQuickDuration(30),
                          ),
                          const SizedBox(width: 6),
                          _DurationChip(
                            label: '+45m',
                            onTap: () => _applyQuickDuration(45),
                          ),
                          const SizedBox(width: 6),
                          _DurationChip(
                            label: '+1h',
                            onTap: () => _applyQuickDuration(60),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Date & Reminder Row
              Row(
                children: [
                  // Date Card
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEE, MMM d').format(_selectedDate),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Reminder Card
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant,
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'REMINDER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<int?>(
                              value: _selectedReminderMinutes,
                              isDense: true,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('None'),
                                ),
                                DropdownMenuItem(
                                  value: 0,
                                  child: Text('At start'),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text('5 min before'),
                                ),
                                DropdownMenuItem(
                                  value: 10,
                                  child: Text('10 min before'),
                                ),
                                DropdownMenuItem(
                                  value: 15,
                                  child: Text('15 min before'),
                                ),
                                DropdownMenuItem(
                                  value: 30,
                                  child: Text('30 min before'),
                                ),
                              ],
                              onChanged: (mins) => setState(
                                () => _selectedReminderMinutes = mins,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Save Button
              BouncyPressable(
                scaleDownFactor: 0.94,
                onTap: () => _save(availableEvents),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: parentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      widget.existingSubtask == null
                          ? 'Save Subtask'
                          : 'Update Subtask',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color:
                            ThemeData.estimateBrightnessForColor(parentColor) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _DurationChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
