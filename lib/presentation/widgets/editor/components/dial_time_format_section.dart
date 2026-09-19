import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/dial_settings.dart';
import '../../../controllers/clock_controller.dart';
import '../../common/bouncy_pressable.dart';

/// Section managing 24-hour mode and center circle display customization.
class DialTimeFormatSection extends ConsumerWidget {
  const DialTimeFormatSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dialSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardBg = colorScheme.surfaceContainer;
    final cardBorder = colorScheme.outlineVariant;
    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentBg = colorScheme.primaryContainer;
    final accentColor = colorScheme.primary;

    final centerDisplayOptions = [
      (
        mode: CenterClockDisplay.digital,
        label: 'Digital Clock',
        icon: Icons.pin_rounded,
        description: 'Bold time numbers and AM/PM tag',
      ),
      (
        mode: CenterClockDisplay.analog,
        label: 'Analog Clock',
        icon: Icons.watch_later_outlined,
        description: 'Watchmaker hands with hour ticks',
      ),
      (
        mode: CenterClockDisplay.dateTime,
        label: 'Date & Time',
        icon: Icons.calendar_today_rounded,
        description: 'Prominent weekday, date, and time',
      ),
      (
        mode: CenterClockDisplay.countdown,
        label: 'Countdown',
        icon: Icons.timer_outlined,
        description: 'Time remaining or until next block',
      ),
      (
        mode: CenterClockDisplay.dobAge,
        label: 'Life Clock (Age)',
        icon: Icons.hourglass_bottom_rounded,
        description: 'Age & total days lived from DOB',
      ),
      (
        mode: CenterClockDisplay.currentSubtask,
        label: 'Current Subtask',
        icon: Icons.checklist_rounded,
        description: 'Active focused subtask & status',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Dial Mode (12h vs 24h)
        Material(
          color: cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cardBorder, width: 1.2),
          ),
          clipBehavior: Clip.antiAlias,
          child: SwitchListTile(
            title: Text(
              '24-Hour Dial Mode',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: primaryText,
              ),
            ),
            subtitle: Text(
              settings.is24HourMode
                  ? 'Full 24-hour circular rotation (0.25°/min)'
                  : 'Classic 12-hour circular dial (0.5°/min)',
              style: TextStyle(fontSize: 11.5, color: secondaryText),
            ),
            activeThumbColor: accentColor,
            activeTrackColor: accentBg,
            inactiveThumbColor: colorScheme.outline,
            inactiveTrackColor: colorScheme.surfaceContainerLow,
            value: settings.is24HourMode,
            onChanged: (val) {
              ref.read(dialSettingsProvider.notifier).toggle24HourMode();
            },
          ),
        ),
        const SizedBox(height: 12),

        // 2. Center Circle Customization Section
        Container(
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
                    Icons.radio_button_checked_rounded,
                    size: 16,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CENTER CIRCLE DISPLAY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Grid of Options
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: centerDisplayOptions.map((opt) {
                  final isSelected = settings.centerClockDisplay == opt.mode;
                  return BouncyPressable(
                    scaleDownFactor: 0.94,
                    onTap: () {
                      ref
                          .read(dialSettingsProvider.notifier)
                          .setCenterClockDisplay(opt.mode);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentColor.withValues(alpha: 0.16)
                            : colorScheme.surfaceContainerHigh.withValues(
                                alpha: 0.5,
                              ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : cardBorder.withValues(alpha: 0.6),
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt.icon,
                            size: 15,
                            color: isSelected ? accentColor : secondaryText,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            opt.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isSelected ? accentColor : primaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              // Date of Birth Picker if dobAge is selected
              if (settings.centerClockDisplay == CenterClockDisplay.dobAge) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.cake_rounded, size: 16, color: accentColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date of Birth',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: secondaryText,
                              ),
                            ),
                            Text(
                              settings.dateOfBirth != null
                                  ? DateFormat.yMMMd().format(
                                      settings.dateOfBirth!,
                                    )
                                  : 'Not set (Jan 1, 2000)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.edit_calendar_rounded, size: 15),
                        label: const Text('Set DOB'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                settings.dateOfBirth ?? DateTime(2000, 1, 1),
                            firstDate: DateTime(1920),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            ref
                                .read(dialSettingsProvider.notifier)
                                .setDateOfBirth(picked);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
