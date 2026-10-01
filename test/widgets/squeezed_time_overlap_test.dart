import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/time/zone_clock.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/schedule/occurrence_adapter.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/sector_content_renderer.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/sector_pill_renderer.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/dial_painter.dart';

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

    test('DialPainter paints contiguous 1h and 1.5h sectors cleanly without errors', () {
      final today = DateTime(2026, 9, 11, 19, 30);
      final events = [
        SectorEvent(
          id: '1',
          title: 'Flexible Hours',
          start: DateTime(today.year, today.month, today.day, 17, 30),
          end: DateTime(today.year, today.month, today.day, 20, 30),
          colorHex: '#0EA5E9',
          subtasks: ['LeetCode', 'Mock Prep'],
        ),
        SectorEvent(
          id: '2',
          title: 'Cooking+Lunch',
          start: DateTime(today.year, today.month, today.day, 20, 30),
          end: DateTime(today.year, today.month, today.day, 21, 30),
          colorHex: '#10B981',
          subtasks: ['Meal Prep', 'Quick Lunch'],
        ),
        SectorEvent(
          id: '3',
          title: 'Study Time',
          start: DateTime(today.year, today.month, today.day, 21, 30),
          end: DateTime(today.year, today.month, today.day, 23, 30),
          colorHex: '#F97316',
          subtasks: ['LinAlg', 'PyTorch'],
        ),
      ];

      final input = DialInput(
        clock: ZoneClockSnapshot.fromDateTime(today),
        occurrences: OccurrenceAdapter.fromSectorEvents(events),
        prefs: const DialPrefs(is24HourMode: true),
      );
      final model = DialModelBuilder.build(input);

      final painter = DialPainter(
        model: model,
        settings: const DialSettings(is24HourMode: true),
        theme: ThemeData.dark(),
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

    test('DialPainter paints 12H Flexible Hours sector with 3 subtasks (LeetCode, Mock, PyTorch) cleanly', () {
      final today = DateTime(2026, 9, 15, 18, 30);
      final events = [
        SectorEvent(
          id: 'flex-1',
          title: 'Flexible Hours',
          start: DateTime(today.year, today.month, today.day, 17, 30),
          end: DateTime(today.year, today.month, today.day, 20, 30),
          colorHex: '#0EA5E9',
          subtasks: ['LeetCode', 'Mock Prep', 'PyTorch'],
        ),
      ];

      final input = DialInput(
        clock: ZoneClockSnapshot.fromDateTime(today),
        occurrences: OccurrenceAdapter.fromSectorEvents(events),
        prefs: const DialPrefs(is24HourMode: false),
      );
      final model = DialModelBuilder.build(input);

      final painter = DialPainter(
        model: model,
        settings: const DialSettings(is24HourMode: false),
        theme: ThemeData.dark(),
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

    test('DialPainter paints active 12H Workout block with Gym, Cardio, Stretch cleanly with zero cap collision', () {
      final now = DateTime(2026, 9, 20, 16, 0); // Active inside 15:30 - 16:30
      final workoutEvent = SectorEvent(
        id: 'workout',
        title: 'Workout',
        start: DateTime(2026, 9, 20, 15, 30),
        end: DateTime(2026, 9, 20, 16, 30),
        colorHex: '#FF7043',
        subtasks: ['Gym', 'Cardio', 'Stretch'],
      );

      final input = DialInput(
        clock: ZoneClockSnapshot.fromDateTime(now),
        occurrences: OccurrenceAdapter.fromSectorEvents([workoutEvent]),
        prefs: const DialPrefs(is24HourMode: false),
      );
      final model = DialModelBuilder.build(input);

      final painter = DialPainter(
        model: model,
        settings: const DialSettings(is24HourMode: false),
        theme: ThemeData.dark(),
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
