import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/geometry/concentric_solver.dart';
import '../../../core/geometry/fisheye_time_lens.dart';
import '../../../core/geometry/focused_block_layout_resolver.dart';
import '../../../core/geometry/polar_hit_test.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';
import 'center_summary.dart';
import 'sectograph_painter.dart';

class SectographDial extends ConsumerWidget {
  const SectographDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final allEventsAsync = ref.watch(allEventsProvider);
    final selectedEvent = ref.watch(selectedEventProvider);
    final activeEvent = ref.watch(currentActiveEventProvider);
    final currentTime = ref.watch(currentTimeProvider).value ?? DateTime.now();
    final scrubAngle = ref.watch(dialScrubAngleProvider);
    final settings = ref.watch(dialSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final today = DateTime(
      currentTime.year,
      currentTime.month,
      currentTime.day,
    );
    final viewingDay = DateTime(
      selectedDay.year,
      selectedDay.month,
      selectedDay.day,
    );
    final isToday = viewingDay == today;
    final isScrubbed = scrubAngle != null;
    final isNotNow = !isToday || isScrubbed || selectedEvent != null;

    final diffDays = viewingDay.difference(today).inDays;
    String? relativeLabel;
    if (diffDays == -1) {
      relativeLabel = 'YESTERDAY';
    } else if (diffDays < -1) {
      relativeLabel = '${-diffDays} DAYS AGO';
    } else if (diffDays == 1) {
      relativeLabel = 'TOMORROW';
    } else if (diffDays > 1) {
      relativeLabel = 'IN $diffDays DAYS';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hasFiniteHeight = constraints.maxHeight.isFinite;
        final hasFiniteWidth = constraints.maxWidth.isFinite;
        final fallbackDimension = hasFiniteWidth
            ? constraints.maxWidth
            : (hasFiniteHeight ? constraints.maxHeight : 320.0);
        final availableDialHeight = hasFiniteHeight
            ? math.max(
                100.0,
                constraints.maxHeight - AppLayoutConstants.dialSizeHeadroom,
              )
            : fallbackDimension;
        final availableDialWidth = hasFiniteWidth
            ? constraints.maxWidth
            : availableDialHeight;
        final dialSize = math.min(availableDialWidth, availableDialHeight);
        final center = Offset(dialSize / 2, dialSize / 2);
        final maxRadius = dialSize / 2 * 0.985;
        const scallopAmp = AppLayoutConstants.scallopAmp;
        final baseRadius = maxRadius - scallopAmp;
        final innerRadius = baseRadius * AppLayoutConstants.innerRadiusRatio;

        final dialStack = Center(
          child: SizedBox(
            width: dialSize,
            height: dialSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Dial Canvas & Hub
                allEventsAsync.when(
                  data: (allEvents) {
                    List<SectorEvent> computedEvents;
                    DateTime refTime = currentTime;

                    if (settings.is24HourMode) {
                      final startOfDay = DateTime(
                        viewingDay.year,
                        viewingDay.month,
                        viewingDay.day,
                      );
                      final endOfDay = DateTime(
                        startOfDay.year,
                        startOfDay.month,
                        startOfDay.day + 1,
                      );
                      final dayEvents = allEvents
                          .where(
                            (e) =>
                                e.start.isBefore(endOfDay) &&
                                e.end.isAfter(startOfDay),
                          )
                          .toList();
                      final withAngles = dayEvents
                          .map((e) => e.withComputedAngles(is24HourMode: true))
                          .toList();
                      final solved = ConcentricSolver.solve(withAngles);
                      computedEvents = withAngles.map((e) {
                        final levels = solved[e];
                        if (levels != null) {
                          return e.copyWith(
                            topLevel: levels.topLevel,
                            bottomLevel: levels.bottomLevel,
                          );
                        }
                        return e;
                      }).toList();
                    } else {
                      // 12-Hour Mode:
                      // Determine current or scrubbed reference time
                      if (scrubAngle != null) {
                        final currentAngle = SectorMath.timeToDialAngle(
                          currentTime,
                          is24HourMode: false,
                        );
                        var diff = scrubAngle - currentAngle;
                        if (diff > 180.0) diff -= 360.0;
                        if (diff < -180.0) diff += 360.0;
                        final deltaMinutes =
                            (diff / SectorMath.degreesPerMinute12H).round();
                        refTime = currentTime.add(
                          Duration(minutes: deltaMinutes),
                        );
                      }

                      // Dynamic rolling 12-hour horizon around refTime:
                      // In 12H mode, events within 12 hours of refTime are displayed.
                      // Revealing and hiding (PastHoursStyle) dynamically manages visibility.
                      final rawEvents = <SectorEvent>[];
                      for (final e in allEvents) {
                        // Skip events that are more than 12 hours ahead in 12H mode
                        if (e.start.difference(refTime).inMinutes >= 720) {
                          continue;
                        }
                        // Skip events that completed more than 12 hours ago
                        if (refTime.difference(e.end).inMinutes >= 720) {
                          continue;
                        }

                        final duration = e.end.difference(e.start);
                        if (duration.inMinutes > 0) {
                          final startAngle = SectorMath.timeToDialAngle(
                            e.start,
                            is24HourMode: false,
                          );
                          final sweepAngle = SectorMath.durationToSweepAngle(
                            duration,
                            is24HourMode: false,
                          );

                          rawEvents.add(
                            e.copyWith(
                              topLevel: 0,
                              bottomLevel: 1000,
                              startAngle: startAngle,
                              sweepAngle: sweepAngle,
                            ),
                          );
                        }
                      }

                      final solved = ConcentricSolver.solve(rawEvents);
                      computedEvents = rawEvents.map((e) {
                        final levels = solved[e];
                        if (levels != null) {
                          return e.copyWith(
                            topLevel: levels.topLevel,
                            bottomLevel: levels.bottomLevel,
                          );
                        }
                        return e;
                      }).toList();
                    }

                    // Compute effective time and effective active event for digital readout
                    final effectiveTime = scrubAngle != null
                        ? refTime
                        : currentTime;
                    SectorEvent? effectiveActive = activeEvent;
                    if (scrubAngle != null) {
                      for (final e in computedEvents) {
                        if (e.start.isBefore(effectiveTime) &&
                            e.end.isAfter(effectiveTime)) {
                          effectiveActive = e;
                          break;
                        }
                      }
                    }

                    final routineTrackIn =
                        innerRadius +
                        AppLayoutConstants.routineTrackInnerOffset;
                    final routineTrackOut =
                        baseRadius - AppLayoutConstants.routineTrackOuterMargin;

                    final isFocusedBlockMode =
                        settings.pastHoursStyle == PastHoursStyle.focusedBlock;
                    final FocusedHorizonResult? horizonResult =
                        isFocusedBlockMode
                        ? FocusedBlockLayoutResolver.resolve(
                            events: computedEvents,
                            effectiveTime: effectiveTime,
                            selectedEvent: selectedEvent,
                            is24HourMode: settings.is24HourMode,
                          )
                        : null;
                    final baseDisplayEvents = horizonResult != null
                        ? horizonResult.visibleEvents
                        : computedEvents;
                    if (horizonResult?.activeEvent != null) {
                      effectiveActive = horizonResult!.activeEvent;
                    }

                    // Fisheye Time Lens focus center
                    final double focusAngle;
                    if (effectiveActive != null) {
                      final halfDuration = Duration(
                        minutes: effectiveActive.duration.inMinutes ~/ 2,
                      );
                      focusAngle = SectorMath.timeToDialAngle(
                        effectiveActive.start.add(halfDuration),
                        is24HourMode: settings.is24HourMode,
                      );
                    } else {
                      focusAngle = SectorMath.timeToDialAngle(
                        effectiveTime,
                        is24HourMode: settings.is24HourMode,
                      );
                    }

                    final lens = settings.isFocusLensEnabled
                        ? FisheyeTimeLens(
                            focusAngle: focusAngle,
                            magnification: settings.lensMagnification,
                          )
                        : const FisheyeTimeLens.linear();

                    // Warp sector bounds so active block expands and surrounding blocks squeeze
                    final displayEvents = baseDisplayEvents.map((e) {
                      final warped = lens.warpSector(
                        startDeg: e.startAngle,
                        sweepDeg: e.sweepAngle,
                      );
                      return e.copyWith(
                        startAngle: warped.startDeg,
                        sweepAngle: warped.sweepDeg,
                      );
                    }).toList();

                    return GestureDetector(
                      onTapUp: (details) {
                        final dist = (details.localPosition - center).distance;
                        if (dist <= innerRadius) {
                          if (selectedEvent != null) {
                            ref.read(selectedEventProvider.notifier).state =
                                null;
                          } else {
                            ref
                                .read(dialSettingsProvider.notifier)
                                .cycleCenterClockDisplay();
                          }
                          return;
                        }
                        final screenAngle = SectorMath.touchDeltaToDialAngle(
                          details.localPosition.dx - center.dx,
                          details.localPosition.dy - center.dy,
                        );
                        final tapped =
                            PolarHitTest.findTappedSector<SectorEvent>(
                              localOffset: details.localPosition,
                              center: center,
                              innerRadius: routineTrackIn,
                              outerRadius: routineTrackOut,
                              sectors: displayEvents,
                              angleOverride: screenAngle,
                            );
                        ref.read(selectedEventProvider.notifier).state = tapped;
                      },
                      onPanStart: (details) {
                        final screenAngle = SectorMath.touchDeltaToDialAngle(
                          details.localPosition.dx - center.dx,
                          details.localPosition.dy - center.dy,
                        );
                        ref.read(dialScrubAngleProvider.notifier).state =
                            screenAngle;
                      },
                      onPanUpdate: (details) {
                        final screenAngle = SectorMath.touchDeltaToDialAngle(
                          details.localPosition.dx - center.dx,
                          details.localPosition.dy - center.dy,
                        );
                        ref.read(dialScrubAngleProvider.notifier).state =
                            screenAngle;
                      },
                      onPanEnd: (_) {
                        ref.read(dialScrubAngleProvider.notifier).state = null;
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(dialSize, dialSize),
                            painter: SectographPainter(
                              events: displayEvents,
                              selectedEvent: selectedEvent,
                              activeEvent: effectiveActive,
                              currentTime: effectiveTime,
                              scrubAngle: scrubAngle,
                              settings: settings,
                              colorScheme: colorScheme,
                              lens: lens,
                            ),
                          ),
                          ClipOval(
                            child: SizedBox(
                              width: innerRadius * 2 * 0.94,
                              height: innerRadius * 2 * 0.94,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth: innerRadius * 1.36,
                                    maxHeight: innerRadius * 1.36,
                                  ),
                                  child: CenterSummary(
                                    currentTime: effectiveTime,
                                    activeEvent: effectiveActive,
                                    selectedEvent: selectedEvent,
                                    is24HourMode: settings.is24HourMode,
                                    onDismissSelected: () {
                                      ref
                                              .read(
                                                selectedEventProvider.notifier,
                                              )
                                              .state =
                                          null;
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                ),
              ],
            ),
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasFiniteHeight) Expanded(child: dialStack) else dialStack,
            // Relative Date Info Tag displayed directly below the clock dial
            if (relativeLabel != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 3.5,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.95,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.45),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  relativeLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 10.5,
                    letterSpacing: 0.8,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Dedicated Connected Footer Control Bar (media_1788806983137.png)
            _DialFooterControlBar(
              settings: settings,
              viewingDay: viewingDay,
              isToday: isToday,
              currentTime: currentTime,
              isNotNow: isNotNow,
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

class _DialFooterControlBar extends ConsumerWidget {
  final DialSettings settings;
  final DateTime viewingDay;
  final bool isToday;
  final DateTime currentTime;
  final bool isNotNow;

  const _DialFooterControlBar({
    required this.settings,
    required this.viewingDay,
    required this.isToday,
    required this.currentTime,
    required this.isNotNow,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final buttonBg = colorScheme.surfaceContainerHigh;
    final buttonBorder = colorScheme.outlineVariant;
    final primaryTextColor = colorScheme.onSurface;

    final dateHeading = isToday
        ? 'Today, ${DateFormat('EEE, MMM d').format(viewingDay)}'
        : DateFormat('EEE, MMM d').format(viewingDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Left: Single Unified 12H / 24H Mode Pill (Toggles between 12H and 24H)
              BouncyPressable.standard(
                onTap: () {
                  ref.read(dialSettingsProvider.notifier).toggle24HourMode();
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: settings.is24HourMode
                        ? colorScheme.primaryContainer
                        : buttonBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: settings.is24HourMode
                          ? colorScheme.primary.withValues(alpha: 0.35)
                          : buttonBorder,
                      width: 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    settings.is24HourMode ? '24H' : '12H',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: settings.is24HourMode
                          ? colorScheme.onPrimaryContainer
                          : primaryTextColor,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Center: [ < ] Today, Mon, Sep 7 [ > ]
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Squircle Chevron Left
                  BouncyPressable.standard(
                    onTap: () {
                      ref
                          .read(customSelectedDayProvider.notifier)
                          .state = DateTime(
                        viewingDay.year,
                        viewingDay.month,
                        viewingDay.day - 1,
                        viewingDay.hour,
                        viewingDay.minute,
                      );
                      ref.read(selectedEventProvider.notifier).state = null;
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: buttonBorder, width: 1.2),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    dateHeading,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                      color: primaryTextColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Squircle Chevron Right
                  BouncyPressable.standard(
                    onTap: () {
                      ref
                          .read(customSelectedDayProvider.notifier)
                          .state = DateTime(
                        viewingDay.year,
                        viewingDay.month,
                        viewingDay.day + 1,
                        viewingDay.hour,
                        viewingDay.minute,
                      );
                      ref.read(selectedEventProvider.notifier).state = null;
                    },
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: buttonBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: buttonBorder, width: 1.2),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // 3. Right: ( 🔄 Now )
              BouncyPressable.standard(
                onTap: () {
                  ref.read(dialScrubAngleProvider.notifier).state = null;
                  ref.read(customSelectedDayProvider.notifier).state = null;
                  ref.read(selectedEventProvider.notifier).state = null;
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: isNotNow ? colorScheme.primaryContainer : buttonBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isNotNow ? colorScheme.primary : buttonBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.restart_alt_rounded,
                        size: 15,
                        color: isNotNow
                            ? colorScheme.primary
                            : primaryTextColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.now,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          color: isNotNow
                              ? colorScheme.primary
                              : primaryTextColor,
                        ),
                      ),
                    ],
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
