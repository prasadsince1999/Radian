import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/models/subtask_item.dart';
import '../../controllers/clock_controller.dart';

class CenterSummary extends ConsumerWidget {
  final DateTime currentTime;
  final SectorEvent? activeEvent;
  final SectorEvent? selectedEvent;
  final bool is24HourMode;
  final VoidCallback? onDismissSelected;

  const CenterSummary({
    super.key,
    required this.currentTime,
    required this.activeEvent,
    required this.selectedEvent,
    required this.is24HourMode,
    this.onDismissSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(dialSettingsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: selectedEvent != null
          ? _buildSelectedEventView(context, colorScheme, theme)
          : _buildClockSummaryView(context, ref, settings),
    );
  }

  Widget _buildSelectedEventView(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final ev = selectedEvent!;
    final isActive = ev.isCurrentlyActive(currentTime);
    final remainingMinutes = ev.end.difference(currentTime).inMinutes;
    final String statusLabel;
    if (isActive) {
      statusLabel = remainingMinutes > 0
          ? 'REMAINING ${remainingMinutes}m'
          : 'ENDING NOW';
    } else if (currentTime.isBefore(ev.start)) {
      final diff = ev.start.difference(currentTime);
      if (diff.inHours > 0) {
        statusLabel = 'STARTS IN ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        statusLabel = 'STARTS IN ${diff.inMinutes}m';
      }
    } else {
      final ago = currentTime.difference(ev.end);
      if (ago.inMinutes < 60) {
        statusLabel = 'ENDED ${ago.inMinutes}m AGO';
      } else {
        statusLabel = 'COMPLETED';
      }
    }

    return Center(
      key: ValueKey('event_${ev.id}'),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ev.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ev.color.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ev.color,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 110),
                child: Text(
                  ev.title.replaceAll('+', ' + ').replaceAll('-', ' - '),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    fontSize: 12,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${TimeFormatters.formatTime(ev.start, is24Hour: is24HourMode)} – ${TimeFormatters.formatTime(ev.end, is24Hour: is24HourMode)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockSummaryView(
    BuildContext context,
    WidgetRef ref,
    DialSettings settings,
  ) {
    return switch (settings.centerClockDisplay) {
      CenterClockDisplay.digital => _buildDigitalView(context, settings),
      CenterClockDisplay.analog => _buildAnalogView(context, settings),
      CenterClockDisplay.dateTime => _buildDateTimeView(context, settings),
      CenterClockDisplay.countdown => _buildCountdownView(
        context,
        ref,
        settings,
      ),
      CenterClockDisplay.dobAge => _buildDobAgeView(context, settings),
      CenterClockDisplay.currentSubtask => _buildCurrentSubtaskView(
        context,
        ref,
        settings,
      ),
    };
  }

  // 1. Digital Clock (Clean & Bold)
  Widget _buildDigitalView(BuildContext context, DialSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: const ValueKey('center_digital_clock'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!is24HourMode)
                Text(
                  currentTime.hour < 12 ? 'AM' : 'PM',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                    letterSpacing: 0.8,
                    height: 1.0,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                DateFormat(is24HourMode ? 'HH:mm' : 'h:mm').format(currentTime),
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                  height: 1.0,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                DateFormat('EEE, d MMM').format(currentTime),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12.0,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 2. Analog Clock (Watchmaker Hands & Ticks)
  Widget _buildAnalogView(BuildContext context, DialSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: const ValueKey('center_analog_clock'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          return SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _MiniAnalogClockPainter(
                time: currentTime,
                primaryColor: colorScheme.primary,
                handColor: colorScheme.onSurface,
                tickColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
              ),
            ),
          );
        },
      ),
    );
  }

  // 3. Date & Time (Rich Day/Date prominent + Time snippet)
  Widget _buildDateTimeView(BuildContext context, DialSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      key: const ValueKey('center_date_time'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  DateFormat('EEEE').format(currentTime).toUpperCase(),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.0,
                    color: colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('d MMMM').format(currentTime),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.3,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(is24HourMode ? 'HH:mm' : 'h:mm a')
                        .format(currentTime),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 4. Countdown (Countdown remaining in active block or until next block)
  Widget _buildCountdownView(
    BuildContext context,
    WidgetRef ref,
    DialSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dayEvents = ref.watch(dayEventsProvider).value ?? const [];

    if (activeEvent != null) {
      final remMinutes = activeEvent!.end.difference(currentTime).inMinutes;
      final hours = remMinutes ~/ 60;
      final mins = remMinutes % 60;
      final remStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';

      return Center(
        key: ValueKey('center_countdown_active_${activeEvent!.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: activeEvent!.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: activeEvent!.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: activeEvent!.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  remStr,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  'until ${TimeFormatters.formatTime(activeEvent!.end, is24Hour: is24HourMode)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Find next upcoming block
    final upcoming =
        dayEvents.where((e) => e.start.isAfter(currentTime)).toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    if (upcoming.isNotEmpty) {
      final next = upcoming.first;
      final diff = next.start.difference(currentTime);
      final h = diff.inHours;
      final m = diff.inMinutes % 60;
      final diffStr = h > 0 ? '${h}h ${m}m' : '${m}m';

      return Center(
        key: ValueKey('center_countdown_next_${next.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'NEXT IN $diffStr',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 100),
                  child: Text(
                    next.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  '@ ${TimeFormatters.formatTime(next.start, is24Hour: is24HourMode)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Day clear
    return Center(
      key: const ValueKey('center_countdown_empty'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 24,
                color: Colors.green,
              ),
              const SizedBox(height: 3),
              Text(
                'Dial Clear',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                'No upcoming blocks',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 5. Age & Life Progress (According to Date of Birth)
  Widget _buildDobAgeView(BuildContext context, DialSettings settings) {
    final colorScheme = Theme.of(context).colorScheme;
    final dob = settings.dateOfBirth ?? DateTime(2000, 1, 1);

    final totalDays = currentTime.difference(dob).inDays;
    int years = currentTime.year - dob.year;
    if (currentTime.month < dob.month ||
        (currentTime.month == dob.month && currentTime.day < dob.day)) {
      years--;
    }
    final months = (currentTime.month - dob.month + 12) % 12;

    return Center(
      key: const ValueKey('center_dob_age'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_top_rounded,
                    size: 12,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'LIFE CLOCK',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: colorScheme.primary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${years}y ${months}m',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Day ${NumberFormat.decimalPattern().format(totalDays)}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 6. Current Subtask (Active subtask inside current macro block)
  Widget _buildCurrentSubtaskView(
    BuildContext context,
    WidgetRef ref,
    DialSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    SubtaskItem? activeSubtask;
    if (activeEvent != null && activeEvent!.subtaskItems.isNotEmpty) {
      final curMinutes = currentTime.hour * 60 + currentTime.minute;
      for (final s in activeEvent!.subtaskItems) {
        if (s.startTime != null && s.endTime != null) {
          final sStart = s.startTime!.hour * 60 + s.startTime!.minute;
          final sEnd = s.endTime!.hour * 60 + s.endTime!.minute;
          if (curMinutes >= sStart && curMinutes < sEnd) {
            activeSubtask = s;
            break;
          }
        }
      }
      activeSubtask ??= activeEvent!.subtaskItems
          .where((s) => !s.isCompleted)
          .firstOrNull;
    }

    if (activeSubtask != null) {
      return Center(
        key: ValueKey('center_subtask_${activeSubtask.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: activeEvent!.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.checklist_rounded,
                        size: 11,
                        color: activeEvent!.color,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'SUBTASK',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: activeEvent!.color,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 105),
                  child: Text(
                    activeSubtask.title,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      height: 1.15,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activeSubtask.startTime != null &&
                          activeSubtask.endTime != null
                      ? '${TimeFormatters.formatTimeOfDay(activeSubtask.startTime!, is24Hour: is24HourMode)} – ${TimeFormatters.formatTimeOfDay(activeSubtask.endTime!, is24Hour: is24HourMode)}'
                      : activeEvent!.title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      key: const ValueKey('center_subtask_none'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 22,
                color: colorScheme.outlineVariant,
              ),
              const SizedBox(height: 3),
              Text(
                activeEvent != null ? 'No Subtasks' : 'No Active Block',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                activeEvent != null ? activeEvent!.title : 'Schedule subtasks',
                style: TextStyle(
                  fontSize: 10,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniAnalogClockPainter extends CustomPainter {
  final DateTime time;
  final Color primaryColor;
  final Color handColor;
  final Color tickColor;

  _MiniAnalogClockPainter({
    required this.time,
    required this.primaryColor,
    required this.handColor,
    required this.tickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.88;

    // Dial background
    final bgPaint = Paint()..color = Colors.black12;
    canvas.drawCircle(center, radius, bgPaint);

    // 12 hour tick marks
    final tickPaint = Paint()
      ..color = tickColor
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 12; i++) {
      final angle = (i * 30) * math.pi / 180;
      final isCardinal = i % 3 == 0;
      final tickLen = isCardinal ? 5.5 : 3.0;
      tickPaint.strokeWidth = isCardinal ? 1.8 : 1.0;

      final p1 = Offset(
        center.dx + (radius - tickLen) * math.cos(angle - math.pi / 2),
        center.dy + (radius - tickLen) * math.sin(angle - math.pi / 2),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(angle - math.pi / 2),
        center.dy + radius * math.sin(angle - math.pi / 2),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    // Hour Hand
    final hourAngle =
        ((time.hour % 12) + time.minute / 60.0) * (2 * math.pi / 12) -
        math.pi / 2;
    final hourLen = radius * 0.48;
    final hourPaint = Paint()
      ..color = handColor
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + hourLen * math.cos(hourAngle),
        center.dy + hourLen * math.sin(hourAngle),
      ),
      hourPaint,
    );

    // Minute Hand
    final minAngle =
        (time.minute + time.second / 60.0) * (2 * math.pi / 60) - math.pi / 2;
    final minLen = radius * 0.72;
    final minPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      Offset(
        center.dx + minLen * math.cos(minAngle),
        center.dy + minLen * math.sin(minAngle),
      ),
      minPaint,
    );

    // Center Pinion Dot
    final centerPaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, 2.5, centerPaint);
    canvas.drawCircle(center, 1.0, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniAnalogClockPainter old) =>
      old.time.minute != time.minute || old.time.second != time.second;
}
