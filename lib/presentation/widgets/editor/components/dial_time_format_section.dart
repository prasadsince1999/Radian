import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../controllers/clock_controller.dart';

/// Section managing 24-hour mode, center clock display, dial shape, and past hours style.
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
      ],
    );
  }
}
