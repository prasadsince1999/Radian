import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/android_widget_service.dart';
import '../common/bouncy_pressable.dart';
import '../common/radian_app_logo.dart';
import '../dialogs/about_radian_dialog.dart';
import '../sync/cloud_sync_vault_card.dart';
import 'components/dial_ota_updates_section.dart';
import 'components/dial_system_integrations_section.dart';
import 'components/dial_theme_section.dart';
import 'components/dial_time_format_section.dart';

/// Modal bottom sheet for customizing the Sectograph Dial, themes, and integrations.
class DialSettingsModal extends ConsumerWidget {
  const DialSettingsModal({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentBg = colorScheme.primaryContainer;
    final accentBorder = colorScheme.primary.withValues(alpha: 0.35);
    final accentColor = colorScheme.primary;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight:
              MediaQuery.sizeOf(context).height *
              AppLayoutConstants.dialSettingsModalHeightFactor,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: AppLayoutConstants.dragHandleWidth,
                    height: AppLayoutConstants.dragHandleHeight,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Header
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: accentBorder, width: 1.2),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: accentColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dial Customization',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: primaryText,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    BouncyPressable(
                      scaleDownFactor: 0.88,
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.outlineVariant,
                            width: 1.2,
                          ),
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: secondaryText,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Time Format & Display Styles
                const DialTimeFormatSection(),
                const SizedBox(height: 12),

                // Theme Mode & Seed Palette
                const DialThemeSection(),
                const SizedBox(height: 12),

                // Cloud Vault & Web Sync (Private Key, Eye Toggle, Warning, QR Code)
                const CloudSyncVaultCard(),
                const SizedBox(height: 12),

                // Over-The-Air (OTA) Delivery & Releases
                const DialOtaUpdatesSection(),
                const SizedBox(height: 12),

                // System & Device Integrations (Android Widget, Battery, Health Connect, MCP)
                if (AndroidWidgetService.isSupported) ...[
                  const DialSystemIntegrationsSection(),
                  const SizedBox(height: 12),
                ],

                // About Radian & KSM × Tech
                BouncyPressable(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    AboutRadianDialog.show(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const RadianAppLogo(size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'About Radian',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: primaryText,
                                ),
                              ),
                              Text(
                                'v${AppStrings.appVersion} (Build ${AppStrings.appBuildNumber}) · KSM × Tech',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: secondaryText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
