import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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
                      // In 12-hour mode (both watch mode and circle edit mode), enforce the 12-hour rolling horizon
                      // around refTime so AM and PM blocks never wrap and overlap on the 12H dial face.
                      final rawEvents = <SectorEvent>[];
                      final shouldShowAllDayBlocks = settings.is24HourMode;

                      for (final e in projectedDayEvents) {
                        if (e.isAllDay) continue;

                        if (!shouldShowAllDayBlocks) {
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
                                            final freeGaps =
                                                DialTimeCapDragHandler.findFreeGaps(
                                                  events: computedEvents,
                                                  day: viewingDay,
                                                );
                                            DateTime newStart;
                                            DateTime newEnd;
                                            if (freeGaps.isNotEmpty) {
                                              final firstGap = freeGaps.first;
                                              newStart = firstGap.$1;
                                              final gapMins = firstGap.$2
                                                  .difference(firstGap.$1)
                                                  .inMinutes;
                                              final dur = math.min(60, gapMins);
                                              newEnd = newStart.add(
                                                Duration(minutes: dur),
                                              );
                                            } else {
                                              newStart = DateTime(
                                                viewingDay.year,
                                                viewingDay.month,
                                                viewingDay.day,
                                                9,
                                                0,
                                              );
                                              newEnd = newStart.add(
                                                const Duration(hours: 1),
                                              );
                                            }
                                            final newEvent = SectorEvent(
                                              id: const Uuid().v4(),
                                              title: 'New Block',
                                              start: newStart,
                                              end: newEnd,
                                              colorHex: '#6366F1',
                                            );
                                            ref
                                                .read(eventRepositoryProvider)
                                                .addEvent(newEvent);
                                            ref
                                                    .read(
                                                      selectedEventProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                newEvent;
                                            ref
                                                .read(cloudSyncServiceProvider)
                                                .queueUpsert(newEvent);
                                            ref
                                                .read(
                                                  cloudSyncControllerProvider
                                                      .notifier,
                                                )
                                                .syncNow();

                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              showDragHandle: false,
                                              backgroundColor:
                                                  Colors.transparent,
                                              builder: (_) => EventEditModal(
                                                event: newEvent,
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
    final isDialEditing = ref.watch(isDialEditingProvider);

    final buttonBg = colorScheme.surfaceContainerHigh;
    final buttonBorder = colorScheme.outlineVariant;
    final primaryTextColor = colorScheme.onSurface;

    final scrubAngle = ref.watch(dialScrubAngleProvider);
    final isNotNow = !isToday || scrubAngle != null;

    final dateHeading = isToday
        ? 'Today, ${DateFormat('EEE, MMM d').format(viewingDay)}'
        : DateFormat('EEE, MMM d').format(viewingDay);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: SizedBox(
        height: 36,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Left: [ 🔄 Now ] (Sync to current time & today)
            Positioned(
              left: 0,
              child: BouncyPressable.standard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(dialScrubAngleProvider.notifier).state = null;
                  ref.read(customSelectedDayProvider.notifier).state = null;
                  ref.read(selectedEventProvider.notifier).state = null;
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
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
            ),

            // 2. Center: [ < ] Today, Mon, Sep 7 [ > ]
            Center(
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
              ),
            ),

            // 3. Right: [ 🎛️ Edit ] / [ ✓ Done ] (Toggles dial block editing)
            Positioned(
              right: 0,
              child: BouncyPressable.standard(
                onTap: () {
                  final current = ref.read(isDialEditingProvider);
                  ref.read(isDialEditingProvider.notifier).state = !current;
                  HapticFeedback.mediumImpact();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOutCubic,
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: isDialEditing ? colorScheme.primary : buttonBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDialEditing ? colorScheme.primary : buttonBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDialEditing
                            ? Icons.check_rounded
                            : Icons.tune_rounded,
                        size: 15,
                        color: isDialEditing
                            ? colorScheme.onPrimary
                            : primaryTextColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isDialEditing ? 'Done' : 'Edit',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: 0.2,
                          color: isDialEditing
                              ? colorScheme.onPrimary
                              : primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
