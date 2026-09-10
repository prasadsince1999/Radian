import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';
import '../editor/event_edit_modal.dart';
import 'event_card.dart';

final selectedTimelineCategoryProvider = StateProvider<String>((ref) => 'All');

class ExpressiveTimeline extends ConsumerWidget {
  const ExpressiveTimeline({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsAsync = ref.watch(dayEventsProvider);
    final selectedEvent = ref.watch(selectedEventProvider);
    final activeEvent = ref.watch(currentActiveEventProvider);
    final is24 = ref.watch(dialSettingsProvider).is24HourMode;
    final now = ref.watch(currentTimeProvider).value ?? DateTime.now();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.timelapse_outlined,
                    size: 64,
                    color: colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Dial is clear',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap + to add a time block, or ask Grok / ChatGPT to plan your day.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final categories = <String>['All'];
        for (final e in events) {
          if (e.category.isNotEmpty && !categories.contains(e.category)) {
            categories.add(e.category);
          }
        }
        final activeCategory = ref.watch(selectedTimelineCategoryProvider);
        final effectiveCategory = categories.contains(activeCategory)
            ? activeCategory
            : 'All';

        final filteredEvents = effectiveCategory == 'All'
            ? events
            : events
                  .where(
                    (e) =>
                        e.category.toLowerCase() ==
                        effectiveCategory.toLowerCase(),
                  )
                  .toList();

        // Automatically reorder blocks: show recent/active one above
        final sorted = _reorderEvents(filteredEvents, now, selectedDay);

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppLayoutConstants.timelineMaxWidth,
            ),
            child: Column(
              children: [
                if (categories.length > 2)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 4,
                      bottom: 6,
                    ),
                    child: SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, catIdx) {
                          final cat = categories[catIdx];
                          final isSelected = cat == effectiveCategory;
                          return BouncyPressable(
                            scaleDownFactor: 0.92,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              ref
                                  .read(
                                    selectedTimelineCategoryProvider.notifier,
                                  )
                                  .state = isSelected
                                  ? 'All'
                                  : cat;
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primaryContainer
                                    : colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isSelected
                                      ? colorScheme.primary.withValues(
                                          alpha: 0.5,
                                        )
                                      : colorScheme.outlineVariant.withValues(
                                          alpha: 0.5,
                                        ),
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  cat,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isSelected
                                        ? colorScheme.onPrimaryContainer
                                        : colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 88),
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final ev = sorted[index];
                      return Dismissible(
                        key: ValueKey(ev.id),
                        direction: DismissDirection.horizontal,
                        dismissThresholds: const {
                          DismissDirection.startToEnd: 0.25,
                          DismissDirection.endToStart: 0.35,
                        },
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.primary.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: colorScheme.onPrimaryContainer,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: colorScheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        secondaryBackground: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: colorScheme.error.withValues(alpha: 0.4),
                              width: 1.2,
                            ),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Delete',
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.delete_outline_rounded,
                                color: colorScheme.onErrorContainer,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          if (direction == DismissDirection.startToEnd) {
                            // Slide Right -> Edit Modal
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: false,
                              constraints: const BoxConstraints(
                                maxWidth: AppLayoutConstants.modalMaxWidth,
                              ),
                              shape: ExpressiveShapes.modalSheet,
                              builder: (_) => EventEditModal(
                                event: ev,
                                initialDate: selectedDay,
                              ),
                            );
                            return false; // Snap back smoothly after opening edit
                          } else if (direction == DismissDirection.endToStart) {
                            // Slide Left -> Delete with Undo
                            _deleteWithUndo(context, ref, ev);
                            return true;
                          }
                          return false;
                        },
                        child: EventCard(
                          event: ev,
                          isSelected: selectedEvent?.id == ev.id,
                          isActive: activeEvent?.id == ev.id,
                          is24HourMode: is24,
                          onTap: () {
                            if (selectedEvent?.id == ev.id) {
                              ref.read(selectedEventProvider.notifier).state =
                                  null;
                            } else {
                              ref.read(selectedEventProvider.notifier).state =
                                  ev;
                            }
                          },
                          onEdit: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: false,
                              constraints: const BoxConstraints(
                                maxWidth: AppLayoutConstants.modalMaxWidth,
                              ),
                              shape: ExpressiveShapes.modalSheet,
                              builder: (_) => EventEditModal(
                                event: ev,
                                initialDate: selectedDay,
                              ),
                            );
                          },
                          onDelete: () => _deleteWithUndo(context, ref, ev),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref, SectorEvent ev) {
    HapticFeedback.mediumImpact();
    ref.read(eventRepositoryProvider).deleteEvent(ev.id);
    final selectedEvent = ref.read(selectedEventProvider);
    if (selectedEvent?.id == ev.id) {
      ref.read(selectedEventProvider.notifier).state = null;
    }
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Deleted "${ev.title}"',
          style: TextStyle(
            color: colorScheme.brightness == Brightness.dark
                ? colorScheme.onSurface
                : colorScheme.onInverseSurface,
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.inverseSurface,
        behavior: SnackBarBehavior.fixed,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          textColor: colorScheme.primary,
          onPressed: () {
            HapticFeedback.lightImpact();
            ref.read(eventRepositoryProvider).addEvent(ev);
          },
        ),
      ),
    );
  }

  List<SectorEvent> _reorderEvents(
    List<SectorEvent> events,
    DateTime now,
    DateTime selectedDay,
  ) {
    if (events.length <= 1) return events;

    final isToday = DateUtils.isSameDay(selectedDay, now);

    if (!isToday) {
      if (selectedDay.isBefore(now)) {
        // Past day: show most recent events of that day first
        return List<SectorEvent>.from(events)
          ..sort((a, b) => b.start.compareTo(a.start));
      } else {
        // Future day: show morning/earliest events first
        return List<SectorEvent>.from(events)
          ..sort((a, b) => a.start.compareTo(b.start));
      }
    }

    // Selected day is Today:
    SectorEvent? currentActive;
    for (final ev in events) {
      if (ev.isCurrentlyActive(now)) {
        currentActive = ev;
        break;
      }
    }

    // Upcoming blocks today (after current time)
    final upcoming = events.where((e) {
      if (currentActive != null && e.id == currentActive.id) return false;
      return e.start.isAfter(now);
    }).toList()..sort((a, b) => a.start.compareTo(b.start));

    // Past blocks today (ended before or equal to current time)
    final past =
        events.where((e) {
          if (currentActive != null && e.id == currentActive.id) return false;
          return !e.start.isAfter(now);
        }).toList()..sort(
          (a, b) => b.start.compareTo(a.start),
        ); // most recent past first

    if (currentActive != null) {
      return [currentActive, ...upcoming, ...past];
    }

    // No currently active event: upcoming first, then recent past
    return [...upcoming, ...past];
  }
}
