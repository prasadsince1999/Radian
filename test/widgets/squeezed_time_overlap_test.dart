import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/sector_content_renderer.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/sector_pill_renderer.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/sectograph_painter.dart';

void main() {
  group('Squeezed Time Geometry and Zero-Overlap Tests', () {
    test('distillShortKeyword produces compact keywords for dial sectors', () {
      expect(
        SectorContentRenderer.distillShortKeyword('Cooking+Lunch'),
        'Lunch',
      );
      expect(SectorContentRenderer.distillShortKeyword('Quick Lunch'), 'Lunch');
      expect(SectorContentRenderer.distillShortKeyword('Afternoon Nap'), 'Nap');
      expect(
        SectorContentRenderer.distillShortKeyword('Flexible Hours'),
        'Flex',
      );
      expect(SectorContentRenderer.distillShortKeyword('Study Time'), 'Study');
      expect(
        SectorContentRenderer.distillShortKeyword('Workout or Chill'),
        'Workout',
      );
      expect(
        SectorContentRenderer.distillShortKeyword('Linear Algebra Notes'),
        'LinAlg',
      );
      expect(
        SectorContentRenderer.distillShortKeyword('PyTorch Deep Dive'),
        'PyTorch',
      );
      expect(
        SectorContentRenderer.distillShortKeyword('Transformer Architecture'),
        'Transformers',
      );
      expect(
        SectorContentRenderer.distillShortKeyword('LeetCode Practice'),
        'LeetCode',
      );
    });

    test('buildPillPath creates valid paths for ultra-squeezed cap spans', () {
      const center = Offset(180, 180);
      final squeezedPath = SectorPillRenderer.buildPillPath(
        center: center,
        rIn: 85.0,
        rOut: 160.0,
        startDeg: 120.0,
        sweepDeg: 2.4, // ultra-squeezed cap span
        cornerRadius: 4.0,
        roundStart: false,
        roundEnd: true,
      );

      expect(squeezedPath.getBounds().isEmpty, isFalse);
      expect(squeezedPath.getBounds().width, greaterThan(0));
      expect(squeezedPath.getBounds().height, greaterThan(0));
    });

    test('SectographPainter paints contiguous 1h and 1.5h sectors cleanly without errors', () {
      final today = DateTime(2026, 9, 11, 19, 30);
      final events = [
        SectorEvent(
          id: '1',
          title: 'Flexible Hours',
          start: DateTime(today.year, today.month, today.day, 17, 30),
          end: DateTime(today.year, today.month, today.day, 20, 30),
          startAngle: 262.5,
          sweepAngle: 45.0,
          colorHex: '#0EA5E9',
          subtasks: ['LeetCode', 'Mock Prep'],
        ),
        SectorEvent(
          id: '2',
          title: 'Cooking+Lunch',
          start: DateTime(today.year, today.month, today.day, 20, 30),
          end: DateTime(today.year, today.month, today.day, 21, 30),
          startAngle: 307.5,
          sweepAngle: 15.0, // 1 hour = 15° in 24h
          colorHex: '#10B981',
          subtasks: ['Meal Prep', 'Quick Lunch'],
        ),
        SectorEvent(
          id: '3',
          title: 'Study Time',
          start: DateTime(today.year, today.month, today.day, 21, 30),
          end: DateTime(today.year, today.month, today.day, 23, 30),
          startAngle: 322.5,
          sweepAngle: 30.0,
          colorHex: '#F97316',
          subtasks: ['LinAlg', 'PyTorch'],
        ),
      ];

      final painter = SectographPainter(
        events: events,
        selectedEvent: null,
        activeEvent: events[0],
        currentTime: today,
        scrubAngle: null,
        settings: const DialSettings(is24HourMode: true),
        colorScheme: const ColorScheme.dark(),
        showCenterClock: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(360, 360);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('SectographPainter paints 12H Flexible Hours sector with 3 subtasks (LeetCode, Mock, PyTorch) cleanly', () {
      final today = DateTime(2026, 9, 15, 18, 30);
      final events = [
        SectorEvent(
          id: 'flex-1',
          title: 'Flexible Hours',
          start: DateTime(today.year, today.month, today.day, 17, 30),
          end: DateTime(today.year, today.month, today.day, 20, 30),
          startAngle: 75.0, // 5:30 on 12h dial (30 deg/h * 5.5 = 165 deg from 12 or standard dial)
          sweepAngle: 90.0, // 3 hours = 90°
          colorHex: '#0EA5E9',
          subtasks: ['LeetCode', 'Mock Prep', 'PyTorch'],
        ),
      ];

      final painter = SectographPainter(
        events: events,
        selectedEvent: null,
        activeEvent: events[0],
        currentTime: today,
        scrubAngle: null,
        settings: const DialSettings(is24HourMode: false),
        colorScheme: const ColorScheme.dark(),
        showCenterClock: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(380, 380);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('SectographPainter paints active 12H Workout block with Gym, Cardio, Stretch cleanly with zero cap collision', () {
      final now = DateTime(2026, 9, 20, 16, 0); // Active inside 15:30 - 16:30
      final workoutEvent = SectorEvent(
        id: 'workout',
        title: 'Workout',
        start: DateTime(2026, 9, 20, 15, 30),
        end: DateTime(2026, 9, 20, 16, 30),
        startAngle: 105.0,
        sweepAngle: 72.0, // Stretched
        colorHex: '#FF7043',
        subtasks: ['Gym', 'Cardio', 'Stretch'],
      );

      final painter = SectographPainter(
        events: [workoutEvent],
        selectedEvent: null,
        activeEvent: workoutEvent,
        currentTime: now,
        scrubAngle: null,
        settings: const DialSettings(is24HourMode: false),
        colorScheme: const ColorScheme.dark(),
        showCenterClock: true,
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(380, 380);

      expect(() => painter.paint(canvas, size), returnsNormally);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
  });
}
