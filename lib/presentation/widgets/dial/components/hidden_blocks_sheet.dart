import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/date_labels.dart';
import '../../../../domain/models/dial_settings.dart';
import '../../../../engine/dial_model.dart';
import '../../../../engine/horizon_selector.dart';
import '../../../controllers/clock_controller.dart';

/// Modal bottom sheet presenting hidden blocks and the reasons for their exclusion (§9 Feature 1, I10).
class HiddenBlocksSheet extends ConsumerWidget {
  final DialModel model;
  final DialSettings settings;

  const HiddenBlocksSheet({
    super.key,
    required this.model,
    required this.settings,
  });

  static void show(BuildContext context, {
    required DialModel model,
    required DialSettings settings,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HiddenBlocksSheet(model: model, settings: settings),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hiddenEvents = model.hidden.hiddenEvents;
    final hiddenCount = model.hidden.hiddenCount;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.visibility_off_rounded,
                  color: Color(0xFFF59E0B),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hidden Blocks ($hiddenCount)',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Scheduled events hidden to maintain clarity (I10)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Explanation Banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              'Radian displays an intentional active horizon (P previous, N upcoming) to give tasks room and prevent dial clutter. Hidden events are fully preserved in your schedule.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Event list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: hiddenEvents.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = hiddenEvents[index];
                return _buildHiddenEventTile(context, item);
              },
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              if (!settings.is24HourMode)
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.av_timer_rounded, size: 18),
                    label: const Text('Try 24H View'),
                    onPressed: () {
                      final current = ref.read(dialSettingsProvider);
                      ref
                          .read(dialSettingsProvider.notifier)
                          .updateSettings(current.copyWith(is24HourMode: true));
                      Navigator.pop(context);
                    },
                  ),
                ),
              if (!settings.is24HourMode) const SizedBox(width: 12),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHiddenEventTile(BuildContext context, HiddenEventInfo item) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final String reasonText;
    if (item.reason.startsWith('exceedsHorizon:next')) {
      reasonText = 'Beyond upcoming horizon (N=${settings.futureBlocksCount})';
    } else if (item.reason.startsWith('exceedsHorizon:prev')) {
      reasonText = 'Prior to past horizon (P=${settings.previousBlocksCount})';
    } else if (item.reason.startsWith('aliasesWith:')) {
      reasonText = '12H angle collision with earlier block';
    } else {
      reasonText = item.reason;
    }

    String timeLabel = '';
    if (item.start != null && item.end != null) {
      timeLabel = DateLabels.formatTimeRange(
        item.start!,
        item.end!,
        is24Hour: settings.is24HourMode,
        numeralSystem: settings.numeralSystem,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5, right: 12),
            decoration: BoxDecoration(
              color: _parseColor(item.colorHex),
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                if (timeLabel.isNotEmpty)
                  Text(
                    timeLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reasonText,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    final val = int.tryParse(clean, radix: 16) ?? 0xFF6366F1;
    return Color(val.bitLength <= 24 ? val | 0xFF000000 : val);
  }
}
