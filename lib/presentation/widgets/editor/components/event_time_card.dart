import 'package:flutter/material.dart';

import '../../common/bouncy_pressable.dart';

/// Interactive Time Card for EventEditModal (Dual Time Tiles, All Day toggle, Duration Slider).
class EventTimeCard extends StatelessWidget {
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isAllDay;
  final int durationMinutes;
  final String durationLabel;
  final Color currentColor;
  final Color cardBg;
  final Color cardBorder;
  final void Function(bool isStart) onPickTime;
  final VoidCallback onToggleAllDay;
  final ValueChanged<int> onDurationChanged;

  const EventTimeCard({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.isAllDay,
    required this.durationMinutes,
    required this.durationLabel,
    required this.currentColor,
    required this.cardBg,
    required this.cardBorder,
    required this.onPickTime,
    required this.onToggleAllDay,
    required this.onDurationChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isOvernight =
        endTime.hour * 60 + endTime.minute <=
        startTime.hour * 60 + startTime.minute;

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
          // Header: Time + All day toggle
          Row(
            children: [
              Icon(
                Icons.access_time_filled_rounded,
                size: 18,
                color: currentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              _buildAllDayPill(colorScheme, currentColor),
            ],
          ),
          if (isAllDay) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.wb_sunny_rounded, size: 18, color: currentColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All-day Block',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: currentColor,
                          ),
                        ),
                        Text(
                          'Takes full 24-hour dial background',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            // Dual Time Tiles
            Row(
              children: [
                Expanded(
                  child: BouncyPressable(
                    key: const ValueKey('start_time_tile'),
                    scaleDownFactor: 0.96,
                    onTap: () => onPickTime(true),
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
                            'START',
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
                              startTime.format(context),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.3,
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
                    key: const ValueKey('end_time_tile'),
                    scaleDownFactor: 0.96,
                    onTap: () => onPickTime(false),
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
                          Row(
                            children: [
                              Text(
                                'END',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: colorScheme.onSurfaceVariant,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (isOvernight) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: colorScheme.tertiary.withValues(
                                        alpha: 0.5,
                                      ),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '+1d',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onTertiaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              endTime.format(context),
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onSurface,
                                letterSpacing: -0.3,
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
            // Duration Slider + Badge
            Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 18, color: currentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: currentColor,
                      inactiveTrackColor: colorScheme.surfaceContainerHighest,
                      thumbColor: currentColor,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 7,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 14,
                      ),
                      trackHeight: 4.0,
                    ),
                    child: Slider(
                      value: (durationMinutes.clamp(15, 240)).toDouble(),
                      min: 15,
                      max: 240,
                      divisions: 15,
                      onChanged: (val) => onDurationChanged(val.round()),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    durationLabel,
                    style: TextStyle(
                      color:
                          ThemeData.estimateBrightnessForColor(currentColor) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAllDayPill(ColorScheme colorScheme, Color currentColor) {
    return BouncyPressable(
      key: const ValueKey('all_day_toggle'),
      scaleDownFactor: 0.94,
      onTap: onToggleAllDay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isAllDay
              ? currentColor.withValues(alpha: 0.22)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isAllDay ? currentColor : colorScheme.outlineVariant,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.all_inclusive_rounded,
              size: 13,
              color: isAllDay ? currentColor : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 5),
            Text(
              'All day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isAllDay ? FontWeight.w800 : FontWeight.w600,
                color: isAllDay ? currentColor : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
