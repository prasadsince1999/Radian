import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../controllers/app_update_controller.dart';
import '../../common/bouncy_pressable.dart';
import '../../update/app_update_modal.dart';
import 'dial_editor_styles.dart';

/// Card displayed inside Custom Dial Settings allowing users to directly inspect,
/// verify, and trigger Over-The-Air (OTA) releases.
class DialOtaUpdatesSection extends ConsumerWidget {
  const DialOtaUpdatesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final updateState = ref.watch(appUpdateControllerProvider);

    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentColor = colorScheme.primary;
    final accentBg = colorScheme.primaryContainer;
    final accentBorder = colorScheme.primary.withValues(alpha: 0.35);

    final hasNewUpdate =
        updateState.isAvailable || updateState.isReadyToInstall;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DialEditorStyles.cardDecoration(colorScheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accentBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accentBorder, width: 1.2),
                ),
                child: Icon(
                  Icons.system_update_rounded,
                  color: accentColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Over-The-Air (OTA) Updates',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Direct Edge releases via Cloudflare & GitHub',
                      style: TextStyle(fontSize: 12, color: secondaryText),
                    ),
                  ],
                ),
              ),
              // Version pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  'v${AppStrings.appVersion}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status & Info Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  hasNewUpdate
                      ? Icons.new_releases_rounded
                      : (updateState.isChecking
                            ? Icons.sync_rounded
                            : Icons.check_circle_outline_rounded),
                  size: 20,
                  color: hasNewUpdate
                      ? Colors.amber
                      : (updateState.isChecking
                            ? accentColor
                            : Colors.greenAccent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        updateState.isChecking
                            ? 'Checking for OTA updates...'
                            : (hasNewUpdate
                                  ? 'New Release v${updateState.updateInfo?.version} Ready'
                                  : 'You are on the latest release'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasNewUpdate
                            ? 'Tap below to download APK and install.'
                            : 'Channel: Production Edge · Build ${AppStrings.appBuildNumber}',
                        style: TextStyle(fontSize: 11, color: secondaryText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Button: Check for OTA Updates / View Modal
          BouncyPressable(
            onTap: () {
              HapticFeedback.lightImpact();
              AppUpdateModal.show(context, checkImmediately: true);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.rocket_launch_rounded,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasNewUpdate
                        ? 'Download & Install Update (OTA)'
                        : 'Check for OTA Updates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
