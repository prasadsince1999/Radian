import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_presets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/models/subtask_item.dart';
import '../../../core/utils/time_formatters.dart';
import '../../controllers/clock_controller.dart';
import '../../controllers/cloud_sync_controller.dart';
import '../common/bouncy_pressable.dart';
import 'subtask_edit_sheet.dart';
import 'components/event_date_repeat_card.dart';
import 'icon_color_picker_sheet.dart';

/// Modal bottom sheet for creating or editing a Sectograph time block.
class EventEditModal extends ConsumerStatefulWidget {
  final SectorEvent? event;
  final DateTime initialDate;

  const EventEditModal({super.key, this.event, required this.initialDate});

  @override
  ConsumerState<EventEditModal> createState() => _EventEditModalState();
}

class _EventEditModalState extends ConsumerState<EventEditModal> {
  late TextEditingController _titleController;
  late TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _selectedCategory;
  late String _selectedColorHex;
  late String _selectedIconName;
  late List<SubtaskItem> _subtaskItems;
  late bool _isAllDay;
  int? _selectedReminderMinutes;
  late Set<int> _selectedWeeklyDays;
  late bool _isUnlimitedEndDate;
  DateTime? _recurrenceEndDate;

  late List<String> _palette;

  @override
  void initState() {
    super.initState();
    _palette = List<String>.from(AppPresets.defaultColorPalette);
    final ev = widget.event;
    final now = DateTime.now();

    _titleController = TextEditingController(text: ev?.title ?? '');
    _notesController = TextEditingController(text: ev?.notes ?? '');
    _subtaskItems = List<SubtaskItem>.from(ev?.subtaskItems ?? const []);

    _startDate = ev?.start ?? widget.initialDate;

    final nextSlotMinutes = ((now.minute ~/ 15) + 1) * 15;
    final DateTime defaultStart;
    final DateTime defaultEnd;
    if (now.hour >= 23) {
      defaultStart = DateTime(now.year, now.month, now.day, 22, 0);
      defaultEnd = DateTime(now.year, now.month, now.day, 23, 0);
    } else {
      defaultStart = now.add(Duration(minutes: nextSlotMinutes - now.minute));
      final rawEnd = defaultStart.add(const Duration(hours: 1));
      defaultEnd = rawEnd.day != defaultStart.day
          ? DateTime(
              defaultStart.year,
              defaultStart.month,
              defaultStart.day,
              23,
              59,
            )
          : rawEnd;
    }

    _startTime = ev != null
        ? TimeOfDay(hour: ev.start.hour, minute: ev.start.minute)
        : TimeOfDay(hour: defaultStart.hour, minute: defaultStart.minute);

    _endTime = ev != null
        ? TimeOfDay(hour: ev.end.hour, minute: ev.end.minute)
        : TimeOfDay(hour: defaultEnd.hour, minute: defaultEnd.minute);

    final isOvernight =
        _endTime.hour * 60 + _endTime.minute <=
        _startTime.hour * 60 + _startTime.minute;
    _endDate =
        ev?.end ??
        (isOvernight ? _startDate.add(const Duration(days: 1)) : _startDate);

    _selectedCategory = ev?.category ?? 'Work';
    _selectedColorHex = ev?.colorHex ?? '#6366F1';
    _selectedIconName = ev?.effectiveIconName ?? '';
    _selectedReminderMinutes = ev?.reminderMinutes;

    final isRepeating =
        (ev?.repeatDays != null && ev!.repeatDays!.isNotEmpty) ||
        (ev?.recurrenceEndDate != null);

    if (ev == null) {
      _isUnlimitedEndDate = true;
      _selectedWeeklyDays = <int>{};
      _recurrenceEndDate = null;
      _endDate = _startDate;
    } else if (isRepeating) {
      _isUnlimitedEndDate = ev.recurrenceEndDate == null;
      _recurrenceEndDate = ev.recurrenceEndDate;
      _endDate = ev.recurrenceEndDate ?? _startDate;
      _selectedWeeklyDays = ev.repeatDays != null && ev.repeatDays!.isNotEmpty
          ? (ev.repeatDays!.length == 7
                ? <int>{}
                : Set<int>.from(ev.repeatDays!))
          : <int>{};
    } else {
      _isUnlimitedEndDate = false;
      _recurrenceEndDate = null;
      _endDate = _startDate;
      _selectedWeeklyDays = <int>{};
    }
    _isAllDay = ev?.isAllDay ?? false;
  }

  IconData? get _selectedIconData {
    if (_selectedIconName.isEmpty) return null;
    return AppPresets.getIconById(_selectedIconName);
  }

  Future<void> _openIconPicker(BuildContext context) async {
    final result = await IconColorPickerSheet.show(
      context,
      initialIconName: _selectedIconName,
      initialColorHex: _selectedColorHex,
      palette: _palette,
    );
    if (result != null && mounted) {
      setState(() {
        _selectedIconName = result.$1;
        _selectedColorHex = result.$2;
        if (!_palette.any((h) => h.toUpperCase() == result.$2.toUpperCase())) {
          _palette.add(result.$2);
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    try {
      final clean = _selectedColorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFFD4A373);
    }
  }

  int get _durationMinutes {
    final sMin = _startTime.hour * 60 + _startTime.minute;
    var eMin = _endTime.hour * 60 + _endTime.minute;
    if (eMin <= sMin) {
      eMin += 24 * 60;
    }
    return eMin - sMin;
  }

  String get _durationLabel {
    final mins = _durationMinutes;
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    if (hours == 0) return '${remMins}m';
    if (remMins == 0) return '${hours}h';
    return '${hours}h ${remMins}m';
  }

  DateTime _combine(DateTime date, TimeOfDay tod) {
    return DateTime(date.year, date.month, date.day, tod.hour, tod.minute);
  }

  void _toggleWeekday(int day) {
    setState(() {
      if (_selectedWeeklyDays.contains(day)) {
        _selectedWeeklyDays.remove(day);
      } else {
        _selectedWeeklyDays.add(day);
      }
      if (_selectedWeeklyDays.isNotEmpty &&
          !_isUnlimitedEndDate &&
          (_recurrenceEndDate == null ||
              !_recurrenceEndDate!.isAfter(_startDate))) {
        _isUnlimitedEndDate = true;
      }
    });
  }

  void _toggleUnlimitedEndDate() {
    setState(() {
      _isUnlimitedEndDate = !_isUnlimitedEndDate;
      if (_isUnlimitedEndDate) {
        _recurrenceEndDate = null;
      } else {
        _selectedWeeklyDays.clear();
        _endDate = _startDate;
        _recurrenceEndDate = null;
      }
    });
  }

  Future<void> _pickDate([bool isStart = true]) async {
    final initial = isStart
        ? _startDate
        : (_endDate.isBefore(_startDate) ? _startDate : _endDate);
    final accent = _currentColor;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final baseTheme = Theme.of(context);
    final colorScheme = baseTheme.colorScheme;
    final isDark = baseTheme.brightness == Brightness.dark;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: isStart ? DateTime(2020) : _startDate,
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: accent,
              onPrimary: onAccent,
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              headerBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
              headerForegroundColor: colorScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
              ),
              dayForegroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return onAccent;
                }
                if (states.contains(WidgetState.disabled)) {
                  return colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
                }
                return colorScheme.onSurface;
              }),
              dayBackgroundColor: WidgetStateColor.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return accent;
                }
                return Colors.transparent;
              }),
              todayForegroundColor: WidgetStatePropertyAll(accent),
              todayBorder: BorderSide(color: accent, width: 1.2),
              yearForegroundColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? onAccent
                    : colorScheme.onSurface,
              ),
              yearBackgroundColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent
                    : Colors.transparent,
              ),
              cancelButtonStyle: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurfaceVariant,
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
              confirmButtonStyle: TextButton.styleFrom(
                foregroundColor: accent,
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (!_isUnlimitedEndDate && _endDate.isBefore(_startDate)) {
            _endDate = _startDate;
            _recurrenceEndDate = _startDate;
          }
        } else {
          _endDate = picked;
          _recurrenceEndDate = picked;
          _isUnlimitedEndDate = false;
        }
      });
    }
  }

  void _deleteEvent() {
    if (widget.event != null) {
      final ev = widget.event!;
      final messenger = ScaffoldMessenger.of(context);
      final colorScheme = Theme.of(context).colorScheme;
      HapticFeedback.mediumImpact();
      ref.read(eventRepositoryProvider).deleteEvent(ev.id);
      Navigator.of(context).pop();
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Deleted "${ev.title}"',
            style: TextStyle(
              color: colorScheme.brightness == Brightness.dark
                  ? colorScheme.onSurface
                  : colorScheme.onInverseSurface,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          backgroundColor: colorScheme.brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          behavior: SnackBarBehavior.fixed,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Undo',
            textColor: colorScheme.primary,
            onPressed: () {
              HapticFeedback.lightImpact();
              ref.read(eventRepositoryProvider).addEvent(ev);
            },
          ),
        ),
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(eventRepositoryProvider);
    final startDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0)
        : _combine(_startDate, _startTime);

    if (widget.event == null) {
      final dialSettings = ref.read(dialSettingsProvider);
      final is24H = dialSettings.is24HourMode;
      final maxAllowed = is24H
          ? AppLayoutConstants.maxBlocks24H
          : AppLayoutConstants.maxBlocks12H;
      final existingEvents = await repo.getEventsForDay(startDt);
      if (existingEvents.length >= maxAllowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Dial limit reached: maximum $maxAllowed blocks allowed in ${is24H ? "24H" : "12H"} mode to prevent visual clutter.',
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        return;
      }
    }

    final isOvernight =
        _endTime.hour * 60 + _endTime.minute <=
        _startTime.hour * 60 + _startTime.minute;
    final effectiveEndDate = isOvernight
        ? _startDate.add(const Duration(days: 1))
        : _startDate;

    var endDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day, 23, 59)
        : _combine(effectiveEndDate, _endTime);

    if (!_isAllDay && !endDt.isAfter(startDt)) {
      endDt = startDt.add(const Duration(hours: 1));
    }

    final effectiveRepeatDays = () {
      if (_selectedWeeklyDays.isNotEmpty) {
        return _selectedWeeklyDays.toList()..sort();
      }
      if (_isUnlimitedEndDate) {
        return [1, 2, 3, 4, 5, 6, 7];
      }
      if (_recurrenceEndDate != null &&
          _recurrenceEndDate!.isAfter(_startDate)) {
        return [1, 2, 3, 4, 5, 6, 7];
      }
      return null;
    }();

    final effectiveRecurrenceEndDate = _isUnlimitedEndDate
        ? null
        : (_endDate.isAfter(_startDate) ? _endDate : null);

    final newEvent = SectorEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: title,
      start: startDt,
      end: endDt,
      colorHex: _selectedColorHex,
      notes: _notesController.text.trim(),
      category: _selectedCategory,
      isAllDay: _isAllDay,
      iconName: _selectedIconName.isEmpty ? null : _selectedIconName,
      reminderMinutes: _selectedReminderMinutes,
      repeatDays: effectiveRepeatDays,
      recurrenceEndDate: effectiveRecurrenceEndDate,
      subtaskItems: _subtaskItems,
    );

    if (widget.event == null) {
      repo.addEvent(newEvent);
      ref.read(selectedEventProvider.notifier).state = newEvent;
    } else {
      repo.updateEvent(newEvent);
      final currentSelected = ref.read(selectedEventProvider);
      if (currentSelected?.id == newEvent.id) {
        ref.read(selectedEventProvider.notifier).state = newEvent;
      }
    }

    ref.read(cloudSyncServiceProvider).queueUpsert(newEvent);
    ref.read(cloudSyncControllerProvider.notifier).syncNow();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final currentColor = _currentColor;

    final addBlockBg = currentColor;
    final addBlockBorder = currentColor;
    final addBlockText =
        ThemeData.estimateBrightnessForColor(currentColor) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final cardBg = colorScheme.surfaceContainer;
    final cardBorder = colorScheme.outlineVariant;
    final chassisBg = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surface;
    return Container(
      decoration: BoxDecoration(
        color: chassisBg,
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

              // Header: Back Button + Title + (Delete Button if editing)
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
                      widget.event == null
                          ? 'New Time Block'
                          : 'Edit Time Block',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (widget.event != null) ...[
                    Tooltip(
                      message: 'Delete',
                      child: BouncyPressable(
                        scaleDownFactor: 0.90,
                        onTap: _deleteEvent,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.3),
                              width: 1.0,
                            ),
                          ),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Tooltip(
                    message: 'Save',
                    child: BouncyPressable(
                      scaleDownFactor: 0.90,
                      onTap: _save,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: currentColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: currentColor.withValues(alpha: 0.4),
                            width: 1.0,
                          ),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: currentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Unified Title & Category Card
              Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        BouncyPressable(
                          key: const ValueKey('select_icon_button'),
                          scaleDownFactor: 0.92,
                          onTap: () => _openIconPicker(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: currentColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: currentColor,
                                width: 1.2,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                _selectedIconData ?? Icons.add_rounded,
                                size: 22,
                                color: currentColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            maxLength: 30,
                            buildCounter: (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
                            decoration: InputDecoration(
                              hintText: 'Event name',
                              hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w500,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _save(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      height: 1,
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 10),
                    // Merged Category Chips directly inside Title Block
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: AppPresets.defaultCategories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final cat = AppPresets.defaultCategories[i];
                          final isSelected = _selectedCategory == cat;
                          return BouncyPressable(
                            scaleDownFactor: 0.94,
                            onTap: () {
                              setState(() {
                                _selectedCategory = cat;
                                final currentTitle = _titleController.text
                                    .trim();
                                if (currentTitle.isEmpty ||
                                    currentTitle == 'New Block' ||
                                    AppPresets.defaultCategories.contains(
                                      currentTitle,
                                    )) {
                                  _titleController.text = cat;
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? currentColor
                                    : colorScheme.surfaceContainer,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: isSelected
                                      ? currentColor
                                      : colorScheme.outlineVariant,
                                  width: 1.0,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? (ThemeData.estimateBrightnessForColor(
                                                    currentColor,
                                                  ) ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : Colors.black87)
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Start & End Time Card (Clean & Tappable, No All-day / drag helper)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 18,
                          color: currentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TIME',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: currentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _durationLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: currentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            key: const ValueKey('start_time_tile'),
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
                                  TimeFormatters.formatTimeOfDay(_startTime),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            key: const ValueKey('end_time_tile'),
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
                                  TimeFormatters.formatTimeOfDay(_endTime),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 13,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Block times are set by dragging sectors on the watch dial',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 3. Subtasks Card (Moved to Upper Side + In-Block Scheduling)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: cardBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 18,
                          color: currentColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Subtasks (${_subtaskItems.length})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ),
                        BouncyPressable(
                          onTap: () async {
                            final created = await SubtaskEditSheet.show(
                              context,
                              initialParentEventId: widget.event?.id,
                              initialDate: _startDate,
                              parentStartTime: _startTime,
                              parentEndTime: _endTime,
                            );
                            if (created != null && mounted) {
                              setState(() {
                                _subtaskItems.add(created);
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: currentColor.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: currentColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.add_rounded,
                                  size: 14,
                                  color: currentColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Add Subtask',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: currentColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_subtaskItems.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subtaskItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (context, idx) {
                          final item = _subtaskItems[idx];
                          final timeStr =
                              item.startTime != null && item.endTime != null
                              ? '${TimeFormatters.formatTimeOfDay(item.startTime!)} – ${TimeFormatters.formatTimeOfDay(item.endTime!)}'
                              : null;
                          return InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              final updated = await SubtaskEditSheet.show(
                                context,
                                subtask: item,
                                initialParentEventId: widget.event?.id,
                                initialDate: _startDate,
                                parentStartTime: _startTime,
                                parentEndTime: _endTime,
                              );
                              if (updated != null && mounted) {
                                setState(() {
                                  _subtaskItems[idx] = updated;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.04)
                                    : Colors.black.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white12
                                      : Colors.black12,
                                ),
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _subtaskItems[idx] = item.copyWith(
                                          isCompleted: !item.isCompleted,
                                        );
                                      });
                                    },
                                    child: Icon(
                                      item.isCompleted
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      size: 18,
                                      color: item.isCompleted
                                          ? currentColor
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface,
                                            decoration: item.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (timeStr != null ||
                                            item.reminderMinutes != null) ...[
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              if (timeStr != null) ...[
                                                Icon(
                                                  Icons.schedule_rounded,
                                                  size: 11,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  timeStr,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: colorScheme
                                                        .onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                              if (timeStr != null &&
                                                  item.reminderMinutes != null)
                                                const SizedBox(width: 8),
                                              if (item.reminderMinutes !=
                                                  null) ...[
                                                Icon(
                                                  Icons
                                                      .notifications_active_outlined,
                                                  size: 11,
                                                  color: currentColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${item.reminderMinutes}m before',
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: currentColor,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _subtaskItems.removeAt(idx);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'No subtasks yet. Tap "+ Add Subtask" to schedule a dedicated task with timing & reminder.',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontStyle: FontStyle.italic,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.7,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. Date & Repeat Card
              EventDateRepeatCard(
                startDate: _startDate,
                endDate: _endDate,
                isUnlimitedEndDate: _isUnlimitedEndDate,
                selectedWeeklyDays: _selectedWeeklyDays,
                currentColor: currentColor,
                cardBg: cardBg,
                cardBorder: cardBorder,
                onPickDate: _pickDate,
                onToggleUnlimited: _toggleUnlimitedEndDate,
                onToggleWeekday: _toggleWeekday,
              ),
              const SizedBox(height: 16),

              // Hero Save Button
              BouncyPressable(
                scaleDownFactor: 0.94,
                onTap: _save,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: addBlockBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: addBlockBorder, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      widget.event == null
                          ? AppStrings.createBlock
                          : AppStrings.saveChanges,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: addBlockText,
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
