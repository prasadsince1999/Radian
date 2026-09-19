import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Clean visual timeline slider for scheduling a micro-subtask within its parent macro time block.
///
/// Layout:
/// - Left column: Parent block start time formatted vertically with vertical accent line.
/// - Right column: Parent block end time formatted vertically with vertical accent line.
/// - Middle track: Horizontal visual track representing parent duration with a draggable,
///   adjustable capsule/pill representing the subtask.
class SubtaskTimelineSlider extends StatefulWidget {
  final TimeOfDay parentStartTime;
  final TimeOfDay parentEndTime;
  final TimeOfDay subtaskStartTime;
  final TimeOfDay subtaskEndTime;
  final Color parentColor;
  final bool is24Hour;
  final String? parentTitle;
  final void Function(TimeOfDay start, TimeOfDay end) onChanged;

  const SubtaskTimelineSlider({
    super.key,
    required this.parentStartTime,
    required this.parentEndTime,
    required this.subtaskStartTime,
    required this.subtaskEndTime,
    required this.parentColor,
    required this.is24Hour,
    this.parentTitle,
    required this.onChanged,
  });

  @override
  State<SubtaskTimelineSlider> createState() => _SubtaskTimelineSliderState();
}

enum _DragTarget { none, startHandle, endHandle, pillMove }

class _SubtaskTimelineSliderState extends State<SubtaskTimelineSlider> {
  _DragTarget _activeDrag = _DragTarget.none;
  double _dragStartX = 0.0;
  int _initialStartOffset = 0;
  int _initialEndOffset = 0;

  static int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  int get _parentSpan {
    final s = _toMinutes(widget.parentStartTime);
    final e = _toMinutes(widget.parentEndTime);
    if (e <= s) {
      return (e + 1440) - s;
    }
    return e - s;
  }

  int _getOffset(TimeOfDay t, int totalSpan) {
    final pStart = _toMinutes(widget.parentStartTime);
    final tm = _toMinutes(t);
    var diff = tm - pStart;
    while (diff < 0) {
      diff += 1440;
    }
    while (diff > 1440) {
      diff -= 1440;
    }
    return diff.clamp(0, totalSpan);
  }

  TimeOfDay _timeFromOffset(int offsetMinutes) {
    final pStart = _toMinutes(widget.parentStartTime);
    final raw = (pStart + offsetMinutes) % 1440;
    return TimeOfDay(hour: raw ~/ 60, minute: raw % 60);
  }

  int _snapTo5(int value, int min, int max) {
    final snapped = ((value + 2) ~/ 5) * 5;
    return snapped.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = widget.parentColor;

    final span = _parentSpan.clamp(15, 1440);
    var startOffset = _getOffset(widget.subtaskStartTime, span);
    var endOffset = _getOffset(widget.subtaskEndTime, span);

    if (endOffset <= startOffset) {
      endOffset = (startOffset + 15).clamp(0, span);
    }
    final subtaskDurationMinutes = endOffset - startOffset;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 17, color: accent),
              const SizedBox(width: 8),
              Text(
                'SUBTASK TIMING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$subtaskDurationMinutes min',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Rectangle with Left & Right Vertical Times and Middle Track
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.45,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Left Vertical Time Box (Parent Start)
                _buildVerticalTimeBox(
                  context: context,
                  time: widget.parentStartTime,
                  label: 'START',
                  accentColor: accent,
                  colorScheme: colorScheme,
                ),
                const SizedBox(width: 6),
                Container(
                  width: 2.5,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),

                // Middle Draggable Capsule Slider Track
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final trackWidth = constraints.maxWidth;
                      const trackHeight = 64.0;
                      const minPillWidth = 54.0;

                      final startFrac = (startOffset / span).clamp(0.0, 1.0);
                      final endFrac = (endOffset / span).clamp(0.0, 1.0);

                      final rawStartX = startFrac * trackWidth;
                      final rawEndX = endFrac * trackWidth;
                      final pillWidth = (rawEndX - rawStartX).clamp(
                        minPillWidth,
                        trackWidth,
                      );
                      final pillLeft = rawStartX.clamp(
                        0.0,
                        (trackWidth - pillWidth).clamp(0.0, trackWidth),
                      );

                      final isStartDragging =
                          _activeDrag == _DragTarget.startHandle ||
                          _activeDrag == _DragTarget.pillMove;
                      final isEndDragging =
                          _activeDrag == _DragTarget.endHandle ||
                          _activeDrag == _DragTarget.pillMove;

                      final hasRoomForCapText = pillWidth >= 76.0;
                      final capWidth = hasRoomForCapText ? 22.0 : 12.0;
                      final startCapStr = _formatCapTime(
                        widget.subtaskStartTime,
                        includePeriod: false,
                      );
                      final endCapStr = _formatCapTime(
                        widget.subtaskEndTime,
                        includePeriod: false,
                      );

                      final isDark =
                          ThemeData.estimateBrightnessForColor(accent) ==
                          Brightness.dark;
                      final onAccentColor = isDark
                          ? Colors.white
                          : Colors.black87;

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (details) {
                          final localX = details.localPosition.dx;
                          _dragStartX = localX;
                          _initialStartOffset = startOffset;
                          _initialEndOffset = endOffset;

                          final halfPill = pillWidth / 2.0;
                          final startHitRange = math.min(capWidth + 12.0, halfPill);
                          final endHitRange = math.min(capWidth + 12.0, halfPill);

                          // Hit detection prioritizing edge caps then pill body
                          if ((localX - pillLeft).abs() <= 20 ||
                              (localX >= pillLeft &&
                                  localX <= pillLeft + startHitRange)) {
                            _activeDrag = _DragTarget.startHandle;
                          } else if ((localX - (pillLeft + pillWidth)).abs() <=
                                  20 ||
                              (localX >= (pillLeft + pillWidth) - endHitRange &&
                                  localX <= pillLeft + pillWidth)) {
                            _activeDrag = _DragTarget.endHandle;
                          } else if (localX >= pillLeft &&
                              localX <= pillLeft + pillWidth) {
                            _activeDrag = _DragTarget.pillMove;
                          } else {
                            // Tap outside: snap nearest edge
                            if (localX < pillLeft) {
                              _activeDrag = _DragTarget.startHandle;
                              final newStartFrac = (localX / trackWidth).clamp(
                                0.0,
                                1.0,
                              );
                              final newStart = _snapTo5(
                                (newStartFrac * span).round(),
                                0,
                                endOffset - 5,
                              );
                              widget.onChanged(
                                _timeFromOffset(newStart),
                                _timeFromOffset(endOffset),
                              );
                            } else {
                              _activeDrag = _DragTarget.endHandle;
                              final newEndFrac = (localX / trackWidth).clamp(
                                0.0,
                                1.0,
                              );
                              final newEnd = _snapTo5(
                                (newEndFrac * span).round(),
                                startOffset + 5,
                                span,
                              );
                              widget.onChanged(
                                _timeFromOffset(startOffset),
                                _timeFromOffset(newEnd),
                              );
                            }
                          }
                          HapticFeedback.selectionClick();
                        },
                        onHorizontalDragUpdate: (details) {
                          final deltaPx =
                              details.localPosition.dx - _dragStartX;
                          final deltaMins = (deltaPx / trackWidth * span)
                              .round();

                          if (_activeDrag == _DragTarget.startHandle) {
                            final candidate = _initialStartOffset + deltaMins;
                            final newStart = _snapTo5(
                              candidate,
                              0,
                              endOffset - 5,
                            );
                            if (newStart != startOffset) {
                              HapticFeedback.selectionClick();
                              widget.onChanged(
                                _timeFromOffset(newStart),
                                _timeFromOffset(endOffset),
                              );
                            }
                          } else if (_activeDrag == _DragTarget.endHandle) {
                            final candidate = _initialEndOffset + deltaMins;
                            final newEnd = _snapTo5(
                              candidate,
                              startOffset + 5,
                              span,
                            );
                            if (newEnd != endOffset) {
                              HapticFeedback.selectionClick();
                              widget.onChanged(
                                _timeFromOffset(startOffset),
                                _timeFromOffset(newEnd),
                              );
                            }
                          } else if (_activeDrag == _DragTarget.pillMove) {
                            final duration =
                                _initialEndOffset - _initialStartOffset;
                            final candidateStart =
                                _initialStartOffset + deltaMins;
                            final newStart = _snapTo5(
                              candidateStart,
                              0,
                              span - duration,
                            );
                            final newEnd = newStart + duration;
                            if (newStart != startOffset ||
                                newEnd != endOffset) {
                              HapticFeedback.selectionClick();
                              widget.onChanged(
                                _timeFromOffset(newStart),
                                _timeFromOffset(newEnd),
                              );
                            }
                          }
                        },
                        onHorizontalDragEnd: (_) {
                          setState(() => _activeDrag = _DragTarget.none);
                        },
                        onHorizontalDragCancel: () {
                          setState(() => _activeDrag = _DragTarget.none);
                        },
                        child: SizedBox(
                          height: trackHeight,
                          child: Stack(
                            alignment: Alignment.centerLeft,
                            children: [
                              // Background Track Bar
                              Container(
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),

                              // Interactive Draggable Subtask Capsule Pill with Boundary Time Caps
                              Positioned(
                                left: pillLeft,
                                width: pillWidth,
                                top: 2,
                                bottom: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: accent,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent.withValues(alpha: 0.35),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // 1. Left Edge: Start Time Boundary Cap (Vertical, matching sector dial edge)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          width: capWidth,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isStartDragging
                                                ? Color.lerp(
                                                    accent,
                                                    Colors.white,
                                                    0.32,
                                                  )!
                                                : Color.lerp(
                                                    accent,
                                                    Colors.black,
                                                    0.42,
                                                  )!,
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                                  left: Radius.circular(20),
                                                ),
                                            border: isStartDragging
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  )
                                                : null,
                                          ),
                                          child: Center(
                                            child: hasRoomForCapText
                                                ? FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: RotatedBox(
                                                      quarterTurns: 3,
                                                      child: Text(
                                                        startCapStr,
                                                        style: TextStyle(
                                                          fontSize: isStartDragging
                                                              ? 11.0
                                                              : 10.0,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: -0.2,
                                                          fontFeatures: const [
                                                            FontFeature.tabularFigures(),
                                                          ],
                                                          color: isStartDragging
                                                              ? Colors.black87
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 2.5,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.85),
                                                      borderRadius:
                                                          BorderRadius.circular(1.5),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),

                                      // 2. Middle: Subtask Duration (Smoothly scales down when squeezed, never disappears)
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 2,
                                          ),
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                subtaskDurationMinutes >= 60
                                                    ? (pillWidth < 90
                                                          ? '${subtaskDurationMinutes ~/ 60}h${subtaskDurationMinutes % 60 > 0 ? '${subtaskDurationMinutes % 60}' : ''}'
                                                          : '${subtaskDurationMinutes ~/ 60}h${subtaskDurationMinutes % 60 > 0 ? ' ${subtaskDurationMinutes % 60}m' : ''}')
                                                    : '${subtaskDurationMinutes}m',
                                                style: TextStyle(
                                                  fontSize: 12.0,
                                                  fontWeight: FontWeight.w900,
                                                  color: onAccentColor,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.clip,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // 3. Right Edge: End Time Boundary Cap (Vertical, matching sector dial edge)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          width: capWidth,
                                          height: double.infinity,
                                          decoration: BoxDecoration(
                                            color: isEndDragging
                                                ? Color.lerp(
                                                    accent,
                                                    Colors.white,
                                                    0.32,
                                                  )!
                                                : Color.lerp(
                                                    accent,
                                                    Colors.black,
                                                    0.42,
                                                  )!,
                                            borderRadius:
                                                const BorderRadius.horizontal(
                                                  right: Radius.circular(20),
                                                ),
                                            border: isEndDragging
                                                ? Border.all(
                                                    color: Colors.white,
                                                    width: 1.5,
                                                  )
                                                : null,
                                          ),
                                          child: Center(
                                            child: hasRoomForCapText
                                                ? FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: RotatedBox(
                                                      quarterTurns: 3,
                                                      child: Text(
                                                        endCapStr,
                                                        style: TextStyle(
                                                          fontSize: isEndDragging
                                                              ? 11.0
                                                              : 10.0,
                                                          fontWeight: FontWeight.w900,
                                                          letterSpacing: -0.2,
                                                          fontFeatures: const [
                                                            FontFeature.tabularFigures(),
                                                          ],
                                                          color: isEndDragging
                                                              ? Colors.black87
                                                              : Colors.white,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Container(
                                                    width: 2.5,
                                                    height: 22,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(alpha: 0.85),
                                                      borderRadius:
                                                          BorderRadius.circular(1.5),
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(width: 6),
                Container(
                  width: 2.5,
                  height: 58,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),

                // Right Vertical Time Box (Parent End)
                _buildVerticalTimeBox(
                  context: context,
                  time: widget.parentEndTime,
                  label: 'END',
                  accentColor: accent,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatCapTime(TimeOfDay time, {required bool includePeriod}) {
    if (widget.is24Hour) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    if (includePeriod) {
      final period = time.period == DayPeriod.am ? 'AM' : 'PM';
      return '$h:$m $period';
    }
    return '$h:$m';
  }

  Widget _buildVerticalTimeBox({
    required BuildContext context,
    required TimeOfDay time,
    required String label,
    required Color accentColor,
    required ColorScheme colorScheme,
  }) {
    final hourStr = widget.is24Hour
        ? time.hour.toString().padLeft(2, '0')
        : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod).toString();
    final minStr = time.minute.toString().padLeft(2, '0');
    final periodStr = widget.is24Hour
        ? ''
        : (time.period == DayPeriod.am ? 'AM' : 'PM');

    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            '$hourStr:$minStr',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          if (periodStr.isNotEmpty)
            Text(
              periodStr,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}
