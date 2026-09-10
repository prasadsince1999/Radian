import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../domain/models/dial_settings.dart';
import '../../../controllers/clock_controller.dart';
import 'dial_editor_styles.dart';

/// Section managing Dial Face Style (Classic / Numbers / Minimal).
class DialFaceSection extends ConsumerWidget {
  const DialFaceSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dialSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryText = colorScheme.onSurface;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: DialEditorStyles.cardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dial Face Style',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final effectiveStyle =
                  settings.faceStyle == DialFaceStyle.numbered
                  ? DialFaceStyle.classicTicks
                  : settings.faceStyle;
              return SizedBox(
                width: double.infinity,
                child: SegmentedButton<DialFaceStyle>(
                  style: DialEditorStyles.segmentedButtonStyle(colorScheme),
                  segments: const [
                    ButtonSegment(
                      value: DialFaceStyle.classicTicks,
                      label: Text(
                        'Classic',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ButtonSegment(
                      value: DialFaceStyle.minimal,
                      label: Text(
                        'Minimal',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  selected: {effectiveStyle},
                  onSelectionChanged: (set) {
                    ref
                        .read(dialSettingsProvider.notifier)
                        .setFaceStyle(set.first);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
