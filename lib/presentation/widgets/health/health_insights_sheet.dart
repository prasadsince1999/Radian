import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/health_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../domain/models/health_models.dart';
import '../../controllers/clock_controller.dart';
import 'm3_activity_heatmap.dart';

class HealthInsightsSheet extends ConsumerWidget {
  const HealthInsightsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDay = ref.watch(selectedDayProvider);
    final healthAsync = ref.watch(dailyHealthSummaryProvider(selectedDay));
    final eventsAsync = ref.watch(dayEventsProvider);
    final syncStatus = ref.watch(healthSyncStatusProvider);
    final currentEvents = eventsAsync.value ?? const [];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag Handle
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
          const SizedBox(height: 16),

          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: ShapeDecoration(
                  shape: ExpressiveShapes.squircle(12),
                  color: colorScheme.primaryContainer,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily Health & Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.statusSuccess,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          syncStatus == HealthSyncStatus.connected
                              ? 'Google Health Connect Active'
                              : 'Health Connect Syncing',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Body Content
          Flexible(
            fit: FlexFit.loose,
            child: healthAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.healthAccent,
                  ),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Error loading health biometrics: $err',
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              ),
              data: (health) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Biometrics 2x2 Grid
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.directions_walk_rounded,
                              iconColor: const Color(0xFF4ADE80),
                              label: 'Steps',
                              value: '${health.steps}',
                              subValue: 'Target: 10,000',
                              progress: (health.steps / 10000).clamp(0.0, 1.0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.nightlight_round,
                              iconColor: const Color(0xFF818CF8),
                              label: 'Sleep',
                              value: health.sleepHoursFormatted,
                              subValue: health.hasSignificantSleepDebt
                                  ? '-${health.sleepDebtMinutes()}m debt'
                                  : 'Optimal recovery',
                              progress: (health.sleepDurationMinutes / 480)
                                  .clamp(0.0, 1.0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.local_fire_department_rounded,
                              iconColor: const Color(0xFFFB923C),
                              label: 'Active Burn',
                              value: '${health.activeCalories.toInt()} kcal',
                              subValue:
                                  'Total: ${health.totalCalories.toInt()} kcal',
                              progress: (health.activeCalories / 600).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _MetricCard(
                              icon: Icons.water_drop_rounded,
                              iconColor: const Color(0xFF38BDF8),
                              label: 'Hydration',
                              value:
                                  '${(health.hydrationMl / 1000).toStringAsFixed(2)} L',
                              subValue: 'Target: 2.50 L',
                              progress: (health.hydrationMl / 2500).clamp(
                                0.0,
                                1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 2. Detected Health Connect Sessions
                      Text(
                        'Detected Health Connect Sessions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 10),

                      if (health.sleepStart != null)
                        _SessionTile(
                          icon: Icons.bed_rounded,
                          color: AppColors.healthSleep,
                          title: 'Sleep Session',
                          timeRange:
                              '${_fmtTime(health.sleepStart!)} – ${_fmtTime(health.sleepEnd!)}',
                          detail:
                              '${health.sleepHoursFormatted} • ${health.deepSleepMinutes}m Deep Sleep',
                        ),

                      ...health.exerciseSessions.map(
                        (sess) => _SessionTile(
                          icon: Icons.fitness_center_rounded,
                          color: AppColors.healthWorkout,
                          title: sess.title,
                          timeRange:
                              '${_fmtTime(sess.start)} – ${_fmtTime(sess.end)}',
                          detail:
                              '${sess.caloriesBurned.toInt()} kcal • ${(sess.distanceMeters / 1000).toStringAsFixed(1)} km',
                        ),
                      ),

                      const SizedBox(height: 18),

                      // 4. Material 3 Expressive Activity Heatmap
                      M3ActivityHeatmap.fromEvents(events: currentEvents),

                      const SizedBox(height: 6),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtTime(DateTime dt) {
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subValue;
  final double progress;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subValue,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(
          16,
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
        ),
        color: colorScheme.surfaceContainer,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colorScheme.onSurface,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subValue,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: colorScheme.outlineVariant,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String timeRange;
  final String detail;

  const _SessionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.timeRange,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(
          14,
          side: BorderSide(color: colorScheme.outlineVariant, width: 1.2),
        ),
        color: colorScheme.surfaceContainer,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: ShapeDecoration(
              shape: ExpressiveShapes.squircle(10),
              color: color.withValues(alpha: 0.2),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                  ),
                ),
                Text(
                  detail,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            timeRange,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
