import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/android_widget_service.dart';
import '../../../controllers/clock_controller.dart';
import '../../common/bouncy_pressable.dart';
import 'dial_editor_styles.dart';

/// Section managing Android Home Screen Widget pinning and synchronization.
class DialSystemIntegrationsSection extends ConsumerWidget {
  const DialSystemIntegrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentBg = colorScheme.primaryContainer;
    final accentBorder = colorScheme.primary.withValues(alpha: 0.35);
    final accentColor = colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),

        // Home Screen Widget Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Home Screen Widget',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Display your signature routine dial directly on your home screen with live countdowns and quick block creation.',
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryText,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: BouncyPressable(
                  onTap: () async {
                    final success =
                        await AndroidWidgetService.requestPinWidget();
                    if (context.mounted && success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Widget pinned to Home Screen'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accentBorder, width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.widgets_rounded,
                          size: 18,
                          color: accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Pin Widget to Home Screen',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: BouncyPressable(
                  onTap: () async {
                    final events =
                        ref.read(allEventsProvider).value ??
                        ref.read(dayEventsProvider).value ??
                        const [];
                    final activeEvent = ref.read(currentActiveEventProvider);
                    final currentTime =
                        ref.read(currentTimeProvider).value ?? DateTime.now();
                    final settings = ref.read(dialSettingsProvider);
                    final theme = Theme.of(context);

                    await ref
                        .read(syncDialWidgetUseCaseProvider)
                        .execute(
                          events: events,
                          activeEvent: activeEvent,
                          currentTime: currentTime,
                          settings: settings,
                          theme: theme,
                        );

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Widget synchronized with latest dial design',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_rounded, size: 16, color: primaryText),
                        const SizedBox(width: 8),
                        Text(
                          'Sync Widget Now',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
