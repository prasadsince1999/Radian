import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/time_formatters.dart';
import '../../../domain/models/dial_settings.dart';
import '../../../domain/models/sector_event.dart';
import '../../controllers/clock_controller.dart';
import '../common/bouncy_pressable.dart';

class CenterSummary extends ConsumerWidget {
  final DateTime currentTime;
  final SectorEvent? activeEvent;
  final SectorEvent? selectedEvent;
  final bool is24HourMode;
  final VoidCallback? onDismissSelected;

  const CenterSummary({
    super.key,
    required this.currentTime,
    required this.activeEvent,
    required this.selectedEvent,
    required this.is24HourMode,
    this.onDismissSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final settings = ref.watch(dialSettingsProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: selectedEvent != null
          ? _buildSelectedEventView(context, colorScheme, theme)
          : _buildClockSummaryView(context, ref, settings),
    );
  }

  Widget _buildSelectedEventView(
    BuildContext context,
    ColorScheme colorScheme,
    ThemeData theme,
  ) {
    final ev = selectedEvent!;
    final isActive = ev.isCurrentlyActive(currentTime);
    final remainingMinutes = ev.end.difference(currentTime).inMinutes;

    return Center(
      key: ValueKey('event_${ev.id}'),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: ev.color.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ev.color.withValues(alpha: 0.5),
                    width: 1.0,
                  ),
                ),
                child: Text(
                  isActive
                      ? 'REMAINING ${remainingMinutes > 0 ? '${remainingMinutes}m' : '0m'}'
                      : 'FOCUSED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ev.color,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                ev.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${TimeFormatters.formatTime(ev.start, is24Hour: is24HourMode)} – ${TimeFormatters.formatTime(ev.end, is24Hour: is24HourMode)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 4),
              BouncyPressable(
                scaleDownFactor: 0.85,
                onTap: onDismissSelected,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockSummaryView(
    BuildContext context,
    WidgetRef ref,
    DialSettings settings,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPureAnalog =
        settings.centerClockDisplay == CenterClockDisplay.analog;
    final isPureDigital =
        settings.centerClockDisplay == CenterClockDisplay.digital;

    return BouncyPressable(
      key: ValueKey('clock_${settings.centerClockDisplay}'),
      scaleDownFactor: 0.94,
      onTap: () {
        ref.read(dialSettingsProvider.notifier).cycleCenterClockDisplay();
      },
      child: Tooltip(
        message: 'Tap to switch clock mode (Digital / Analog / Both)',
        child: Align(
          alignment: isPureDigital
              ? Alignment.center
              : (isPureAnalog
                    ? const Alignment(0, 0.28)
                    : const Alignment(0, 0.10)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isPureAnalog) ...[
                    // 1. PM / AM Tag in Primary Seed Accent
                    if (!is24HourMode)
                      Text(
                        currentTime.hour < 12 ? 'AM' : 'PM',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.primary,
                          letterSpacing: 0.8,
                          height: 1.0,
                        ),
                      ),
                    const SizedBox(height: 2),

                    // 2. Bold Digital Clock Readout
                    Text(
                      DateFormat(is24HourMode ? 'HH:mm' : 'h:mm')
                          .format(currentTime),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.5,
                        height: 1.0,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 3),
                  ],

                  // 3. Weekday, Day Month (e.g. "Mon, 7 Sep")
                  Text(
                    DateFormat('EEE, d MMM').format(currentTime),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 12.5,
                      letterSpacing: 0.1,
                    ),
                  ),
                  if (activeEvent != null) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3.0,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.secondary.withValues(alpha: 0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.spa_rounded,
                            size: 12,
                            color: colorScheme.onSecondaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            activeEvent!.title,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSecondaryContainer,
                              fontSize: 11.0,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
