import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_layout_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/layout/window_size_class.dart';
import '../../core/services/android_widget_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/expressive_shapes.dart';
import '../../core/services/cloud_sync_service.dart';
import '../../domain/models/sector_event.dart';
import '../controllers/clock_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import '../controllers/app_update_controller.dart';
import '../controllers/mcp_server_controller.dart';
import '../widgets/calendar/calendar_sheet.dart';
import '../widgets/common/bouncy_pressable.dart';
import '../widgets/common/radian_logo.dart';
import '../widgets/dialogs/about_radian_dialog.dart';
import '../widgets/dial/sectograph_dial.dart';
import '../widgets/editor/dial_settings_modal.dart';
import '../widgets/editor/event_edit_modal.dart';
import '../../core/services/device_settings_service.dart';
import '../../core/services/health_service.dart';
import '../widgets/health/health_insights_sheet.dart';
import '../widgets/sync/cloud_sync_modal.dart';
import '../widgets/health/m3_activity_heatmap.dart';
import '../widgets/mcp/mcp_status_sheet.dart';
import '../widgets/timeline/daily_subtasks_sheet.dart';
import '../widgets/timeline/expressive_timeline.dart';
import '../widgets/update/app_update_modal.dart';

const _kSheetAnimationStyle = AnimationStyle(
  duration: Duration(milliseconds: 280),
  reverseDuration: Duration(milliseconds: 240),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late final AnimationController _expansionController;
  late final Animation<double> _expansionAnimation;
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expansionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expansionAnimation = CurvedAnimation(
      parent: _expansionController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    AndroidWidgetService.initialize(
      onAction: (action) {
        if (action == 'add_block') {
          _openAddBlock();
        } else if (action == 'open_today' || action == 'view_dial') {
          ref.read(customSelectedDayProvider.notifier).state = null;
          ref.read(dialScrubAngleProvider.notifier).state = null;
          ref.read(selectedEventProvider.notifier).state = null;
        }
      },
      onOpenEvent: (eventId) {
        final events = ref.read(allEventsProvider).value ?? [];
        try {
          final ev = events.firstWhere((e) => e.id == eventId);
          ref.read(selectedEventProvider.notifier).state = ev;
        } catch (_) {}
      },
      onOpenUpdate: (version) {
        if (mounted) {
          AppUpdateModal.show(context, checkImmediately: true);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialWidgetAction();
      _syncAndroidWidget();
      final syncNotifier = ref.read(cloudSyncControllerProvider.notifier);
      syncNotifier.syncNow();
      syncNotifier.startPolling();

      // Silent background check for updates 3s after launch (skipped in widget tests to avoid pending timers)
      final isRunningInTest = WidgetsBinding.instance.runtimeType
          .toString()
          .contains('Test');
      if (!isRunningInTest) {
        _updateCheckTimer = Timer(const Duration(seconds: 3), () async {
          if (!mounted) return;
          final hasUpdate = await ref
              .read(appUpdateControllerProvider.notifier)
              .checkForUpdates(isSilent: true);
          if (hasUpdate && mounted) {
            final updateState = ref.read(appUpdateControllerProvider);
            final version = updateState.updateInfo?.version ?? '';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                ),
                content: Row(
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Radian v$version is available!',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                action: SnackBarAction(
                  label: 'UPDATE',
                  textColor: Theme.of(context).colorScheme.primary,
                  onPressed: () {
                    AppUpdateModal.show(context);
                  },
                ),
                duration: const Duration(seconds: 7),
              ),
            );
          }
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAndroidWidget();
      final syncNotifier = ref.read(cloudSyncControllerProvider.notifier);
      syncNotifier.syncNow();
      syncNotifier.startPolling();
      ref.invalidate(healthPermissionsStatusProvider);
      ref.invalidate(batteryOptimizationStatusProvider);
    } else if (state == AppLifecycleState.paused) {
      ref.read(cloudSyncControllerProvider.notifier).stopPolling();
    }
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    _expansionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkInitialWidgetAction() async {
    final action = await AndroidWidgetService.getInitialAction();
    if (action == 'add_block' && mounted) {
      _openAddBlock();
    } else if (action == 'open_update' && mounted) {
      AppUpdateModal.show(context, checkImmediately: true);
    }
  }

  void _openAddBlock() {
    final selectedDay = ref.read(selectedDayProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      constraints: const BoxConstraints(
        maxWidth: AppLayoutConstants.modalMaxWidth,
      ),
      shape: ExpressiveShapes.modalSheet,
      builder: (_) => EventEditModal(initialDate: selectedDay),
    );
  }

  void _syncAndroidWidget() {
    final events =
        ref.read(allEventsProvider).value ??
        ref.read(dayEventsProvider).value ??
        const [];
    final activeEvent = ref.read(currentActiveEventProvider);
    final currentTime = ref.read(currentTimeProvider).value ?? DateTime.now();
    final settings = ref.read(dialSettingsProvider);
    final theme = Theme.of(context);

    ref
        .read(syncDialWidgetUseCaseProvider)
        .execute(
          events: events,
          activeEvent: activeEvent,
          currentTime: currentTime,
          settings: settings,
          theme: theme,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Keep Android Home Screen Widget in sync (throttled to minute boundaries & state changes)
    ref.listen(allEventsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(dayEventsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(currentActiveEventProvider, (_, _) => _syncAndroidWidget());
    ref.listen(dialSettingsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(currentTimeProvider, (prev, next) {
      final prevMin = prev?.value?.minute;
      final nextMin = next.value?.minute;
      if (prevMin != nextMin) {
        _syncAndroidWidget();
      }
    });

    final cloudSyncState = ref.watch(cloudSyncControllerProvider);
    final isBatteryIgnored =
        ref.watch(batteryOptimizationStatusProvider).value ?? false;
    final hasHealthPerms =
        ref.watch(healthPermissionsStatusProvider).value ?? false;
    final lastHealthSync = ref.watch(lastHealthSyncTimeProvider);
    final mcpState = ref.watch(mcpServerControllerProvider);
    final updateState = ref.watch(appUpdateControllerProvider);

    // Indicator status colors and subtitles
    final Color healthIconColor;
    final String healthSubtitle;
    if (!hasHealthPerms) {
      healthIconColor = AppColors.statusError;
      healthSubtitle = 'Permission needed (tap to connect)';
    } else if (lastHealthSync == null) {
      healthIconColor = AppColors.statusWarning;
      healthSubtitle = 'Connected · Tap to sync';
    } else {
      healthIconColor = AppColors.statusSuccess;
      healthSubtitle = 'Connected · Synced';
    }

    final Color batteryIconColor = isBatteryIgnored
        ? AppColors.statusSuccess
        : AppColors.statusWarning;
    final String batterySubtitle = isBatteryIgnored
        ? 'Unrestricted'
        : 'Restricted (tap to allow)';

    final Color syncVaultIconColor;
    final String syncVaultSubtitle;
    if (cloudSyncState.status == SyncStatus.error) {
      syncVaultIconColor = AppColors.statusError;
      syncVaultSubtitle = 'Sync error';
    } else if (cloudSyncState.isSyncing) {
      syncVaultIconColor = AppColors.statusWarning;
      syncVaultSubtitle = 'Syncing...';
    } else if (cloudSyncState.lastSyncTime != null ||
        cloudSyncState.status == SyncStatus.synced) {
      syncVaultIconColor = AppColors.statusSuccess;
      syncVaultSubtitle = 'Connected & synced';
    } else {
      syncVaultIconColor = colorScheme.primary;
      syncVaultSubtitle = 'Private vault';
    }

    final Color mcpIconColor = mcpState.isRunning
        ? AppColors.statusSuccess
        : colorScheme.primary;
    final String mcpSubtitle = mcpState.isRunning
        ? 'Active on Edge'
        : 'Cloud Edge Hub';

    final bool hasOtaUpdate =
        updateState.isAvailable || updateState.isReadyToInstall;
    final Color otaIconColor = hasOtaUpdate
        ? AppColors.statusWarning
        : (updateState.isUpToDate
              ? AppColors.statusSuccess
              : colorScheme.primary);
    final String otaSubtitle = hasOtaUpdate
        ? 'Update ready (tap to install)'
        : (updateState.isUpToDate
              ? 'v${AppStrings.appVersion} (Latest)'
              : 'Check releases');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: null,
        titleSpacing: 16.0,
        title: const RadianLogo(),
        actions: [
          // 0. Health Insights Squircle Button (Opens HealthInsightsSheet)
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                sheetAnimationStyle: _kSheetAnimationStyle,
                constraints: const BoxConstraints(
                  maxWidth: AppLayoutConstants.modalMaxWidth,
                ),
                shape: ExpressiveShapes.modalSheet,
                builder: (_) => const HealthInsightsSheet(),
              );
            },
            child: Container(
              width: AppLayoutConstants.actionButtonSize,
              height: AppLayoutConstants.actionButtonSize,
              decoration: BoxDecoration(
                color: AppColors.healthCoral.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AppColors.healthCoral.withValues(alpha: 0.4),
                  width: 1.2,
                ),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 18,
                color: AppColors.healthCoral,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 1. Calendar Squircle Button
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                sheetAnimationStyle: _kSheetAnimationStyle,
                constraints: const BoxConstraints(
                  maxWidth: AppLayoutConstants.modalMaxWidth,
                ),
                shape: ExpressiveShapes.modalSheet,
                builder: (_) => const CalendarSheet(),
              );
            },
            child: Container(
              width: AppLayoutConstants.actionButtonSize,
              height: AppLayoutConstants.actionButtonSize,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 2. Dial Settings / Custom Squircle Button (Powered by Seed Primary)
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
                sheetAnimationStyle: _kSheetAnimationStyle,
                constraints: const BoxConstraints(
                  maxWidth: AppLayoutConstants.modalMaxWidth,
                ),
                shape: ExpressiveShapes.modalSheet,
                builder: (_) => const DialSettingsModal(),
              );
            },
            child: Container(
              width: AppLayoutConstants.actionButtonSize,
              height: AppLayoutConstants.actionButtonSize,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // 3. Overflow Menu: Vault, Battery, Health, MCP, OTA, About
          PopupMenuButton<String>(
            tooltip: 'More options',
            constraints: const BoxConstraints(minWidth: 260, maxWidth: 300),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            color: colorScheme.surfaceContainerHigh,
            elevation: 4,
            onSelected: (value) async {
              HapticFeedback.lightImpact();
              if (value == 'sync_vault') {
                CloudSyncModal.show(context);
              } else if (value == 'battery') {
                final isIgnored =
                    ref.read(batteryOptimizationStatusProvider).value ?? false;
                if (isIgnored) {
                  DeviceSettingsService.openBatterySettings();
                } else {
                  DeviceSettingsService.requestIgnoreBatteryOptimization();
                }
                ref.invalidate(batteryOptimizationStatusProvider);
              } else if (value == 'health_sync') {
                final hasPerms =
                    ref.read(healthPermissionsStatusProvider).value ?? false;
                if (!hasPerms) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Opening Health Connect to grant biometric permissions...',
                        ),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                  await DeviceSettingsService.openHealthConnectSettings();
                  ref.invalidate(healthPermissionsStatusProvider);
                  ref.invalidate(healthSyncStatusProvider);
                } else {
                  final selectedDay = ref.read(selectedDayProvider);
                  final health = await ref.read(
                    dailyHealthSummaryProvider(selectedDay).future,
                  );
                  final currentEvents =
                      ref.read(dayEventsProvider).value ?? const [];
                  final newSectors = await ref
                      .read(syncHealthSessionsUseCaseProvider)
                      .execute(health: health, existingEvents: currentEvents);
                  ref.read(lastHealthSyncTimeProvider.notifier).state =
                      DateTime.now();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          newSectors.isEmpty
                              ? 'Health Connect: Up to date (0 new sessions).'
                              : 'Synced ${newSectors.length} workout/sleep session(s) to dial!',
                        ),
                        backgroundColor: colorScheme.surfaceContainerHigh,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } else if (value == 'mcp') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: false,
                  sheetAnimationStyle: _kSheetAnimationStyle,
                  constraints: const BoxConstraints(
                    maxWidth: AppLayoutConstants.modalMaxWidth,
                  ),
                  shape: ExpressiveShapes.modalSheet,
                  builder: (_) => const McpStatusSheet(),
                );
              } else if (value == 'check_updates') {
                AppUpdateModal.show(context, checkImmediately: true);
              } else if (value == 'about') {
                AboutRadianDialog.show(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'sync_vault',
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_sync_rounded,
                      size: 20,
                      color: syncVaultIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Sync & Web Pairing Vault',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            syncVaultSubtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: syncVaultIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: syncVaultIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'battery',
                child: Row(
                  children: [
                    Icon(
                      isBatteryIgnored
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_alert_rounded,
                      size: 20,
                      color: batteryIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Battery Optimization',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            batterySubtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: batteryIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: batteryIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'health_sync',
                child: Row(
                  children: [
                    Icon(
                      hasHealthPerms
                          ? Icons.health_and_safety_rounded
                          : Icons.favorite_border_rounded,
                      size: 20,
                      color: healthIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Health Connect Sync',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            healthSubtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: healthIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: healthIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mcp',
                child: Row(
                  children: [
                    Icon(Icons.hub_rounded, size: 20, color: mcpIconColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'AI & MCP Hub',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            mcpSubtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: mcpIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: mcpIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'check_updates',
                child: Row(
                  children: [
                    Icon(
                      hasOtaUpdate
                          ? Icons.system_update_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                      color: otaIconColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Over-The-Air (OTA) Updates',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            otaSubtitle,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: otaIconColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: otaIconColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'About Radian',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            'v${AppStrings.appVersion} · KSM × Tech',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            child: Container(
              width: AppLayoutConstants.actionButtonSize,
              height: AppLayoutConstants.actionButtonSize,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.more_vert_rounded,
                size: 19,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(width: 16.0),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final windowSizeClass = WindowSizeClass.fromBoxConstraints(
            constraints,
          );

          if (windowSizeClass.isThreePane) {
            // Expanded (>= 840dp): 3-Pane Adaptive Layout
            // (Large tablets, desktop mode, Samsung DeX, ChromeOS)
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: const SectographDial(),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(flex: 5, child: const ExpressiveTimeline()),
                VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(flex: 4, child: const _SupportingInsightsPane()),
              ],
            );
          } else if (windowSizeClass.isTwoPane) {
            // Medium (600dp - 840dp): 2-Pane Side-by-Side Split Layout
            // (Foldables unfolded, small tablets, landscape phones)
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: const SectographDial(),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                Expanded(flex: 6, child: const ExpressiveTimeline()),
              ],
            );
          } else {
            // Compact (< 600dp): Portrait phone vertical stacked layout
            // with interactive whole-screen / half-screen expansion handle.
            return AnimatedBuilder(
              animation: _expansionAnimation,
              child: const RepaintBoundary(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 4.0,
                    vertical: 1.0,
                  ),
                  child: SectographDial(),
                ),
              ),
              builder: (context, cachedDial) {
                final expansionProgress = _expansionAnimation.value;
                final availableHeight = constraints.maxHeight;
                // Base dial height in half-screen mode (~54% of available height)
                final baseDialHeight = (availableHeight * 0.54).clamp(
                  240.0,
                  480.0,
                );
                // Dial height shrinks from baseDialHeight down to 0
                final dialHeight = baseDialHeight * (1.0 - expansionProgress);
                final isWholeScreen = expansionProgress > 0.5;

                return Stack(
                  children: [
                    Column(
                      children: [
                        // Dial Section (Slides up and fades out cleanly)
                        if (dialHeight > 1.0)
                          SizedBox(
                            height: dialHeight,
                            child: ClipRect(
                              child: OverflowBox(
                                minHeight: baseDialHeight,
                                maxHeight: baseDialHeight,
                                alignment: Alignment.topCenter,
                                child: FadeTransition(
                                  opacity: Tween<double>(begin: 1.0, end: 0.0)
                                      .animate(
                                        CurvedAnimation(
                                          parent: _expansionController,
                                          curve: const Interval(
                                            0.0,
                                            0.6,
                                            curve: Curves.easeOut,
                                          ),
                                        ),
                                      ),
                                  child: cachedDial,
                                ),
                              ),
                            ),
                          ),

                        // Timeline Blocks Section (fills remaining space)
                        Expanded(
                          child: ExpressiveTimeline(
                            showAllEvents: isWholeScreen,
                          ),
                        ),
                      ],
                    ),

                    // Floating Dual-Pill Bar (All Blocks toggle pill + Subtasks list pill)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16.0 + MediaQuery.paddingOf(context).bottom,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _TimelineExpansionHandle(
                              key: const ValueKey('timeline_expansion_handle'),
                              isExpanded: isWholeScreen,
                              onToggle: () {
                                HapticFeedback.mediumImpact();
                                if (isWholeScreen) {
                                  _expansionController.reverse();
                                } else {
                                  _expansionController.forward();
                                }
                              },
                              onVerticalDragUpdate: (details) {
                                final delta = details.primaryDelta ?? 0.0;
                                _expansionController.value -=
                                    delta / (baseDialHeight * 0.8);
                              },
                              onVerticalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0.0;
                                if (velocity < -250) {
                                  // Fast swipe up -> expand to whole screen
                                  HapticFeedback.lightImpact();
                                  _expansionController.forward();
                                } else if (velocity > 250) {
                                  // Fast swipe down -> collapse to half screen
                                  HapticFeedback.lightImpact();
                                  _expansionController.reverse();
                                } else {
                                  if (_expansionController.value >= 0.4) {
                                    _expansionController.forward();
                                  } else {
                                    _expansionController.reverse();
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            _SubtasksListPill(
                              key: const ValueKey('subtasks_list_pill'),
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                DailySubtasksSheet.show(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          }
        },
      ),
    );
  }
}

class _SupportingInsightsPane extends ConsumerWidget {
  const _SupportingInsightsPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allEventsAsync = ref.watch(allEventsProvider);
    final events = allEventsAsync.value ?? const [];
    final cloudSyncState = ref.watch(cloudSyncControllerProvider);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Habit & Routine Insights',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              icon: const Icon(Icons.insights_rounded, size: 20),
              tooltip: 'Full Health Insights',
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  sheetAnimationStyle: _kSheetAnimationStyle,
                  constraints: const BoxConstraints(
                    maxWidth: AppLayoutConstants.modalMaxWidth,
                  ),
                  shape: ExpressiveShapes.modalSheet,
                  builder: (_) => const HealthInsightsSheet(),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: M3ActivityHeatmap.fromEvents(
              events: events,
              weeksCount: 8,
              title: 'Activity Consistency',
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.cloud_done_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '24/7 Cloud MCP Server',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            cloudSyncState.isSyncing
                                ? 'Syncing routine...'
                                : 'Live Cloud Sync Active',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: 'Sync Now',
                      onPressed: () {
                        ref
                            .read(cloudSyncControllerProvider.notifier)
                            .syncNow();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        useSafeArea: true,
                        sheetAnimationStyle: _kSheetAnimationStyle,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const McpStatusSheet(),
                      );
                    },
                    icon: const Icon(Icons.hub_rounded, size: 18),
                    label: const Text('Manage MCP Endpoints'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineExpansionHandle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const _TimelineExpansionHandle({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label: isExpanded ? 'Show dial' : 'Show all blocks created',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isExpanded
                    ? Icons.keyboard_arrow_down_rounded
                    : Icons.keyboard_arrow_up_rounded,
                size: 17,
                color: isExpanded ? colorScheme.primary : colorScheme.onSurface,
              ),
              const SizedBox(width: 6),
              Container(
                width: 24,
                height: 3.5,
                decoration: BoxDecoration(
                  color: isExpanded
                      ? colorScheme.primary.withValues(alpha: 0.85)
                      : colorScheme.outlineVariant.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isExpanded ? 'Show Dial' : 'All Blocks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: isExpanded
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubtasksListPill extends ConsumerWidget {
  final VoidCallback onTap;

  const _SubtasksListPill({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final selectedDay = ref.watch(selectedDayProvider);
    final eventsAsync = ref.watch(eventsForDateProvider(selectedDay));
    final events = eventsAsync.value ?? const <SectorEvent>[];

    int totalSubtasks = 0;
    int completedSubtasks = 0;
    for (final ev in events) {
      for (final s in ev.subtaskItems) {
        totalSubtasks++;
        if (s.isCompleted) completedSubtasks++;
      }
    }

    return Semantics(
      button: true,
      label: 'Show subtasks list',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.checklist_rounded,
                size: 17,
                color: totalSubtasks > 0
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                'Subtasks',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                  color: colorScheme.onSurface,
                ),
              ),
              if (totalSubtasks > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1.5,
                  ),
                  decoration: BoxDecoration(
                    color: completedSubtasks == totalSubtasks
                        ? Colors.green.withValues(alpha: 0.2)
                        : colorScheme.primary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completedSubtasks/$totalSubtasks',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: completedSubtasks == totalSubtasks
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
