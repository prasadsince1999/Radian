import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/dial_settings.dart';
import '../../../controllers/clock_controller.dart';
import 'dial_editor_styles.dart';

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
        const SizedBox(height: 12),

        // 2. Center Clock Display (Digital / Analog / Both)
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Center Clock Display',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Show digital time, analog clock hands, or both',
                style: TextStyle(fontSize: 11.5, color: secondaryText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<CenterClockDisplay>(
                  style: DialEditorStyles.segmentedButtonStyle(colorScheme),
                  segments: const [
                    ButtonSegment(
                      value: CenterClockDisplay.digital,
                      label: Text(
                        'Digital',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(Icons.numbers_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: CenterClockDisplay.analog,
                      label: Text(
                        'Analog',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(Icons.access_time_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: CenterClockDisplay.both,
                      label: Text(
                        'Both',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(Icons.watch_later_outlined, size: 16),
                    ),
                  ],
                  selected: {settings.centerClockDisplay},
                  onSelectionChanged: (set) {
                    ref
                        .read(dialSettingsProvider.notifier)
                        .setCenterClockDisplay(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2b. Widget & Dial Shape
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Widget & Dial Shape',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Choose pure circle or organic 12-lobed petal wave',
                style: TextStyle(fontSize: 11.5, color: secondaryText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<DialShape>(
                  style: DialEditorStyles.segmentedButtonStyle(colorScheme),
                  segments: const [
                    ButtonSegment(
                      value: DialShape.circle,
                      label: Text(
                        'Pure Circle',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(Icons.circle_outlined, size: 16),
                    ),
                    ButtonSegment(
                      value: DialShape.waveRounded,
                      label: Text(
                        'Wave Rounded',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      icon: Icon(Icons.waves_rounded, size: 16),
                    ),
                  ],
                  selected: {settings.dialShape},
                  onSelectionChanged: (set) {
                    ref
                        .read(dialSettingsProvider.notifier)
                        .setDialShape(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2c. Past Hours Display (Normal / Shadow Dim / Disappear)
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Past Hours Display',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Treatment for completed & elapsed time blocks',
                style: TextStyle(fontSize: 11.5, color: secondaryText),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<PastHoursStyle>(
                  style: DialEditorStyles.segmentedButtonStyle(colorScheme),
                  segments: const [
                    ButtonSegment(
                      value: PastHoursStyle.normal,
                      label: Text(
                        'Normal',
                        style: TextStyle(
                          fontSize: 11.0,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: Icon(Icons.visibility_rounded, size: 15),
                    ),
                    ButtonSegment(
                      value: PastHoursStyle.shadowDim,
                      label: Text(
                        'Shadow/Dim',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: Icon(Icons.brightness_medium_rounded, size: 15),
                    ),
                    ButtonSegment(
                      value: PastHoursStyle.disappear,
                      label: Text(
                        'Disappear',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      icon: Icon(Icons.timelapse_rounded, size: 15),
                    ),
                  ],
                  selected: {settings.pastHoursStyle},
                  onSelectionChanged: (set) {
                    ref
                        .read(dialSettingsProvider.notifier)
                        .setPastHoursStyle(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
