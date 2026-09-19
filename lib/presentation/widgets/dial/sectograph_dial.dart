import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/geometry/dial_sector_layout_stretcher.dart';
import '../../../core/geometry/dial_time_cap_drag_handler.dart';
import '../../../core/geometry/fisheye_time_lens.dart';
import '../../../core/geometry/focused_block_layout_resolver.dart';
import '../../../core/geometry/polar_hit_test.dart';
import '../../../core/geometry/sector_math.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../../controllers/cloud_sync_controller.dart';
import '../common/bouncy_pressable.dart';
import '../editor/event_edit_modal.dart';
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
    final isDialEditing = ref.watch(isDialEditingProvider);
    final dialSegment = ref.watch(dial12HourSegmentProvider);
    final activeDraggingCap = ref.watch(activeDraggingCapProvider);
    final liveAdjustedEvent = ref.watch(liveAdjustedEventProvider);
    final liveAdjustedMap = ref.watch(liveAdjustedEventsMapProvider);
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
        final footerHeight =
            (settings.is24HourMode ? 0.0 : 34.0) +
            (relativeLabel != null ? 22.0 : 0.0) +
            44.0;
        final availableDialHeight = hasFiniteHeight
            ? math.max(100.0, constraints.maxHeight - footerHeight)
            : fallbackDimension;
        final availableDialWidth = hasFiniteWidth
            ? constraints.maxWidth
            : availableDialHeight;
        final dialSize = math.min(availableDialWidth, availableDialHeight);
        final center = Offset(dialSize / 2, dialSize / 2);
        final maxRadius = dialSize / 2 * 0.995;
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
                    final effectiveAllEvents = allEvents.map((e) {
                      if (liveAdjustedMap.containsKey(e.id)) {
                        return liveAdjustedMap[e.id]!;
                      }
                      if (liveAdjustedEvent != null &&
                          e.id == liveAdjustedEvent.id) {
                        return liveAdjustedEvent;
                      }
                      return e;
                    }).toList();

                    // 1. Project all raw events for viewingDay (including recurring and unlimited events)
                    final projectedDayEvents = <SectorEvent>[];
                    for (final e in effectiveAllEvents) {
                      if (e.repeatDays != null && e.repeatDays!.isNotEmpty) {
                        final startBoundary = DateTime(
                          e.start.year,
                          e.start.month,
                          e.start.day,
                        );
                        if (viewingDay.isBefore(startBoundary)) continue;
                        if (e.recurrenceEndDate != null) {
                          final endBoundary = DateTime(
                            e.recurrenceEndDate!.year,
                            e.recurrenceEndDate!.month,
                            e.recurrenceEndDate!.day,
                            23,
                            59,
                            59,
                          );
                          if (viewingDay.isAfter(endBoundary)) continue;
                        }
                        if (e.repeatDays!.contains(viewingDay.weekday)) {
                          final projStart = DateTime(
                            viewingDay.year,
                            viewingDay.month,
                            viewingDay.day,
                            e.start.hour,
                            e.start.minute,
                          );
                          projectedDayEvents.add(
                            e.copyWith(
                              start: projStart,
                              end: projStart.add(e.duration),
                            ),
                          );
                        }
                      } else if (e.recurrenceEndDate != null) {
                        final startBoundary = DateTime(
                          e.start.year,
                          e.start.month,
                          e.start.day,
                        );
                        final endBoundary = DateTime(
                          e.recurrenceEndDate!.year,
                          e.recurrenceEndDate!.month,
                          e.recurrenceEndDate!.day,
                          23,
                          59,
                          59,
                        );
                        if (!viewingDay.isBefore(startBoundary) &&
                            !viewingDay.isAfter(endBoundary)) {
                          final projStart = DateTime(
                            viewingDay.year,
                            viewingDay.month,
                            viewingDay.day,
                            e.start.hour,
                            e.start.minute,
                          );
                          projectedDayEvents.add(
                            e.copyWith(
                              start: projStart,
                              end: projStart.add(e.duration),
                            ),
                          );
                        }
                      } else {
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
                        if (e.start.isBefore(endOfDay) &&
                            e.end.isAfter(startOfDay)) {
                          projectedDayEvents.add(e);
                        }
                      }
                    }

                    List<SectorEvent> computedEvents;
                    DateTime refTime = isToday
                        ? currentTime
                        : DateTime(
                            viewingDay.year,
                            viewingDay.month,
                            viewingDay.day,
                            currentTime.hour,
                            currentTime.minute,
                          );

                    if (settings.is24HourMode) {
                      final withAngles = projectedDayEvents
                          .where((e) => !e.isAllDay)
                          .map((e) => e.withComputedAngles(is24HourMode: true))
                          .toList();

                      // Deconflict directly overlapping events so conflicting blocks
                      // never render on top of each other on the circular dial.
                      withAngles.sort((a, b) {
                        if (selectedEvent != null) {
                          if (a.id == selectedEvent.id) return -1;
                          if (b.id == selectedEvent.id) return 1;
                        }
                        return a.start.compareTo(b.start);
                      });

                      final deconflicted = <SectorEvent>[];
                      for (final ev in withAngles) {
                        if (!deconflicted.any(
                          (existing) =>
                              ev.start.isBefore(existing.end) &&
                              existing.start.isBefore(ev.end),
                        )) {
                          deconflicted.add(ev);
                        }
                      }
                      computedEvents = deconflicted;
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
                        refTime = refTime.add(Duration(minutes: deltaMinutes));
                      }

                      // In 24-hour mode, all 24 hours are distributed around 360° with zero wrap collisions.
                      // In 12-hour mode:
                      // - When editing (isDialEditing): segmented into AM (00:00-12:00) and PM (12:00-24:00),
                      //   displaying all existing blocks for that segment with zero AM/PM visual collisions.
                      // - In normal watch mode: rolling 12-hour horizon around refTime.
                      final rawEvents = <SectorEvent>[];

                      if (isDialEditing) {
                        final isAm = dialSegment == Dial12HourSegment.am;
                        final segStart = DateTime(
                          viewingDay.year,
                          viewingDay.month,
                          viewingDay.day,
                          isAm ? 0 : 12,
                          0,
                        );
                        final segEnd = isAm
                            ? DateTime(
                                viewingDay.year,
                                viewingDay.month,
                                viewingDay.day,
                                12,
                                0,
                              )
                            : DateTime(
                                viewingDay.year,
                                viewingDay.month,
                                viewingDay.day + 1,
                                0,
                                0,
                              );

                        for (final e in projectedDayEvents) {
                          if (e.isAllDay) continue;

                          if (e.start.isBefore(segEnd) &&
                              e.end.isAfter(segStart)) {
                            final effStart = e.start.isBefore(segStart)
                                ? segStart
                                : e.start;
                            final effEnd = e.end.isAfter(segEnd)
                                ? segEnd
                                : e.end;
                            final duration = effEnd.difference(effStart);
                            if (duration.inMinutes > 0) {
                              final startAngle = SectorMath.timeToDialAngle(
                                effStart,
                                is24HourMode: false,
                              );
                              final sweepAngle =
                                  SectorMath.durationToSweepAngle(
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
                        }
                      } else {
                        for (final e in projectedDayEvents) {
                          if (e.isAllDay) continue;

                          // Skip events that completed more than 15 minutes before refTime (unless active)
                          if (e.end.isBefore(
                                refTime.subtract(const Duration(minutes: 15)),
                              ) &&
                              !(!refTime.isBefore(e.start) &&
                                  refTime.isBefore(e.end))) {
                            continue;
                          }
                          // Skip events that start 12 hours (720 min) or more ahead in 12H mode
                          if (e.start.difference(refTime).inMinutes >= 720) {
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
                      }

                      computedEvents = rawEvents;
                    }

                    // Compute effective time and effective active event for digital readout
                    final effectiveTime = scrubAngle != null
                        ? refTime
                        : (isToday
                              ? currentTime
                              : DateTime(
                                  viewingDay.year,
                                  viewingDay.month,
                                  viewingDay.day,
                                  currentTime.hour,
                                  currentTime.minute,
                                ));
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
                        !isDialEditing &&
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

                    // Fisheye Time Lens focus center: prioritize user-tapped block to expand it
                    final focusEvent = selectedEvent ?? effectiveActive;
                    final double focusAngle;
                    if (focusEvent != null) {
                      final halfDuration = Duration(
                        minutes: focusEvent.duration.inMinutes ~/ 2,
                      );
                      focusAngle = SectorMath.timeToDialAngle(
                        focusEvent.start.add(halfDuration),
                        is24HourMode: settings.is24HourMode,
                      );
                    } else {
                      focusAngle = SectorMath.timeToDialAngle(
                        effectiveTime,
                        is24HourMode: settings.is24HourMode,
                      );
                    }

                    // When a block is explicitly tapped/selected, provide punchy expansion magnification
                    final activeMagnification = selectedEvent != null
                        ? math.max(settings.lensMagnification, 1.85)
                        : settings.lensMagnification;

                    final lens = settings.isFocusLensEnabled
                        ? FisheyeTimeLens(
                            focusAngle: focusAngle,
                            magnification: activeMagnification,
                          )
                        : const FisheyeTimeLens.linear();

                    // Warp sector bounds so active block expands and surrounding blocks squeeze
                    final warpedEvents = baseDisplayEvents.map((e) {
                      final warped = lens.warpSector(
                        startDeg: e.startAngle,
                        sweepDeg: e.sweepAngle,
                      );
                      return e.copyWith(
                        startAngle: warped.startDeg,
                        sweepAngle: warped.sweepDeg,
                      );
                    }).toList();

                    // Naturally stretch compressed/tight sectors into adjacent gaps so content fits cleanly
                    final displayEvents = DialSectorLayoutStretcher.stretch(
                      warpedEvents,
                      is24HourMode: settings.is24HourMode,
                    );

                    SectorEvent? effectiveSelected = selectedEvent;
                    if (selectedEvent != null) {
                      for (final e in displayEvents) {
                        if (e.id == selectedEvent.id) {
                          effectiveSelected = e;
                          break;
                        }
                      }
                    }

                    return GestureDetector(
                      onPanDown: (details) {
                        if (!isDialEditing) return;
                        final hitTarget = DialTimeCapDragHandler.findHitTarget(
                          localOffset: details.localPosition,
                          center: center,
                          rIn: routineTrackIn,
                          rOut: routineTrackOut,
                          events: displayEvents,
                          is24HourMode: settings.is24HourMode,
                          selectedEvent: effectiveSelected,
                          isDialEditing: isDialEditing,
                        );
                        if (hitTarget != null) {
                          ref.read(activeDraggingCapProvider.notifier).state =
                              hitTarget;
                          ref.read(liveAdjustedEventProvider.notifier).state =
                              hitTarget.event;
                          ref.read(selectedEventProvider.notifier).state =
                              hitTarget.event;
                          HapticFeedback.selectionClick();
                        }
                      },
                      onPanStart: (details) {
                        var activeCap = ref.read(activeDraggingCapProvider);
                        if (isDialEditing && activeCap == null) {
                          final hitTarget =
                              DialTimeCapDragHandler.findHitTarget(
                                localOffset: details.localPosition,
                                center: center,
                                rIn: routineTrackIn,
                                rOut: routineTrackOut,
                                events: displayEvents,
                                is24HourMode: settings.is24HourMode,
                                selectedEvent: effectiveSelected,
                                isDialEditing: isDialEditing,
                              );
                          if (hitTarget != null) {
                            ref.read(activeDraggingCapProvider.notifier).state =
                                hitTarget;
                            ref.read(liveAdjustedEventProvider.notifier).state =
                                hitTarget.event;
                            ref.read(selectedEventProvider.notifier).state =
                                hitTarget.event;
                            HapticFeedback.selectionClick();
                            activeCap = hitTarget;
                          }
                        }
                        if (activeCap == null && !isDialEditing) {
                          final screenAngle = SectorMath.touchDeltaToDialAngle(
                            details.localPosition.dx - center.dx,
                            details.localPosition.dy - center.dy,
                          );
                          ref.read(dialScrubAngleProvider.notifier).state =
                              screenAngle;
                        }
                      },
                      onPanUpdate: (details) {
                        final activeCap = ref.read(activeDraggingCapProvider);
                        if (isDialEditing && activeCap != null) {
                          final touchAngle = SectorMath.touchDeltaToDialAngle(
                            details.localPosition.dx - center.dx,
                            details.localPosition.dy - center.dy,
                          );
                          final prevAdjusted = ref.read(
                            liveAdjustedEventProvider,
                          );
                          final adjResult =
                              DialTimeCapDragHandler.calculateLiveAdjustment(
                                hit: activeCap,
                                currentTouchAngle: touchAngle,
                                allDayEvents: allEvents,
                                is24HourMode: settings.is24HourMode,
                              );
                          if (prevAdjusted == null ||
                              prevAdjusted.start !=
                                  adjResult.updatedEvent.start ||
                              prevAdjusted.end != adjResult.updatedEvent.end) {
                            HapticFeedback.selectionClick();
                          }
                          ref.read(liveAdjustedEventProvider.notifier).state =
                              adjResult.updatedEvent;
                          ref
                                  .read(liveAdjustedEventsMapProvider.notifier)
                                  .state =
                              adjResult.allUpdatedEvents;
                        } else if (!isDialEditing) {
                          final screenAngle = SectorMath.touchDeltaToDialAngle(
                            details.localPosition.dx - center.dx,
                            details.localPosition.dy - center.dy,
                          );
                          ref.read(dialScrubAngleProvider.notifier).state =
                              screenAngle;
                        }
                      },
                      onPanEnd: (_) {
                        final activeCap = ref.read(activeDraggingCapProvider);
                        final liveAdjusted = ref.read(
                          liveAdjustedEventProvider,
                        );
                        final liveMap = ref.read(liveAdjustedEventsMapProvider);
                        if (isDialEditing && liveMap.isNotEmpty) {
                          for (final updated in liveMap.values) {
                            ref
                                .read(eventRepositoryProvider)
                                .updateEvent(updated);
                            ref
                                .read(cloudSyncServiceProvider)
                                .queueUpsert(updated);
                          }
                          if (liveAdjusted != null) {
                            ref.read(selectedEventProvider.notifier).state =
                                liveAdjusted;
                          }
                          ref
                              .read(cloudSyncControllerProvider.notifier)
                              .syncNow();
                          ref
                                  .read(
                                    hasModifiedDialPositionsProvider.notifier,
                                  )
                                  .state =
                              true;
                          HapticFeedback.mediumImpact();
                        } else if (isDialEditing &&
                            activeCap != null &&
                            liveAdjusted != null) {
                          ref
                              .read(eventRepositoryProvider)
                              .updateEvent(liveAdjusted);
                          ref.read(selectedEventProvider.notifier).state =
                              liveAdjusted;
                          ref
                              .read(cloudSyncServiceProvider)
                              .queueUpsert(liveAdjusted);
                          ref
                              .read(cloudSyncControllerProvider.notifier)
                              .syncNow();
                          ref
                                  .read(
                                    hasModifiedDialPositionsProvider.notifier,
                                  )
                                  .state =
                              true;
                          HapticFeedback.mediumImpact();
                        }
                        ref.read(activeDraggingCapProvider.notifier).state =
                            null;
                        ref.read(liveAdjustedEventProvider.notifier).state =
                            null;
                        ref.read(liveAdjustedEventsMapProvider.notifier).state =
                            const {};
                        ref.read(dialScrubAngleProvider.notifier).state = null;
                      },
                      onPanCancel: () {
                        ref.read(activeDraggingCapProvider.notifier).state =
                            null;
                        ref.read(liveAdjustedEventProvider.notifier).state =
                            null;
                        ref.read(liveAdjustedEventsMapProvider.notifier).state =
                            const {};
                        ref.read(dialScrubAngleProvider.notifier).state = null;
                      },
                      onTapUp: (details) {
                        final dist = (details.localPosition - center).distance;
                        if (dist <= innerRadius) {
                          if (isDialEditing) {
                            return;
                          }
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
                        if (tapped != null) {
                          HapticFeedback.lightImpact();
                          ref.read(selectedEventProvider.notifier).state =
                              tapped;

                          // Only clicking the center text title area opens the edit modal,
                          // tapping the broader surface selects/focuses the block without popping up modal.
                          final isTitleTap =
                              DialTimeCapDragHandler.isTitleTextHit(
                                localOffset: details.localPosition,
                                center: center,
                                rIn: routineTrackIn,
                                rOut: routineTrackOut,
                                event: tapped,
                                is24HourMode: settings.is24HourMode,
                              );

                          if (isTitleTap) {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: false,
                              backgroundColor: Colors.transparent,
                              builder: (_) => EventEditModal(
                                event: tapped,
                                initialDate: viewingDay,
                              ),
                            );
                          }
                        } else {
                          ref.read(selectedEventProvider.notifier).state = null;
                        }
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
                              activeDraggingCap: activeDraggingCap,
                              isDialEditing: isDialEditing,
                            ),
                          ),
                          ClipOval(
                            child: SizedBox(
                              width: innerRadius * 2 * 0.94,
                              height: innerRadius * 2 * 0.94,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: 0.88,
                                        end: 1.0,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                child: isDialEditing
                                    ? Center(
                                        key: const ValueKey(
                                          'dial_center_edit_btn',
                                        ),
                                        child: BouncyPressable(
                                          scaleDownFactor: 0.88,
                                          onTap: () {
                                            HapticFeedback.mediumImpact();
                                            final is24H = settings.is24HourMode;
                                            final maxAllowed = is24H
                                                ? AppLayoutConstants
                                                      .maxBlocks24H
                                                : AppLayoutConstants
                                                      .maxBlocks12H;
                                            if (projectedDayEvents.length >=
                                                maxAllowed) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Dial limit reached: maximum $maxAllowed blocks allowed in ${is24H ? "24H" : "12H"} mode to prevent dial clutter.',
                                                  ),
                                                  behavior:
                                                      SnackBarBehavior.floating,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              );
                                              return;
                                            }

                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              showDragHandle: false,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) => EventEditModal(
                                                event: null,
                                                initialDate: viewingDay,
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: math.min(
                                              52.0,
                                              innerRadius * 0.96,
                                            ),
                                            height: math.min(
                                              52.0,
                                              innerRadius * 0.96,
                                            ),
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colorScheme.primary
                                                      .withValues(alpha: 0.45),
                                                  blurRadius: 10,
                                                  spreadRadius: 2,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: Icon(
                                              Icons.add_rounded,
                                              size: 28,
                                              color: colorScheme.onPrimary,
                                            ),
                                          ),
                                        ),
                                      )
                                    : Center(
                                        key: const ValueKey(
                                          'dial_center_clock_summary',
                                        ),
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
                                                        selectedEventProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  null;
                                            },
                                          ),
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
            if (!settings.is24HourMode) ...[
              const SizedBox(height: 3),
              _Dial12HourSegmentPill(viewingDay: viewingDay),
            ],
            const SizedBox(height: 4),
            // Dedicated Connected Footer Control Bar (media_1788806983137.png)
            _DialFooterControlBar(
              settings: settings,
              viewingDay: viewingDay,
              isToday: isToday,
              currentTime: currentTime,
              isNotNow: isNotNow,
            ),
            const SizedBox(height: 2),
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
    final isDialEditing = ref.watch(isDialEditingProvider);
    final hasModified = ref.watch(hasModifiedDialPositionsProvider);

    final buttonBg = colorScheme.surfaceContainerHigh;
    final buttonBorder = colorScheme.outlineVariant;
    final primaryTextColor = colorScheme.onSurface;

    final scrubAngle = ref.watch(dialScrubAngleProvider);
    final isNotNow = !isToday || scrubAngle != null;

    final dateHeading = isToday
        ? 'Today, ${DateFormat('EEE, MMM d').format(viewingDay)}'
        : DateFormat('EEE, MMM d').format(viewingDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            // 1. Left: [ 🔄 Now ] (Sync to current time & today)
            BouncyPressable.standard(
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(dialScrubAngleProvider.notifier).state = null;
                ref.read(customSelectedDayProvider.notifier).state = null;
                ref.read(selectedEventProvider.notifier).state = null;
                ref
                    .read(dial12HourSegmentProvider.notifier)
                    .state = DateTime.now().hour < 12
                    ? Dial12HourSegment.am
                    : Dial12HourSegment.pm;
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
                      color: isNotNow ? colorScheme.primary : primaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      AppStrings.now,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: isNotNow
                            ? colorScheme.primary
                            : primaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 2. Center: [ < ] Today, Sat, Sep 19 [ > ]
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: buttonBorder, width: 1.2),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        dateHeading,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: primaryTextColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(width: 5),
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
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: buttonBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: buttonBorder, width: 1.2),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            // 3. Right: [ 🎛️ Edit ] / [ 💾 Save ]
            BouncyPressable.standard(
              onTap: () {
                if (isDialEditing) {
                  ref.read(selectedEventProvider.notifier).state = null;
                  final wasModified = ref.read(
                    hasModifiedDialPositionsProvider,
                  );
                  ref.read(hasModifiedDialPositionsProvider.notifier).state =
                      false;
                  ref.read(isDialEditingProvider.notifier).state = false;
                  HapticFeedback.mediumImpact();
                  if (wasModified) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Block positions saved',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  ref.read(selectedEventProvider.notifier).state = null;
                  ref.read(isDialEditingProvider.notifier).state = true;
                  ref.read(hasModifiedDialPositionsProvider.notifier).state =
                      false;
                  HapticFeedback.mediumImpact();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                height: 36,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDialEditing
                      ? (hasModified
                            ? const Color(0xFF10B981)
                            : colorScheme.primary)
                      : buttonBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDialEditing
                        ? (hasModified
                              ? const Color(0xFF10B981)
                              : colorScheme.primary)
                        : buttonBorder,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDialEditing ? Icons.save_rounded : Icons.tune_rounded,
                      size: 15,
                      color: isDialEditing ? Colors.white : primaryTextColor,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isDialEditing ? 'Save' : 'Edit',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.2,
                        color: isDialEditing ? Colors.white : primaryTextColor,
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

class _Dial12HourSegmentPill extends ConsumerWidget {
  final DateTime viewingDay;

  const _Dial12HourSegmentPill({required this.viewingDay});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeSegment = ref.watch(dial12HourSegmentProvider);
    final allEventsAsync = ref.watch(allEventsProvider);

    final events = allEventsAsync.value ?? const [];
    int amCount = 0;
    int pmCount = 0;
    final dayStart = DateTime(
      viewingDay.year,
      viewingDay.month,
      viewingDay.day,
      0,
      0,
    );
    final noon = DateTime(
      viewingDay.year,
      viewingDay.month,
      viewingDay.day,
      12,
      0,
    );
    final dayEnd = DateTime(
      viewingDay.year,
      viewingDay.month,
      viewingDay.day + 1,
      0,
      0,
    );

    for (final e in events) {
      if (e.isAllDay) continue;
      if (e.start.isBefore(noon) && e.end.isAfter(dayStart)) {
        amCount++;
      }
      if (e.start.isBefore(dayEnd) && e.end.isAfter(noon)) {
        pmCount++;
      }
    }

    final containerBg = colorScheme.surfaceContainerHigh;
    final outlineBorder = colorScheme.outlineVariant;

    return Center(
      child: Container(
        height: 30,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: outlineBorder, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSegmentOption(
              context: context,
              ref: ref,
              segment: Dial12HourSegment.am,
              isSelected: activeSegment == Dial12HourSegment.am,
              icon: Icons.wb_sunny_rounded,
              title: 'AM',
              count: amCount,
              colorScheme: colorScheme,
            ),
            const SizedBox(width: 4),
            _buildSegmentOption(
              context: context,
              ref: ref,
              segment: Dial12HourSegment.pm,
              isSelected: activeSegment == Dial12HourSegment.pm,
              icon: Icons.nightlight_round,
              title: 'PM',
              count: pmCount,
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentOption({
    required BuildContext context,
    required WidgetRef ref,
    required Dial12HourSegment segment,
    required bool isSelected,
    required IconData icon,
    required String title,
    required int count,
    required ColorScheme colorScheme,
  }) {
    final activeBg = colorScheme.primary;
    final activeFg = colorScheme.onPrimary;
    final inactiveFg = colorScheme.onSurfaceVariant;

    return BouncyPressable(
      scaleDownFactor: 0.92,
      onTap: () {
        HapticFeedback.selectionClick();
        ref.read(dial12HourSegmentProvider.notifier).state = segment;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? activeFg : inactiveFg),
            const SizedBox(width: 4),
            Text(
              '$title ($count)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? activeFg : inactiveFg,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
