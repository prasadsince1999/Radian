import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_layout_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/android_widget_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/expressive_shapes.dart';
import '../controllers/clock_controller.dart';
import '../widgets/calendar/calendar_sheet.dart';
import '../widgets/common/bouncy_pressable.dart';
import '../widgets/dialogs/about_radian_dialog.dart';
import '../widgets/dial/sectograph_dial.dart';
import '../widgets/editor/dial_settings_modal.dart';
import '../widgets/editor/event_edit_modal.dart';
import '../widgets/fab/expressive_speed_dial_fab.dart';
import '../widgets/health/health_insights_sheet.dart';
import '../widgets/mcp/mcp_status_sheet.dart';
import '../widgets/timeline/expressive_timeline.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    AndroidWidgetService.initialize(
      onAction: (action) {
        if (action == 'add_block') {
          _openAddBlock();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialWidgetAction();
      _syncAndroidWidget();
    });
  }

  Future<void> _checkInitialWidgetAction() async {
    final action = await AndroidWidgetService.getInitialAction();
    if (action == 'add_block' && mounted) {
      _openAddBlock();
    }
  }

  void _openAddBlock() {
    final selectedDay = ref.read(selectedDayProvider);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      constraints: const BoxConstraints(
        maxWidth: AppLayoutConstants.modalMaxWidth,
      ),
      shape: ExpressiveShapes.modalSheet,
      builder: (_) => EventEditModal(initialDate: selectedDay),
    );
  }

  Future<void> _quickScheduleBlock({
    required String title,
    required Duration duration,
    required String colorHex,
    required IconData icon,
    String? notes,
  }) async {
    await ref
        .read(quickScheduleBlockUseCaseProvider)
        .execute(
          title: title,
          duration: duration,
          colorHex: colorHex,
          notes: notes ?? '',
        );
    _syncAndroidWidget();
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(icon, color: colorScheme.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Scheduled: $title (${duration.inMinutes}m)',
                  style: TextStyle(
                    color: colorScheme.brightness == Brightness.dark
                        ? colorScheme.onSurface
                        : colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: colorScheme.brightness == Brightness.dark
              ? colorScheme.surfaceContainerHighest
              : colorScheme.inverseSurface,
          behavior: SnackBarBehavior.fixed,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
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

    // Keep Android Home Screen Widget in sync
    ref.listen(allEventsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(dayEventsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(currentActiveEventProvider, (_, _) => _syncAndroidWidget());
    ref.listen(dialSettingsProvider, (_, _) => _syncAndroidWidget());
    ref.listen(currentTimeProvider, (_, _) => _syncAndroidWidget());

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 12,
        title: BouncyPressable.standard(
          onTap: () {
            ref.read(dialScrubAngleProvider.notifier).state = null;
            ref.read(selectedEventProvider.notifier).state = null;
          },
          child: Text(
            AppStrings.appName,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 22,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
              height: 1.1,
            ),
          ),
        ),
        actions: [
          // 1. Calendar Squircle Button
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
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
          const SizedBox(width: 5),

          // 2. Health Squircle Button
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
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
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.favorite_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 5),

          // 3. Dial Settings / Custom Squircle Button (Powered by Seed Primary)
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                showDragHandle: false,
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
          const SizedBox(width: 5),

          // 4. AI Agent & MCP Hub Squircle Button
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
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
                Icons.hub_rounded,
                size: 17,
                color: colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 5),

          // 5. About Radian Squircle Button
          BouncyPressable.standard(
            onTap: () {
              HapticFeedback.lightImpact();
              AboutRadianDialog.show(context);
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
                Icons.info_outline_rounded,
                size: 17,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),

          const SizedBox(width: 10),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide =
              constraints.maxWidth >= AppLayoutConstants.tabletBreakpoint;

          if (isWide) {
            // Tablet / Desktop side-by-side split layout
            return Row(
              children: [
                // Left Pane: Circular Dial
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: const SectographDial(),
                  ),
                ),
                VerticalDivider(
                  width: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
                // Right Pane: Timeline & Event Agenda
                Expanded(flex: 6, child: const ExpressiveTimeline()),
              ],
            );
          } else {
            // Portrait phone vertical stacked layout
            return Column(
              children: [
                // Top Half: Circular Dial & Connected Footer Bar
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 2.0),
                    child: const SectographDial(),
                  ),
                ),
                // Bottom Half: Timeline
                Expanded(flex: 5, child: const ExpressiveTimeline()),
              ],
            );
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ExpressiveSpeedDialFab(
        key: const ValueKey('add_block_fab'),
        tooltip: 'Add Block',
        heroColor: colorScheme.primary,
        heroIconColor: colorScheme.onPrimary,
        actions: const [
          SpeedDialAction(
            id: 'event',
            icon: Icons.add_task_rounded,
            label: 'New Event',
            backgroundColor: AppColors.addBlockBg,
            foregroundColor: AppColors.addBlockText,
          ),
          SpeedDialAction(
            id: 'focus',
            icon: Icons.bolt_rounded,
            label: '90m Focus Block',
            backgroundColor: Color(0xFF6366F1),
            foregroundColor: Colors.white,
          ),
          SpeedDialAction(
            id: 'nap',
            icon: Icons.bedtime_rounded,
            label: '25m Power Nap',
            backgroundColor: Color(0xFF4338CA),
            foregroundColor: Colors.white,
          ),
          SpeedDialAction(
            id: 'workout',
            icon: Icons.fitness_center_rounded,
            label: '45m Workout',
            backgroundColor: Color(0xFFF59E0B),
            foregroundColor: Colors.white,
          ),
        ],
        onActionSelected: (id) {
          HapticFeedback.lightImpact();
          switch (id) {
            case 'event':
              _openAddBlock();
              break;
            case 'focus':
              _quickScheduleBlock(
                title: 'Deep Focus Block',
                duration: const Duration(minutes: 90),
                colorHex: '#6366F1',
                icon: Icons.bolt_rounded,
                notes: 'Material 3 Expressive Deep Focus Session',
              );
              break;
            case 'nap':
              _quickScheduleBlock(
                title: 'Restorative Power Nap',
                duration: const Duration(minutes: 25),
                colorHex: '#4338CA',
                icon: Icons.bedtime_rounded,
                notes: 'Circadian sleep debt recovery buffer',
              );
              break;
            case 'workout':
              _quickScheduleBlock(
                title: 'Workout Session',
                duration: const Duration(minutes: 45),
                colorHex: '#F59E0B',
                icon: Icons.fitness_center_rounded,
                notes: 'Cardio & Strength Training',
              );
              break;
          }
        },
      ),
    );
  }
}
