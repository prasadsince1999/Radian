import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';

class CalendarSheet extends ConsumerStatefulWidget {
  const CalendarSheet({super.key});

  @override
  ConsumerState<CalendarSheet> createState() => _CalendarSheetState();
}

class _CalendarSheetState extends ConsumerState<CalendarSheet> {
  late DateTime _displayedMonth;
  Map<int, List<SectorEvent>> _monthEvents = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final selectedDay = ref.read(selectedDayProvider);
    _displayedMonth = DateTime(selectedDay.year, selectedDay.month, 1);
    _loadEventsForMonth();
  }

  Future<void> _loadEventsForMonth() async {
    setState(() => _isLoading = true);
    final repo = ref.read(eventRepositoryProvider);
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );

    final eventMap = <int, List<SectorEvent>>{};
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayedMonth.year, _displayedMonth.month, day);
      final events = await repo.getEventsForDay(date);
      if (events.isNotEmpty) {
        eventMap[day] = events;
      }
    }

    if (mounted) {
      setState(() {
        _monthEvents = eventMap;
        _isLoading = false;
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
        1,
      );
    });
    _loadEventsForMonth();
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
        1,
      );
    });
    _loadEventsForMonth();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDay = ref.watch(selectedDayProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final firstDayOffset =
        DateTime(_displayedMonth.year, _displayedMonth.month, 1).weekday % 7;
    final daysInMonth = DateUtils.getDaysInMonth(
      _displayedMonth.year,
      _displayedMonth.month,
    );
    final totalCells = ((firstDayOffset + daysInMonth + 6) ~/ 7) * 7;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: AppLayoutConstants.dragHandleWidth,
                height: AppLayoutConstants.dragHandleHeight,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Month navigation header
            Row(
              children: [
                BouncyPressable(
                  scaleDownFactor: 0.88,
                  onTap: _previousMonth,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    DateFormat('MMMM yyyy').format(_displayedMonth),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                BouncyPressable(
                  scaleDownFactor: 0.88,
                  onTap: _nextMonth,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Weekday symbols
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
                return SizedBox(
                  width: 36,
                  child: Text(
                    day,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 11.5,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            // Days Grid
            if (_isLoading)
              SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(color: colorScheme.primary),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  final dayNumber = index - firstDayOffset + 1;
                  final isValidDay = dayNumber >= 1 && dayNumber <= daysInMonth;

                  if (!isValidDay) {
                    return const SizedBox.shrink();
                  }

                  final cellDate = DateTime(
                    _displayedMonth.year,
                    _displayedMonth.month,
                    dayNumber,
                  );
                  final isSelected =
                      cellDate.year == selectedDay.year &&
                      cellDate.month == selectedDay.month &&
                      cellDate.day == selectedDay.day;
                  final isCurrentDay = cellDate == today;
                  final events = _monthEvents[dayNumber] ?? [];

                  return BouncyPressable(
                    scaleDownFactor: 0.90,
                    onTap: () {
                      ref.read(customSelectedDayProvider.notifier).state =
                          cellDate;
                      ref.read(selectedEventProvider.notifier).state = null;
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : isCurrentDay
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? colorScheme.primary
                              : isCurrentDay
                              ? colorScheme.secondary
                              : colorScheme.outlineVariant,
                          width: isSelected || isCurrentDay ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNumber',
                            style: TextStyle(
                              fontWeight: isSelected || isCurrentDay
                                  ? FontWeight.w900
                                  : FontWeight.w600,
                              fontSize: 13,
                              color: isSelected
                                  ? colorScheme.onPrimaryContainer
                                  : isCurrentDay
                                  ? colorScheme.onSecondaryContainer
                                  : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          // Subtle event indicators (maximum 3 dots)
                          if (events.isNotEmpty)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: events.take(3).map((ev) {
                                return Container(
                                  width: 4.5,
                                  height: 4.5,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ev.color,
                                    shape: BoxShape.circle,
                                  ),
                                );
                              }).toList(),
                            )
                          else
                            const SizedBox(height: 4.5),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 16),
            // Today jump action button
            BouncyPressable(
              scaleDownFactor: 0.93,
              onTap: () {
                ref.read(customSelectedDayProvider.notifier).state = null;
                ref.read(selectedEventProvider.notifier).state = null;
                Navigator.of(context).pop();
              },
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.today_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppStrings.jumpToToday,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: colorScheme.primary,
                      ),
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
