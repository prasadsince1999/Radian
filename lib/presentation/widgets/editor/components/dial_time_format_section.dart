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

        // 2c. Past Hours Display (Disappear / Bird's Eye / Focused Blocks)
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
              LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _PastHoursOptionTile(
                              style: PastHoursStyle.disappear,
                              title: 'Disappear',
                              subtitle: 'Hide past blocks',
                              icon: Icons.timelapse_rounded,
                              isSelected:
                                  settings.pastHoursStyle ==
                                  PastHoursStyle.disappear,
                              onTap: () => ref
                                  .read(dialSettingsProvider.notifier)
                                  .setPastHoursStyle(PastHoursStyle.disappear),
                              colorScheme: colorScheme,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _PastHoursOptionTile(
                              style: PastHoursStyle.birdsEye,
                              title: "Bird's Eye",
                              subtitle: 'Active + 2 past & 2 next',
                              icon: Icons.travel_explore_rounded,
                              isSelected:
                                  settings.pastHoursStyle ==
                                  PastHoursStyle.birdsEye,
                              onTap: () => ref
                                  .read(dialSettingsProvider.notifier)
                                  .setPastHoursStyle(PastHoursStyle.birdsEye),
                              colorScheme: colorScheme,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _PastHoursOptionTile(
                        style: PastHoursStyle.focusedBlock,
                        title: 'Focused Blocks',
                        subtitle: 'Zoom in on active block & expand circle for subtasks',
                        icon: Icons.center_focus_strong_rounded,
                        isSelected:
                            settings.pastHoursStyle ==
                            PastHoursStyle.focusedBlock,
                        onTap: () => ref
                            .read(dialSettingsProvider.notifier)
                            .setPastHoursStyle(PastHoursStyle.focusedBlock),
                        colorScheme: colorScheme,
                        isFullWidth: true,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PastHoursOptionTile extends StatelessWidget {
  final PastHoursStyle style;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isFullWidth;

  const _PastHoursOptionTile({
    required this.style,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isFullWidth ? 14 : 10,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primaryContainer.withValues(alpha: 0.75)
                : colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.outlineVariant.withValues(alpha: 0.6),
              width: isSelected ? 1.6 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      maxLines: isFullWidth ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: isSelected
                            ? colorScheme.onPrimaryContainer.withValues(
                                alpha: 0.82,
                              )
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
