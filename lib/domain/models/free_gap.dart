import 'package:flutter/material.dart';

/// Represents an unoccupied time gap on the circular dial.
@immutable
class FreeGap {
  final DateTime start;
  final DateTime end;
  final Duration duration;
  final double startAngle;
  final double sweepAngle;

  const FreeGap({
    required this.start,
    required this.end,
    required this.duration,
    required this.startAngle,
    required this.sweepAngle,
  });

  Map<String, dynamic> toJson() => {
    'start': start.toIso8601String(),
    'end': end.toIso8601String(),
    'durationMinutes': duration.inMinutes,
    'startAngle': startAngle,
    'sweepAngle': sweepAngle,
  };
}
