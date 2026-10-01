import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/geometry/dial_time_cap_drag_handler.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/rules/block_budget.dart';
import '../../../domain/schedule/occurrence_adapter.dart';
import '../../../engine/dial_model.dart';
import '../../../engine/horizon_selector.dart';
import '../../controllers/clock_controller.dart';
import '../../controllers/dial_model_controller.dart';
import '../common/bouncy_pressable.dart';
import '../editor/event_edit_modal.dart';
import 'center_summary.dart';
import 'components/hidden_blocks_sheet.dart';
import 'dial_gesture_controller.dart';
import 'dial_painter.dart';

class SectographDial extends ConsumerWidget {
  const SectographDial({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final allEventsAsync = ref.watch(allEventsProvider);
    final selectedEvent = ref.watch(selectedEventProvider);
    final currentTime =
        ref.watch(currentTimeProvider).value ?? ref.read(clockProvider).now();
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
        final showSegmentPill = !settings.is24HourMode && isDialEditing;
        final footerHeight =
            (showSegmentPill ? 34.0 : 0.0) +
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
        final routineTrackIn =
            innerRadius + AppLayoutConstants.routineTrackInnerOffset;
        final routineTrackOut =
            baseRadius - AppLayoutConstants.routineTrackOuterMargin;

        final allEvents = allEventsAsync.value ?? const <SectorEvent>[];
        final effectiveAllEvents = allEvents.map((e) {
          if (liveAdjustedMap.containsKey(e.id)) {
            return liveAdjustedMap[e.id]!;
          }
          if (liveAdjustedEvent != null && e.id == liveAdjustedEvent.id) {
            return liveAdjustedEvent;
          }
          return e;
        }).toList();

        final dialStack = Center(
          child: SizedBox(
            width: dialSize,
            height: dialSize,
            child: _buildNewEngineDialStack(
              context: context,
              ref: ref,
              dialSize: dialSize,
              innerRadius: innerRadius,
              center: center,
              routineTrackIn: routineTrackIn,
              routineTrackOut: routineTrackOut,
              settings: settings,
              colorScheme: colorScheme,
              theme: theme,
              isDialEditing: isDialEditing,
              viewingDay: viewingDay,
              currentTime: currentTime,
              selectedEvent: selectedEvent,
              activeDraggingCap: activeDraggingCap,
              scrubAngle: scrubAngle,
              effectiveAllEvents: effectiveAllEvents,
              dialSegment: dialSegment,
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
            if (showSegmentPill) ...[
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

  Widget _buildNewEngineDialStack({
    required BuildContext context,
    required WidgetRef ref,
    required double dialSize,
    required double innerRadius,
    required Offset center,
    required double routineTrackIn,
    required double routineTrackOut,
    required DialSettings settings,
    required ColorScheme colorScheme,
    required ThemeData theme,
    required bool isDialEditing,
    required DateTime viewingDay,
    required DateTime currentTime,
    required SectorEvent? selectedEvent,
    required CapHitResult? activeDraggingCap,
    required double? scrubAngle,
    required List<SectorEvent> effectiveAllEvents,
    required Dial12HourSegment dialSegment,
  }) {
    final model = ref.watch(dialModelProvider);

    final gestureController = DialGestureController(
      ref: ref,
      model: model,
      center: center,
      innerRadius: innerRadius,
      routineTrackIn: routineTrackIn,
      routineTrackOut: routineTrackOut,
      ringDividerRadius: (routineTrackIn + routineTrackOut) / 2.0,
      is24HourMode: settings.is24HourMode,
      isDialEditing: isDialEditing,
      allEvents: effectiveAllEvents,
      selectedEvent: selectedEvent,
    );

    final semanticsLabel = _buildSemanticsLabel(model);

    return GestureDetector(
      onPanDown: gestureController.handlePanDown,
      onPanStart: gestureController.handlePanStart,
      onPanUpdate: gestureController.handlePanUpdate,
      onPanEnd: gestureController.handlePanEnd,
      onPanCancel: gestureController.handlePanCancel,
      onTapUp: (details) {
        final hit = gestureController.hitTestBlock(details.localPosition);
        if (hit != null) {
          SectorEvent? matching;
          for (final ev in effectiveAllEvents) {
            if (ev.id == hit.eventId) {
              matching = ev;
              break;
            }
          }
          matching ??= OccurrenceAdapter.toSectorEvent(
            hit.occurrence,
            is24HourMode: settings.is24HourMode,
          );

          ref.read(selectedEventProvider.notifier).state = matching;
          HapticFeedback.lightImpact();

          final isTitleTap = DialTimeCapDragHandler.isTitleTextHit(
            localOffset: details.localPosition,
            center: center,
            rIn: routineTrackIn,
            rOut: routineTrackOut,
            event: matching,
            is24HourMode: settings.is24HourMode,
          );

          if (isTitleTap) {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              showDragHandle: false,
              backgroundColor: Colors.transparent,
              builder: (_) =>
                  EventEditModal(event: matching!, initialDate: viewingDay),
            );
          }
        } else {
          gestureController.handleTapUp(details);
        }
      },
      child: Semantics(
        label: semanticsLabel,
        container: true,
        child: Stack(
          alignment: Alignment.center,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                size: Size(dialSize, dialSize),
                painter: DialPainter(
                  model: model,
                  settings: settings,
                  theme: theme,
                  colorScheme: colorScheme,
                  activeDraggingCap: activeDraggingCap,
                  scrubAngle: scrubAngle,
                  selectedEventId: selectedEvent?.id,
                  showCenterClock: false,
                  showNeedle: true,
                ),
              ),
            ),
            ClipOval(
              child: SizedBox(
                width: innerRadius * 2 * 0.94,
                height: innerRadius * 2 * 0.94,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: isDialEditing
                      ? Center(
                          key: const ValueKey('dial_center_edit_btn'),
                          child: BouncyPressable(
                            scaleDownFactor: 0.88,
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              final is24H = settings.is24HourMode;
                              final maxAllowed = is24H
                                  ? BlockBudget.maxPerWindow24H
                                  : BlockBudget.maxPerWindow12H;
                              if (model.blocks.length >= maxAllowed) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Dial limit reached: maximum $maxAllowed blocks allowed in ${is24H ? "24H" : "12H"} mode to prevent dial clutter.',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                );
                                return;
                              }
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: false,
                                backgroundColor: Colors.transparent,
                                builder: (_) => EventEditModal(
                                  event: null,
                                  initialDate: viewingDay,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.add_rounded,
                                size: 26,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          key: const ValueKey('dial_center_clock_summary'),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: innerRadius * 1.36,
                              maxHeight: innerRadius * 1.36,
                            ),
                            child: CenterSummary(
                              currentTime: currentTime,
                              activeEvent: selectedEvent,
                              selectedEvent: selectedEvent,
                              is24HourMode: settings.is24HourMode,
                              onDismissSelected: () {
                                ref.read(selectedEventProvider.notifier).state =
                                    null;
                              },
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (model.hidden.hiddenCount > 0 &&
                settings.showHiddenBlocksIndicator)
              Positioned(
                bottom: 6,
                right: 6,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      HiddenBlocksSheet.show(
                        context,
                        model: model,
                        settings: settings,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.visibility_off_rounded,
                            size: 13,
                            color: Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+${model.hidden.hiddenCount}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _buildSemanticsLabel(DialModel model) {
    final sb = StringBuffer();
    if (model.center.activeTitle.isNotEmpty &&
        model.center.activeTitle != 'Free Time') {
      sb.write('Now: ${model.center.activeTitle}');
      if (model.center.remainingDurationFormatted.isNotEmpty) {
        sb.write(
          ', until ${model.center.remainingDurationFormatted} remaining. ',
        );
      } else {
        sb.write('. ');
      }
    } else {
      sb.write('Now: Free time. ');
    }

    final nextBlock = model.blocks
        .where((b) => b.role == BlockRole.next)
        .firstOrNull;
    if (nextBlock != null) {
      sb.write('Next: ${nextBlock.title}');
      if (nextBlock.caps.startTimeLabel.isNotEmpty &&
          nextBlock.caps.endTimeLabel.isNotEmpty) {
        sb.write(
          ', ${nextBlock.caps.startTimeLabel} to ${nextBlock.caps.endTimeLabel}. ',
        );
      } else {
        sb.write('. ');
      }
    }

    sb.write('${model.blocks.length} events on the dial.');
    if (model.blocks.isNotEmpty) {
      sb.write(' Events: ');
      for (final block in model.blocks) {
        sb.write('${_buildBlockSemanticsLabel(block)} ');
      }
    }
    return sb.toString().trim();
  }

  static String _buildBlockSemanticsLabel(DialBlock block) {
    final prefix = block.role == BlockRole.active
        ? 'Current event'
        : (block.role == BlockRole.next ? 'Next event' : 'Scheduled event');
    final timeRange =
        block.caps.startTimeLabel.isNotEmpty &&
            block.caps.endTimeLabel.isNotEmpty
        ? 'from ${block.caps.startTimeLabel} to ${block.caps.endTimeLabel}'
        : '';
    final subtaskInfo = block.subtasks.isNotEmpty
        ? ', ${block.subtasks.length} subtasks'
        : '';
    final categoryInfo = block.category.isNotEmpty
        ? ', category ${block.category}'
        : '';
    return '$prefix: ${block.title}, $timeRange$categoryInfo$subtaskInfo.'
        .trim();
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
                    .state = ref.read(clockProvider).now().hour < 12
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
