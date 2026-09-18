import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_layout_constants.dart';
import '../../core/layout/window_size_class.dart';
import '../../core/services/android_widget_service.dart';
import '../../core/theme/expressive_shapes.dart';
import '../controllers/clock_controller.dart';
import '../controllers/cloud_sync_controller.dart';
import '../widgets/calendar/calendar_sheet.dart';
import '../widgets/common/bouncy_pressable.dart';
import '../widgets/common/radian_logo.dart';
import '../widgets/dialogs/about_radian_dialog.dart';
import '../widgets/dial/sectograph_dial.dart';
import '../widgets/editor/dial_settings_modal.dart';
import '../widgets/editor/event_edit_modal.dart';
import '../widgets/health/health_insights_sheet.dart';
import '../widgets/health/m3_activity_heatmap.dart';
import '../widgets/mcp/mcp_status_sheet.dart';
import '../widgets/timeline/expressive_timeline.dart';

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
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialWidgetAction();
      _syncAndroidWidget();
      final syncNotifier = ref.read(cloudSyncControllerProvider.notifier);
      syncNotifier.syncNow();
      syncNotifier.startPolling();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncAndroidWidget();
      final syncNotifier = ref.read(cloudSyncControllerProvider.notifier);
      syncNotifier.syncNow();
      syncNotifier.startPolling();
    } else if (state == AppLifecycleState.paused) {
      ref.read(cloudSyncControllerProvider.notifier).stopPolling();
    }
  }

  @override
  void dispose() {
    _expansionController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
    final settings = ref.watch(dialSettingsProvider);

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
          // 0. Quick 12H Indian / 24H Global Mode Toggle Pill
          BouncyPressable.standard(
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
              height: AppLayoutConstants.actionButtonSize,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: settings.is24HourMode
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: settings.is24HourMode
                      ? colorScheme.primary.withValues(alpha: 0.45)
                      : colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    settings.is24HourMode ? '24H' : '12H',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: settings.is24HourMode
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    settings.is24HourMode ? '🌐' : '🇮🇳',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
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

          // 3. Overflow Menu: Health, MCP Hub, About
          PopupMenuButton<String>(
            tooltip: 'More options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                width: 1.0,
              ),
            ),
            color: colorScheme.surfaceContainerHigh,
            elevation: 4,
            onSelected: (value) {
              HapticFeedback.lightImpact();
              if (value == 'health') {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: false,
                  sheetAnimationStyle: _kSheetAnimationStyle,
                  constraints: const BoxConstraints(
                    maxWidth: AppLayoutConstants.modalMaxWidth,
                  ),
                  shape: ExpressiveShapes.modalSheet,
                  builder: (_) => const HealthInsightsSheet(),
                );
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
              } else if (value == 'preset_indian') {
                ref
                    .read(dialSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(is24HourMode: false));
                ref.read(eventRepositoryProvider).loadPreset('indian_12h');
              } else if (value == 'preset_intl') {
                ref
                    .read(dialSettingsProvider.notifier)
                    .updateSettings(settings.copyWith(is24HourMode: true));
                ref
                    .read(eventRepositoryProvider)
                    .loadPreset('international_24h');
              } else if (value == 'about') {
                AboutRadianDialog.show(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'preset_indian',
                child: Row(
                  children: [
                    const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Text(
                      'Load Indian Routine (12H)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'preset_intl',
                child: Row(
                  children: [
                    const Text('🌐', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 12),
                    Text(
                      'Load Global Circadian (24H)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'health',
                child: Row(
                  children: [
                    Icon(
                      Icons.favorite_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Health Insights',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'mcp',
                child: Row(
                  children: [
                    Icon(
                      Icons.hub_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'AI & MCP Hub',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'about',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'About Radian',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
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
                size: 18,
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
                  padding: EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 2.0),
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

                    // Floating Ergonomic Handle Bar (Floating at bottom above the blocks)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 16.0,
                      child: Center(
                        child: _TimelineExpansionHandle(
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
                  backgroundColor: Colors.transparent,
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
