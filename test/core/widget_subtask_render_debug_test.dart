import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/dial_image_renderer.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  test('DialImageRenderer renders subtasks and previous blocks on widget image without errors', () async {
    final now = DateTime(2026, 9, 21, 17, 4);
    final readEvent = SectorEvent(
      id: 'read_1',
      title: 'Read',
      start: DateTime(2026, 9, 21, 16, 45),
      end: DateTime(2026, 9, 21, 18, 45),
      colorHex: '#8BC34A',
      subtasks: ['ArXiv Papers', 'Math Notes'],
    );
    final workoutEvent = SectorEvent(
      id: 'workout_1',
      title: 'Workout',
      start: DateTime(2026, 9, 21, 15, 30),
      end: DateTime(2026, 9, 21, 16, 30),
      colorHex: '#FF5722',
      subtasks: ['Gym', 'Cardio', 'Stretch'],
    );

    final events = [workoutEvent, readEvent];
    const settings = DialSettings(
      pastHoursStyle: PastHoursStyle.focusedBlock,
      previousBlocksCount: 1,
      futureBlocksCount: 2,
    );
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

    final bytes = await DialImageRenderer.renderDialPng(
      events: events,
      currentTime: now,
      settings: settings,
      colorScheme: colorScheme,
      activeEvent: readEvent,
      size: 720.0,
      showNeedle: false,
      showCenterClock: false,
    );

    expect(bytes, isNotNull);
  });

  test('DialImageRenderer at 6:57 PM renders Dinner & Meal Prep with subtasks cleanly', () async {
    final now = DateTime(
      2026,
      9,
      21,
      18,
      57,
    ); // 6:57 PM (gap before Dinner at 7:00 PM)
    final readEvent = SectorEvent(
      id: 'read_1',
      title: 'Read',
      start: DateTime(2026, 9, 21, 16, 45),
      end: DateTime(2026, 9, 21, 18, 45),
      colorHex: '#8BC34A',
      subtasks: ['ArXiv Papers', 'Math Notes'],
    );
    final dinnerEvent = SectorEvent(
      id: 'dinner_1',
      title: 'Dinner & Meal Prep',
      start: DateTime(2026, 9, 21, 19, 0),
      end: DateTime(2026, 9, 21, 20, 15),
      colorHex: '#8EC5FC',
      subtasks: ['Meal Prep', 'Dinner'],
    );
    final flexEvent = SectorEvent(
      id: 'flex_1',
      title: 'Flexible Hours',
      start: DateTime(2026, 9, 21, 20, 15),
      end: DateTime(2026, 9, 22, 0, 0),
      colorHex: '#8EA865',
      subtasks: ['LeetCode', 'Mock Prep', 'PyTorch'],
    );

    final events = [readEvent, dinnerEvent, flexEvent];
    const settings = DialSettings(
      pastHoursStyle: PastHoursStyle.focusedBlock,
      previousBlocksCount: 1,
      futureBlocksCount: 2,
    );
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.indigo);

    final bytes = await DialImageRenderer.renderDialPng(
      events: events,
      currentTime: now,
      settings: settings,
      colorScheme: colorScheme,
      activeEvent: null, // Idle gap before dinner
      size: 720.0,
      showNeedle: true,
      showCenterClock: true,
    );

    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(10000));
  });
}
