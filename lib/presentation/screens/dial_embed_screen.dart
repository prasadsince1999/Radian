import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/clock_controller.dart';
import '../widgets/common/bouncy_pressable.dart';
import '../widgets/dial/sectograph_dial.dart';

/// Lightweight, embeddable screen that hosts only the authentic SectographDial
/// without navigation bars or timeline lists, optimized for web embeds and iframes.
class DialEmbedScreen extends ConsumerWidget {
  const DialEmbedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(dialSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: Stack(
        children: [
          // Authentic Circular Polar Dial
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12.0),
              child: SectographDial(),
            ),
          ),

          // Subtle Mode Pill (Top Right)
          Positioned(
            top: 14,
            right: 14,
            child: BouncyPressable.standard(
              onTap: () {
                HapticFeedback.lightImpact();
                final isCurrently24 = settings.is24HourMode;
                ref.read(dialSettingsProvider.notifier).toggle24HourMode();
                ref
                    .read(eventRepositoryProvider)
                    .loadPreset(
                      !isCurrently24 ? 'international_24h' : 'indian_12h',
                    );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF131722).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: settings.is24HourMode
                        ? const Color(0xFF38BDF8).withValues(alpha: 0.5)
                        : const Color(0xFFF7C752).withValues(alpha: 0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      settings.is24HourMode ? '24H 🌐' : '12H 🇮🇳',
                      style: const TextStyle(
                        fontFamily: 'Space Grotesk',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
