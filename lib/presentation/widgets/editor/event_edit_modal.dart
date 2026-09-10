import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_presets.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';
import 'components/event_category_selector.dart';
import 'components/event_date_repeat_card.dart';
import 'components/event_reminder_card.dart';
import 'components/event_time_card.dart';
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
  bool _isAllDay = false;
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

    _startDate = ev?.start ?? widget.initialDate;

    final nextSlotMinutes = ((now.minute ~/ 15) + 1) * 15;
    final defaultStart = now.add(
      Duration(minutes: nextSlotMinutes - now.minute),
    );
    final defaultEnd = defaultStart.add(const Duration(hours: 1));

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
    _selectedIconName = ev?.iconName ?? '';
    _selectedReminderMinutes = ev?.reminderMinutes;

    _selectedWeeklyDays = ev?.repeatDays != null
        ? Set<int>.from(ev!.repeatDays!)
        : <int>{};
    _isUnlimitedEndDate = ev?.recurrenceEndDate == null;
    _recurrenceEndDate = ev?.recurrenceEndDate;
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

  void _applyDurationMinutes(int targetMinutes) {
    setState(() {
      final totalStartMin = _startTime.hour * 60 + _startTime.minute;
      final targetEndMin = (totalStartMin + targetMinutes) % (24 * 60);
      _endTime = TimeOfDay(hour: targetEndMin ~/ 60, minute: targetEndMin % 60);
    });
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
    });
  }

  void _toggleUnlimitedEndDate() {
    setState(() {
      _isUnlimitedEndDate = !_isUnlimitedEndDate;
      if (!_isUnlimitedEndDate) {
        if (_recurrenceEndDate != null &&
            _recurrenceEndDate!.isAfter(_startDate)) {
          _endDate = _recurrenceEndDate!;
        } else {
          _endDate = _startDate.add(const Duration(days: 7));
          _recurrenceEndDate = _endDate;
        }
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

  Future<void> _pickTime(bool isStart) async {
    final initial = isStart ? _startTime : _endTime;
    final accent = _currentColor;
    final onAccent =
        ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
        ? Colors.white
        : Colors.black;

    final baseTheme = Theme.of(context);
    final colorScheme = baseTheme.colorScheme;
    final isDark = baseTheme.brightness == Brightness.dark;

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) {
        return Theme(
          data: baseTheme.copyWith(
            colorScheme: colorScheme.copyWith(
              primary: accent,
              onPrimary: onAccent,
            ),
            timePickerTheme: TimePickerThemeData(
              backgroundColor: isDark
                  ? colorScheme.surfaceContainerHigh
                  : colorScheme.surface,
              helpTextStyle: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
              ),
              hourMinuteColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
              hourMinuteTextColor: colorScheme.onSurface,
              dialBackgroundColor: isDark
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
              dialHandColor: accent,
              dialTextColor: colorScheme.onSurface,
              entryModeIconColor: accent,
              dayPeriodShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
              ),
              dayPeriodColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent.withValues(alpha: 0.25)
                    : (isDark
                          ? colorScheme.surfaceContainerHighest
                          : colorScheme.surfaceContainerHigh),
              ),
              dayPeriodTextColor: WidgetStateColor.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? accent
                    : colorScheme.onSurfaceVariant,
              ),
              dayPeriodBorderSide: BorderSide(
                color: colorScheme.outlineVariant,
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
          _startTime = picked;
          final sMin = _startTime.hour * 60 + _startTime.minute;
          final eMin = _endTime.hour * 60 + _endTime.minute;
          if (eMin <= sMin) {
            _endTime = TimeOfDay(
              hour: (_startTime.hour + 1) % 24,
              minute: _startTime.minute,
            );
          }
        } else {
          _endTime = picked;
        }
        final isOvernight =
            _endTime.hour * 60 + _endTime.minute <=
            _startTime.hour * 60 + _startTime.minute;
        _endDate = isOvernight
            ? _startDate.add(const Duration(days: 1))
            : _startDate;
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
          content: Text('Deleted "${ev.title}"'),
          behavior: SnackBarBehavior.floating,
          shape: ExpressiveShapes.full,
          action: SnackBarAction(
            label: 'UNDO',
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

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final repo = ref.read(eventRepositoryProvider);
    final startDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0)
        : _combine(_startDate, _startTime);

    var endDt = _isAllDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day, 23, 59)
        : _combine(_endDate, _endTime);

    if (!_isAllDay && !endDt.isAfter(startDt)) {
      endDt = startDt.add(const Duration(hours: 1));
    }

    final newEvent = SectorEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      title: title,
      start: startDt,
      end: endDt,
      colorHex: _selectedColorHex,
      notes: _notesController.text.trim(),
      category: _selectedCategory,
      iconName: _selectedIconName.isEmpty ? null : _selectedIconName,
      reminderMinutes: _selectedReminderMinutes,
      repeatDays: _selectedWeeklyDays.isEmpty
          ? null
          : _selectedWeeklyDays.toList(),
      recurrenceEndDate: _isUnlimitedEndDate ? null : _recurrenceEndDate,
    );

    if (widget.event == null) {
      repo.addEvent(newEvent);
    } else {
      repo.updateEvent(newEvent);
    }

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
        top: false,
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
                  if (widget.event != null)
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
                ],
              ),
              const SizedBox(height: 14),

              // Title input with Icon button
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
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
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
                          border: Border.all(color: currentColor, width: 1.2),
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
              ),
              const SizedBox(height: 12),

              // Category Selector
              EventCategorySelector(
                selectedCategory: _selectedCategory,
                currentColor: currentColor,
                onCategorySelected: (cat) =>
                    setState(() => _selectedCategory = cat),
              ),
              const SizedBox(height: 12),

              // Time Card
              EventTimeCard(
                startTime: _startTime,
                endTime: _endTime,
                isAllDay: _isAllDay,
                durationMinutes: _durationMinutes,
                durationLabel: _durationLabel,
                currentColor: currentColor,
                cardBg: cardBg,
                cardBorder: cardBorder,
                onPickTime: _pickTime,
                onToggleAllDay: () => setState(() => _isAllDay = !_isAllDay),
                onDurationChanged: _applyDurationMinutes,
              ),
              const SizedBox(height: 12),

              // Date & Repeat Card
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
              const SizedBox(height: 12),

              // Reminder Card
              EventReminderCard(
                selectedReminderMinutes: _selectedReminderMinutes,
                currentColor: currentColor,
                cardBg: cardBg,
                cardBorder: cardBorder,
                onReminderSelected: (mins) =>
                    setState(() => _selectedReminderMinutes = mins),
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
