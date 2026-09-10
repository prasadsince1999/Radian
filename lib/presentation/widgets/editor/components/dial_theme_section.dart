import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_presets.dart';
import '../../../controllers/clock_controller.dart';
import '../../common/bouncy_pressable.dart';
import 'dial_editor_styles.dart';

/// Section managing Theme Mode (Auto/Light/Dark) and Expressive Seed Palette colors.
class DialThemeSection extends ConsumerWidget {
  const DialThemeSection({super.key});

  static const _seedPalette = AppPresets.defaultSeedPalette;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dialSettingsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryText = colorScheme.onSurface;
    final accentColor = colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 3. Theme Mode
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme Mode',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  style: DialEditorStyles.segmentedButtonStyle(colorScheme),
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text(
                        'Auto',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text(
                        'Light',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text(
                        'Dark',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (set) {
                    HapticFeedback.selectionClick();
                    ref
                        .read(dialSettingsProvider.notifier)
                        .setThemeMode(set.first);
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 4. Theme Seed Accent Color
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: DialEditorStyles.cardDecoration(colorScheme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Expressive Seed Palette',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _seedPalette.map((pair) {
                    final hex = pair.$1;
                    final color = Color(
                      int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                    );
                    final isSelected =
                        settings.seedColorHex.toLowerCase() ==
                        hex.toLowerCase();

                    return BouncyPressable(
                      scaleDownFactor: 0.88,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        ref
                            .read(dialSettingsProvider.notifier)
                            .setSeedColorHex(hex);
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? accentColor
                                : colorScheme.outlineVariant,
                            width: isSelected ? 3 : 1.5,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 20,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
