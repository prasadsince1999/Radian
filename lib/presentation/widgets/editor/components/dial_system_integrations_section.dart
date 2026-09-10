import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_layout_constants.dart';
import '../../../../core/services/android_widget_service.dart';
import '../../../../core/services/device_settings_service.dart';
import '../../../../core/services/health_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/expressive_shapes.dart';
import '../../../controllers/clock_controller.dart';
import '../../../controllers/mcp_server_controller.dart';
import '../../common/bouncy_pressable.dart';
import '../../mcp/mcp_status_sheet.dart';
import 'dial_editor_styles.dart';

/// Section managing Android system integrations: Home Screen Widget, Battery Optimization, Health Connect, and MCP.
class DialSystemIntegrationsSection extends ConsumerWidget {
  const DialSystemIntegrationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardBg = colorScheme.surfaceContainer;
    final cardBorder = colorScheme.outlineVariant;
    final primaryText = colorScheme.onSurface;
    final secondaryText = colorScheme.onSurfaceVariant;
    final accentBg = colorScheme.primaryContainer;
    final accentBorder = colorScheme.primary.withValues(alpha: 0.35);
    final accentColor = colorScheme.primary;

    final isBatteryIgnored =
        ref.watch(batteryOptimizationStatusProvider).value ?? false;
    final hasHealthPerms =
        ref.watch(healthPermissionsStatusProvider).value ?? false;
    final mcpState = ref.watch(mcpServerControllerProvider);

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
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Background & Battery Saver Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isBatteryIgnored
                  ? AppColors.statusSuccess.withValues(alpha: 0.5)
                  : cardBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isBatteryIgnored
                        ? Icons.check_circle_rounded
                        : Icons.battery_charging_full_rounded,
                    size: 18,
                    color: isBatteryIgnored
                        ? AppColors.statusSuccess
                        : accentColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isBatteryIgnored
                        ? 'Battery Optimization: Disabled ✓'
                        : 'Background & Battery Saver',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: isBatteryIgnored
                          ? AppColors.statusSuccess
                          : primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isBatteryIgnored
                    ? 'Sectograph is running unrestricted. Background widget updates and routine reminders run reliably.'
                    : 'Allow Sectograph to run unrestricted so Android battery savers do not pause the dial widget or routine reminders.',
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
                    if (isBatteryIgnored) {
                      await DeviceSettingsService.openBatterySettings();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Battery optimization is already unrestricted. Opened App Settings.',
                            ),
                          ),
                        );
                      }
                    } else {
                      await DeviceSettingsService.requestIgnoreBatteryOptimization();
                    }
                    ref.invalidate(batteryOptimizationStatusProvider);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isBatteryIgnored
                          ? AppColors.statusSuccess.withValues(alpha: 0.12)
                          : accentBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isBatteryIgnored
                            ? AppColors.statusSuccess.withValues(alpha: 0.4)
                            : accentBorder,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isBatteryIgnored
                              ? Icons.tune_rounded
                              : Icons.battery_charging_full_rounded,
                          size: 18,
                          color: isBatteryIgnored
                              ? AppColors.statusSuccess
                              : accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isBatteryIgnored
                              ? 'Manage in Android Settings'
                              : 'Disable Battery Optimization',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isBatteryIgnored
                                ? AppColors.statusSuccess
                                : accentColor,
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
        const SizedBox(height: 12),

        // Health Connect Permissions Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasHealthPerms
                  ? AppColors.statusSuccess.withValues(alpha: 0.5)
                  : cardBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    hasHealthPerms
                        ? Icons.check_circle_rounded
                        : Icons.favorite_rounded,
                    size: 18,
                    color: hasHealthPerms
                        ? AppColors.statusSuccess
                        : AppColors.healthCoral,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasHealthPerms
                        ? 'Health Connect: Connected ✓'
                        : 'Google Health Connect',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: hasHealthPerms
                          ? AppColors.statusSuccess
                          : primaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                hasHealthPerms
                    ? 'Health Connect biometrics permissions are active. Steps, sleep, and workouts sync with your dial.'
                    : 'Grant permissions to sync steps, sleep sessions, workouts, active calories, and hydration onto the dial.',
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
                    final selectedDay = ref.read(selectedDayProvider);
                    final health = await ref.read(
                      dailyHealthSummaryProvider(selectedDay).future,
                    );
                    final currentEvents =
                        ref.read(dayEventsProvider).value ?? const [];
                    final newSectors = await ref
                        .read(syncHealthSessionsUseCaseProvider)
                        .execute(health: health, existingEvents: currentEvents);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            newSectors.isEmpty
                                ? 'No new health or workout sessions to sync.'
                                : 'Synced ${newSectors.length} health session(s) to your dial!',
                          ),
                          backgroundColor: colorScheme.surfaceContainerHigh,
                          behavior: SnackBarBehavior.floating,
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
                        Icon(Icons.sync_rounded, size: 18, color: accentColor),
                        const SizedBox(width: 8),
                        Text(
                          'Sync Workouts & Sleep to Dial',
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
                    await DeviceSettingsService.openHealthConnectSettings();
                    ref.invalidate(healthPermissionsStatusProvider);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: hasHealthPerms
                          ? AppColors.statusSuccess.withValues(alpha: 0.12)
                          : AppColors.healthCoral.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: hasHealthPerms
                            ? AppColors.statusSuccess.withValues(alpha: 0.4)
                            : AppColors.healthCoral.withValues(alpha: 0.4),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.health_and_safety_rounded,
                          size: 18,
                          color: hasHealthPerms
                              ? AppColors.statusSuccess
                              : AppColors.healthCoral,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Manage Health Permissions',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: hasHealthPerms
                                ? AppColors.statusSuccess
                                : AppColors.healthCoral,
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
        const SizedBox(height: 12),

        // Model Context Protocol (MCP) Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: mcpState.isRunning
                  ? AppColors.statusSuccess.withValues(alpha: 0.5)
                  : cardBorder,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.mcpVioletContainer.withValues(
                        alpha: 0.15,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.bar_chart_rounded,
                      size: 16,
                      color: AppColors.mcpViolet,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Model Context Protocol (MCP)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: primaryText,
                      ),
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: mcpState.isRunning
                          ? AppColors.statusSuccess
                          : AppColors.statusError,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Connect external AI assistants (ChatGPT, Claude, Grok) via open MCP endpoints to manage and plan your dial schedule.',
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
                  onTap: () {
                    Navigator.of(context).pop();
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      showDragHandle: false,
                      constraints: const BoxConstraints(
                        maxWidth: AppLayoutConstants.modalMaxWidth,
                      ),
                      shape: ExpressiveShapes.modalSheet,
                      builder: (_) => const McpStatusSheet(),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.mcpVioletContainer.withValues(
                        alpha: 0.12,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.mcpVioletContainer.withValues(
                          alpha: 0.4,
                        ),
                        width: 1.2,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.hub_rounded,
                          size: 18,
                          color: AppColors.mcpViolet,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Manage MCP & AI Endpoints',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.mcpViolet,
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
