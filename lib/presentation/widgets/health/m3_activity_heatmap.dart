import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/expressive_shapes.dart';
import '../../../domain/models/sector_event.dart';
import '../common/bouncy_pressable.dart';

/// Supported expressive tile shapes for the activity heatmap.
enum HeatmapTileShape { squircle, pebblePill, diamond, glowCircle }

/// Data model representing an individual cell in the heatmap grid.
class HeatmapDayData {
  const HeatmapDayData({
    required this.dayIndex, // 0 = Mon, 6 = Sun
    required this.weekIndex,
    required this.count, // e.g. hours or events
    required this.level, // 0 to 4
    required this.dateLabel,
  });

  final int dayIndex;
  final int weekIndex;
  final int count;
  final int level;
  final String dateLabel;
}

/// Material 3 Expressive Contribution & Activity Heatmap Component.
///
/// Implemented following [M3Heatmap.kt] from JustForPixel-ExpressiveLab:
/// - 4 Expressive Tile Shape Geometries (Squircle, Pebble Pill, Diamond, Glow Circle)
/// - Peak Day Radiant Glow and elevation depth
/// - Interactive Streak Summary Fire Badge & Date Tooltip
/// - Multi-week scrollable grid with day-of-week labels
class M3ActivityHeatmap extends StatefulWidget {
  const M3ActivityHeatmap({
    super.key,
    this.weeksData,
    this.title = 'Routine Heat Map',
    this.currentStreak = 0,
    this.totalHours = 0,
    this.tileShape = HeatmapTileShape.squircle,
  });

  factory M3ActivityHeatmap.fromEvents({
    Key? key,
    required List<SectorEvent> events,
    String title = 'Routine Heat Map',
    HeatmapTileShape tileShape = HeatmapTileShape.squircle,
    int weeksCount = 12,
  }) {
    final weeks = generateFromEvents(events, weeksCount: weeksCount);
    int totalMinutes = 0;
    for (final e in events) {
      totalMinutes += e.duration.inMinutes;
    }
    final streak = calculateStreak(events);
    return M3ActivityHeatmap(
      key: key,
      weeksData: weeks,
      title: title,
      currentStreak: streak,
      totalHours: totalMinutes ~/ 60,
      tileShape: tileShape,
    );
  }

  final List<List<HeatmapDayData>>? weeksData;
  final String title;
  final int currentStreak;
  final int totalHours;
  final HeatmapTileShape tileShape;

  static int calculateStreak(List<SectorEvent> events) {
    if (events.isEmpty) return 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    int streak = 0;
    var checkDay = today;

    final hasToday = events.any(
      (e) =>
          e.start.year == today.year &&
          e.start.month == today.month &&
          e.start.day == today.day,
    );

    if (!hasToday) {
      checkDay = today.subtract(const Duration(days: 1));
    }

    while (true) {
      final dayMatches = events.any(
        (e) =>
            e.start.year == checkDay.year &&
            e.start.month == checkDay.month &&
            e.start.day == checkDay.day,
      );
      if (dayMatches) {
        streak++;
        checkDay = checkDay.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    return streak;
  }

  static List<List<HeatmapDayData>> generateBaselineData({
    int weeksCount = 12,
    DateTime? endDate,
  }) {
    final now = endDate ?? DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final daysSinceSunday = now.weekday % 7;
    final endSunday = now.add(Duration(days: 6 - daysSinceSunday));
    final startSunday = endSunday.subtract(
      Duration(days: (weeksCount * 7) - 1),
    );

    return List.generate(weeksCount, (w) {
      return List.generate(7, (d) {
        final date = startSunday.add(Duration(days: (w * 7) + d));
        final month = months[date.month - 1];
        return HeatmapDayData(
          dayIndex: d,
          weekIndex: w,
          count: 0,
          level: 0,
          dateLabel: '$month ${date.day}',
        );
      });
    });
  }

  static List<List<HeatmapDayData>> generateFromEvents(
    List<SectorEvent> events, {
    int weeksCount = 12,
    DateTime? endDate,
  }) {
    final now = endDate ?? DateTime.now();
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final daysSinceSunday = now.weekday % 7;
    final endSunday = now.add(Duration(days: 6 - daysSinceSunday));
    final startSunday = endSunday.subtract(
      Duration(days: (weeksCount * 7) - 1),
    );

    return List.generate(weeksCount, (w) {
      return List.generate(7, (d) {
        final date = startSunday.add(Duration(days: (w * 7) + d));
        final month = months[date.month - 1];
        final count = events
            .where(
              (e) =>
                  e.start.year == date.year &&
                  e.start.month == date.month &&
                  e.start.day == date.day,
            )
            .length;

        final level = count == 0
            ? 0
            : count == 1
            ? 1
            : count <= 3
            ? 2
            : count <= 5
            ? 3
            : 4;

        return HeatmapDayData(
          dayIndex: d,
          weekIndex: w,
          count: count,
          level: level,
          dateLabel: '$month ${date.day}',
        );
      });
    });
  }

  @override
  State<M3ActivityHeatmap> createState() => _M3ActivityHeatmapState();
}

class _M3ActivityHeatmapState extends State<M3ActivityHeatmap> {
  HeatmapDayData? _selectedDay;
  late final List<List<HeatmapDayData>> _data;

  @override
  void initState() {
    super.initState();
    _data =
        widget.weeksData ??
        M3ActivityHeatmap.generateBaselineData(weeksCount: 12);
  }

  @override
  Widget build(BuildContext context) {
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.squircle(20),
        color: colorScheme.surfaceContainer,
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row with Title, Streak Fire Badge, and Total Hours
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${widget.totalHours} Total Hours Scheduled',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: ShapeDecoration(
                  shape: ExpressiveShapes.full,
                  color: AppColors.healthAccent.withAlpha(40),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 15,
                      color: AppColors.healthAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.currentStreak} Day Streak',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.healthAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Heatmap Grid: Day Labels + Scrollable Weekly Columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Day of week labels (M, T, W, T, F, S, S)
              Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final label in dayLabels)
                    SizedBox(
                      height: 16,
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),

              // Scrollable Weekly Matrix
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true, // Start at current week on right
                  child: Row(
                    children: [
                      for (final week in _data)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0),
                          child: Column(
                            children: [
                              for (final day in week)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2.0,
                                  ),
                                  child: _buildTile(day),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Interactive Tooltip Card when tile is selected
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: _selectedDay == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(top: 12.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: ShapeDecoration(
                        shape: ExpressiveShapes.squircle(
                          12,
                          side: BorderSide(
                            color: colorScheme.outlineVariant,
                            width: 1.0,
                          ),
                        ),
                        color: colorScheme.surfaceContainerHigh,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _tileColorForLevel(
                                    _selectedDay!.level,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_selectedDay!.count}h on ${_selectedDay!.dateLabel}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            _levelDescription(_selectedDay!.level),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _selectedDay!.level <= 1
                                  ? colorScheme.onSurfaceVariant
                                  : (_selectedDay!.level == 2
                                        ? const Color(0xFFE879F9)
                                        : AppColors.healthAccent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),

          // Legend Bar (Less -> More)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 6),
              for (int lvl = 0; lvl <= 4; lvl++) ...[
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: ShapeDecoration(
                    shape: ExpressiveShapes.squircle(3),
                    color: _tileColorForLevel(lvl),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTile(HeatmapDayData day) {
    final isSelected = _selectedDay == day;
    final isPeak = day.level == 4;
    final tileColor = _tileColorForLevel(day.level);

    return BouncyPressable.standard(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _selectedDay = _selectedDay == day ? null : day;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 14,
        height: 14,
        decoration: ShapeDecoration(
          shape: _resolveShape(widget.tileShape),
          color: tileColor,
          shadows: isPeak
              ? [
                  BoxShadow(
                    color: AppColors.healthAccent.withAlpha(120),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        foregroundDecoration: isSelected
            ? ShapeDecoration(
                shape: _resolveShape(
                  widget.tileShape,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                ),
              )
            : null,
      ),
    );
  }

  ShapeBorder _resolveShape(
    HeatmapTileShape shape, {
    BorderSide side = BorderSide.none,
  }) {
    switch (shape) {
      case HeatmapTileShape.squircle:
        return ExpressiveShapes.squircle(4, side: side);
      case HeatmapTileShape.pebblePill:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: side,
        );
      case HeatmapTileShape.diamond:
        return RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: side,
        );
      case HeatmapTileShape.glowCircle:
        return CircleBorder(side: side);
    }
  }

  Color _tileColorForLevel(int level) {
    switch (level) {
      case 0:
        return (Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF3D352E).withValues(alpha: 0.4)
            : const Color(0xFFDCD6CF));
      case 1:
        return const Color(0xFF3B2D54);
      case 2:
        return const Color(0xFF6A3D6E);
      case 3:
        return const Color(0xFFC04E6D);
      case 4:
        return AppColors.healthAccent;
      default:
        return AppColors.healthAccent;
    }
  }

  String _levelDescription(int level) {
    switch (level) {
      case 0:
        return 'Rest Day';
      case 1:
        return 'Light Routine';
      case 2:
        return 'Balanced Flow';
      case 3:
        return 'High Focus';
      case 4:
        return 'Peak Flow 🔥';
      default:
        return '';
    }
  }
}
