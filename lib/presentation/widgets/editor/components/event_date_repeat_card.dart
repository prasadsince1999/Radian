import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/bouncy_pressable.dart';

/// Interactive Date & Repeat Card for EventEditModal (Dual Date Tiles, Unlimited End Date, 7-Day Weekday Bubbles).
class EventDateRepeatCard extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final bool isUnlimitedEndDate;
  final Set<int> selectedWeeklyDays;
  final Color currentColor;
  final Color cardBg;
  final Color cardBorder;
  final void Function(bool isStart) onPickDate;
  final VoidCallback onToggleUnlimited;
  final ValueChanged<int> onToggleWeekday;

  const EventDateRepeatCard({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.isUnlimitedEndDate,
    required this.selectedWeeklyDays,
    required this.currentColor,
    required this.cardBg,
    required this.cardBorder,
    required this.onPickDate,
    required this.onToggleUnlimited,
    required this.onToggleWeekday,
  });

  static const _weekdays = <(String, String, int)>[
    ('M', 'Mon', 1),
    ('T', 'Tue', 2),
    ('W', 'Wed', 3),
    ('T', 'Thu', 4),
    ('F', 'Fri', 5),
    ('S', 'Sat', 6),
    ('S', 'Sun', 7),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Date & Repeat + Unlimited toggle
          Row(
            children: [
              Icon(Icons.calendar_month_rounded, size: 18, color: currentColor),
              const SizedBox(width: 8),
              Text(
                'Date & Repeat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _buildUnlimitedDatePill(colorScheme, currentColor),
            ],
          ),
          const SizedBox(height: 12),
          // Dual Date Tiles
          Row(
            children: [
              Expanded(
                child: BouncyPressable(
                  key: const ValueKey('start_date_tile'),
                  scaleDownFactor: 0.96,
                  onTap: () => onPickDate(true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'START DATE',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            DateFormat('EEE, d MMM').format(startDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: BouncyPressable(
                  key: const ValueKey('end_date_tile'),
                  scaleDownFactor: 0.96,
                  onTap: () => onPickDate(false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UNTIL',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            isUnlimitedEndDate
                                ? 'Unlimited'
                                : DateFormat('EEE, d MMM').format(endDate),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isUnlimitedEndDate
                                  ? currentColor
                                  : colorScheme.onSurface,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Repeat row: Repeat label + 7 Calendar Day bubbles
          Row(
            children: [
              Text(
                'Repeat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: _weekdays.map((item) {
                    final letter = item.$1;
                    final fullName = item.$2;
                    final day = item.$3;
                    final isSelected = selectedWeeklyDays.contains(day);
                    return Tooltip(
                      message: fullName,
                      child: BouncyPressable(
                        scaleDownFactor: 0.90,
                        onTap: () => onToggleWeekday(day),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? currentColor.withValues(alpha: 0.25)
                                : colorScheme.surfaceContainerHigh,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? currentColor
                                  : colorScheme.outlineVariant,
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                color: isSelected
                                    ? currentColor
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnlimitedDatePill(ColorScheme colorScheme, Color currentColor) {
    return BouncyPressable(
      key: const ValueKey('unlimited_date_toggle'),
      scaleDownFactor: 0.94,
      onTap: onToggleUnlimited,
      child: Tooltip(
        message: isUnlimitedEndDate
            ? 'Unlimited end date (active)'
            : 'Set unlimited end date',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
          decoration: BoxDecoration(
            color: isUnlimitedEndDate
                ? currentColor.withValues(alpha: 0.22)
                : colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isUnlimitedEndDate
                  ? currentColor
                  : colorScheme.outlineVariant,
              width: 1.0,
            ),
          ),
          child: Text(
            '∞',
            style: TextStyle(
              fontSize: 15,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: isUnlimitedEndDate
                  ? currentColor
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
