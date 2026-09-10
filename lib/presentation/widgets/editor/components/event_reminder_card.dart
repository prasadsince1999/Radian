import 'package:flutter/material.dart';

import '../../../../core/services/reminder_notification_service.dart';
import '../../common/bouncy_pressable.dart';

/// Interactive Reminder Card for EventEditModal (Reminder Chips & Android Notification Permission check).
class EventReminderCard extends StatelessWidget {
  final int? selectedReminderMinutes;
  final Color currentColor;
  final Color cardBg;
  final Color cardBorder;
  final ValueChanged<int?> onReminderSelected;

  const EventReminderCard({
    super.key,
    required this.selectedReminderMinutes,
    required this.currentColor,
    required this.cardBg,
    required this.cardBorder,
    required this.onReminderSelected,
  });

  static const _reminderOptions = <(String, int?)>[
    ('None', null),
    ('At start', 0),
    ('5 min', 5),
    ('10 min', 10),
    ('15 min', 15),
    ('30 min', 30),
    ('1 hour', 60),
    ('1 day', 1440),
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
          Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                size: 18,
                color: currentColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Reminder',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _reminderOptions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (ctx, i) {
                final opt = _reminderOptions[i];
                final label = opt.$1;
                final minutes = opt.$2;
                final isSelected = selectedReminderMinutes == minutes;

                return BouncyPressable(
                  scaleDownFactor: 0.94,
                  onTap: () async {
                    onReminderSelected(minutes);
                    if (minutes != null) {
                      final enabled =
                          await ReminderNotificationService.areNotificationsEnabled();
                      if (!enabled) {
                        await ReminderNotificationService.requestNotificationPermission();
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? currentColor.withValues(alpha: 0.22)
                          : colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? currentColor
                            : colorScheme.outlineVariant,
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? currentColor
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
