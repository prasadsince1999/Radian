import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/models/subtask_item.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';
import '../editor/subtask_edit_sheet.dart';

/// Modal bottom sheet displaying all subtasks scheduled for the selected day across all blocks.
///
/// If subtask blocks end from their main blocks according to date, they appear independently here
/// with completion toggles, parent block badges, scheduled times, and ended/active status.
class DailySubtasksSheet extends ConsumerWidget {
  const DailySubtasksSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      sheetAnimationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 280),
        reverseDuration: Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      constraints: const BoxConstraints(
        maxWidth: AppLayoutConstants.modalMaxWidth,
      ),
      shape: ExpressiveShapes.modalSheet,
      builder: (_) => const DailySubtasksSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final selectedDay = ref.watch(selectedDayProvider);
    final eventsAsync = ref.watch(eventsForDateProvider(selectedDay));
    final events = eventsAsync.value ?? const <SectorEvent>[];
    final is24 = ref.watch(dialSettingsProvider.select((s) => s.is24HourMode));
    final now = ref.watch(currentTimeProvider).value ?? DateTime.now();

    final isToday =
        selectedDay.year == now.year &&
        selectedDay.month == now.month &&
        selectedDay.day == now.day;
    final isPastDay = selectedDay.isBefore(
      DateTime(now.year, now.month, now.day),
    );

    // Collect all subtask entries for the day with their parent event
    final subtaskEntries = <({SectorEvent parent, SubtaskItem subtask})>[];
    for (final ev in events) {
      for (final sub in ev.subtaskItems) {
        if (sub.isScheduledForDate(selectedDay)) {
          subtaskEntries.add((parent: ev, subtask: sub));
        }
      }
    }

    final totalCount = subtaskEntries.length;
    final completedCount = subtaskEntries
        .where((e) => e.subtask.isCompleted)
        .length;
    final progress = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return RepaintBoundary(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? colorScheme.surfaceContainerLow
                : colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(16, 8, 16, 20 + bottomInset),
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

              // Header Row
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: ShapeDecoration(
                      shape: ExpressiveShapes.squircle(12),
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    child: Icon(
                      Icons.checklist_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Subtasks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          DateFormat('EEEE, MMM d').format(selectedDay),
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (events.isNotEmpty)
                    BouncyPressable(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        SubtaskEditSheet.show(
                          context,
                          initialDate: selectedDay,
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.4,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.primary.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              size: 15,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add Subtask',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Progress Banner
              if (totalCount > 0) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$completedCount of $totalCount completed',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress == 1.0
                                ? Colors.green
                                : colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Subtask Items List or Empty State
              if (totalCount == 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.task_alt_rounded,
                        size: 48,
                        color: colorScheme.outlineVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Subtasks For This Day',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        events.isEmpty
                            ? 'Add a time block first, then slice it into subtasks.'
                            : 'Create subtasks inside your macro blocks to schedule focused time slices.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (events.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            SubtaskEditSheet.show(
                              context,
                              initialDate: selectedDay,
                            );
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Subtask'),
                        ),
                      ],
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: false,
                    physics: const BouncingScrollPhysics(),
                    itemCount: subtaskEntries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final entry = subtaskEntries[idx];
                      final parent = entry.parent;
                      final subtask = entry.subtask;

                      // Ended detection
                      bool isEnded = false;
                      if (isPastDay) {
                        isEnded = true;
                      } else if (isToday) {
                        if (subtask.endTime != null) {
                          final subEndDt = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            subtask.endTime!.hour,
                            subtask.endTime!.minute,
                          );
                          isEnded = subEndDt.isBefore(now);
                        } else {
                          isEnded = parent.end.isBefore(now);
                        }
                      }

                      final timeRangeStr = () {
                        if (subtask.startTime != null &&
                            subtask.endTime != null) {
                          return '${TimeFormatters.formatTimeOfDay(subtask.startTime!, is24Hour: is24)} – ${TimeFormatters.formatTimeOfDay(subtask.endTime!, is24Hour: is24)}';
                        }
                        return 'Untimed · In Block';
                      }();

                      return Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHigh.withValues(
                            alpha: 0.55,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: subtask.isCompleted
                                ? Colors.green.withValues(alpha: 0.3)
                                : parent.color.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Completion Checkbox
                            BouncyPressable(
                              key: ValueKey('subtask_checkbox_${subtask.id}'),
                              scaleDownFactor: 0.88,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                final updatedItems = parent.subtaskItems
                                    .map(
                                      (s) => s.id == subtask.id
                                          ? s.copyWith(
                                              isCompleted: !s.isCompleted,
                                            )
                                          : s,
                                    )
                                    .toList();
                                ref
                                    .read(eventRepositoryProvider)
                                    .updateEvent(
                                      parent.copyWith(
                                        subtaskItems: updatedItems,
                                      ),
                                    );
                              },
                              child: Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  color: subtask.isCompleted
                                      ? Colors.green
                                      : colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: subtask.isCompleted
                                        ? Colors.green
                                        : colorScheme.outlineVariant,
                                    width: 1.5,
                                  ),
                                ),
                                child: subtask.isCompleted
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 17,
                                        color: Colors.white,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Subtask Details (tappable to edit)
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    SubtaskEditSheet.show(
                                      context,
                                      existingSubtask: subtask,
                                      initialParentEventId: parent.id,
                                      initialDate: selectedDay,
                                      parentStartTime: TimeOfDay(
                                        hour: parent.start.hour,
                                        minute: parent.start.minute,
                                      ),
                                      parentEndTime: TimeOfDay(
                                        hour: parent.end.hour,
                                        minute: parent.end.minute,
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          subtask.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: subtask.isCompleted
                                                ? colorScheme.onSurfaceVariant
                                                      .withValues(alpha: 0.6)
                                                : colorScheme.onSurface,
                                            decoration: subtask.isCompleted
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            // Parent Block Pill Tag
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: parent.color.withValues(
                                                  alpha: 0.15,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    width: 6,
                                                    height: 6,
                                                    decoration: BoxDecoration(
                                                      color: parent.color,
                                                      shape: BoxShape.circle,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    parent.title,
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: parent.color,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),

                                            // Time Tag
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: colorScheme
                                                    .surfaceContainerHighest,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                timeRangeStr,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                              ),
                                            ),

                                            // Ended Tag
                                            if (isEnded && !subtask.isCompleted)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.amber
                                                      .withValues(alpha: 0.18),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Ended',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w800,
                                                    color: Colors.amber,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Quick Delete Icon
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 16,
                                color: colorScheme.onSurfaceVariant.withValues(
                                  alpha: 0.5,
                                ),
                              ),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                final updatedItems = parent.subtaskItems
                                    .where((s) => s.id != subtask.id)
                                    .toList();
                                ref
                                    .read(eventRepositoryProvider)
                                    .updateEvent(
                                      parent.copyWith(
                                        subtaskItems: updatedItems,
                                      ),
                                    );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
