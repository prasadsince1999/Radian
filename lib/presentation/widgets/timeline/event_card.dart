import 'package:flutter/material.dart';

import '../../../core/theme/expressive_shapes.dart';
import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/sector_event.dart';
import '../common/bouncy_pressable.dart';

class EventCard extends StatelessWidget {
  final SectorEvent event;
  final bool isSelected;
  final bool isActive;
  final bool is24HourMode;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const EventCard({
    super.key,
    required this.event,
    required this.isSelected,
    required this.isActive,
    required this.is24HourMode,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final eventColor = event.color;

    final solidCardBg = colorScheme.surfaceContainer;
    final solidSelectedCardBg = colorScheme.surfaceContainerHigh;
    final solidCardBorder = colorScheme.outlineVariant;

    return AnimatedScale(
      scale: isSelected ? 1.018 : 1.0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      child: BouncyPressable.card(
        onTap: onTap,
        onLongPress: onEdit,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: ShapeDecoration(
            color: isSelected ? solidSelectedCardBg : solidCardBg,
            shape: ContinuousRectangleBorder(
              side: BorderSide(
                color: isSelected ? eventColor : solidCardBorder,
                width: isSelected ? 2.0 : 1.2,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(ExpressiveShapes.cornerXl * 1.5),
                bottomRight: Radius.circular(ExpressiveShapes.cornerXl * 1.5),
                topRight: Radius.circular(ExpressiveShapes.cornerMd * 1.5),
                bottomLeft: Radius.circular(ExpressiveShapes.cornerMd * 1.5),
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Color Pill & Active Pulse
                Container(
                  width: 5,
                  height: 44,
                  decoration: BoxDecoration(
                    color: eventColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                // Solid Icon Squircle Badge (Synced to task color theme)
                Container(
                  width: 38,
                  height: 38,
                  decoration: ShapeDecoration(
                    color: eventColor.withValues(alpha: 0.18),
                    shape: ContinuousRectangleBorder(
                      side: BorderSide(
                        color: eventColor.withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Icon(event.resolvedIcon, size: 20, color: eventColor),
                ),
                const SizedBox(width: 12),
                // Content

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                border: Border.all(
                                  color: colorScheme.error.withValues(
                                    alpha: 0.5,
                                  ),
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'NOW',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  color: colorScheme.onErrorContainer,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          // Time range: bold start and end times
                          Text(
                            TimeFormatters.formatTimeRange(
                              event.start,
                              event.end,
                              is24Hour: is24HourMode,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '•',
                            style: TextStyle(color: colorScheme.outlineVariant),
                          ),
                          const SizedBox(width: 6),
                          // Duration
                          Text(
                            TimeFormatters.formatDuration(event.duration),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (event.category.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            // Category / Tag Chip displayed directly after block hours
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: eventColor.withValues(alpha: 0.16),
                                  border: Border.all(
                                    color: eventColor.withValues(alpha: 0.42),
                                    width: 1.0,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  event.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: eventColor,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (event.reminderMinutes != null) ...[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.notifications_active_outlined,
                              size: 13,
                              color: colorScheme.outlineVariant,
                            ),
                          ],
                        ],
                      ),
                      if (event.subtasks.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        if (!isSelected)
                          // Collapsed compact chip preview
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              ...event.subtasks.take(4).map((sub) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: eventColor.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: eventColor.withValues(alpha: 0.2),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.subdirectory_arrow_right_rounded,
                                        size: 10,
                                        color: eventColor,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          sub,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.onSurface
                                                .withValues(alpha: 0.85),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                              if (event.subtasks.length > 4)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${event.subtasks.length - 4}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        else
                          // EXPANDED VIEW: All subtasks revealed as interactive checklist
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: eventColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: eventColor.withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.checklist_rounded,
                                      size: 15,
                                      color: eventColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'SUBTASKS (${event.subtasks.length})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: eventColor,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ...event.subtasks.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final sub = entry.value;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3.5,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 16,
                                          color: eventColor.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            sub,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600,
                                              color: colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 5,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: eventColor.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '#${idx + 1}',
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: eventColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                if (event.notes.isNotEmpty) ...[
                                  const Divider(height: 14, thickness: 0.8),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.notes_rounded,
                                        size: 13,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          event.notes,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            fontStyle: FontStyle.italic,
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
