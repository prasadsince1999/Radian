import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/dial_image_renderer.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  group('Android Home Screen Widget Sync & Render Tests', () {
    test(
      'DialImageRenderer generates valid PNG byte array with latest design',
      () async {
        final now = DateTime(2026, 9, 11, 19, 30);
        final events = [
          SectorEvent(
            id: 'widget-1',
            title: 'Flexible Hours',
            start: DateTime(now.year, now.month, now.day, 17, 30),
            end: DateTime(now.year, now.month, now.day, 20, 30),
            colorHex: '#0EA5E9',
            subtasks: ['LeetCode', 'Mock Prep'],
          ),
          SectorEvent(
            id: 'widget-2',
            title: 'Cooking+Lunch',
            start: DateTime(now.year, now.month, now.day, 20, 30),
            end: DateTime(now.year, now.month, now.day, 21, 30),
            colorHex: '#10B981',
            subtasks: ['Meal Prep'],
          ),
        ];

        final pngBytes = await DialImageRenderer.renderDialPng(
          events: events,
          currentTime: now,
          settings: const DialSettings(is24HourMode: true),
          colorScheme: const ColorScheme.dark(),
          activeEvent: events[0],
          size: 512.0,
        );

        expect(pngBytes, isNotNull);
        expect(pngBytes!.length, greaterThan(1000));
        // Standard PNG header signature check: 0x89, 0x50, 0x4E, 0x47
        expect(pngBytes[0], 0x89);
        expect(pngBytes[1], 0x50);
        expect(pngBytes[2], 0x4E);
        expect(pngBytes[3], 0x47);
      },
    );
  });
}
