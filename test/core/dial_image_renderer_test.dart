import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sectograph_mcp/core/services/dial_image_renderer.dart';
import 'package:sectograph_mcp/data/datasources/sample_events_data.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DialImageRenderer Tests', () {
    final now = DateTime(2026, 9, 8, 14, 30);
    final events = SampleEventsData.generateDefaultSchedule(now);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.dark,
    );

    testWidgets('renders 12-hour dial into valid PNG byte buffer', (
      tester,
    ) async {
      Uint8List? pngBytes;
      await tester.runAsync(() async {
        pngBytes = await DialImageRenderer.renderDialPng(
          events: events,
          currentTime: now,
          settings: const DialSettings(is24HourMode: false),
          colorScheme: colorScheme,
          size: 200.0,
        );
      });

      expect(pngBytes, isNotNull);
      expect(pngBytes, isA<Uint8List>());
      expect(pngBytes!.length, greaterThan(100));

      // Validate standard PNG magic header: \x89PNG\r\n\x1a\n
      expect(pngBytes![0], 0x89);
      expect(pngBytes![1], 0x50); // P
      expect(pngBytes![2], 0x4E); // N
      expect(pngBytes![3], 0x47); // G
      expect(pngBytes![4], 0x0D);
      expect(pngBytes![5], 0x0A);
      expect(pngBytes![6], 0x1A);
      expect(pngBytes![7], 0x0A);
    });

    testWidgets('renders 24-hour dial into valid PNG byte buffer', (
      tester,
    ) async {
      Uint8List? pngBytes;
      await tester.runAsync(() async {
        pngBytes = await DialImageRenderer.renderDialPng(
          events: events,
          currentTime: now,
          settings: const DialSettings(is24HourMode: true),
          colorScheme: colorScheme,
          size: 200.0,
        );
      });

      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(100));
      expect(pngBytes![0], 0x89);
      expect(pngBytes![1], 0x50);
      expect(pngBytes![2], 0x4E);
      expect(pngBytes![3], 0x47);
    });

    testWidgets('renders Wave Rounded dial into valid PNG byte buffer', (
      tester,
    ) async {
      Uint8List? pngBytes;
      await tester.runAsync(() async {
        pngBytes = await DialImageRenderer.renderDialPng(
          events: events,
          currentTime: now,
          settings: const DialSettings(
            is24HourMode: false,
            dialShape: DialShape.waveRounded,
          ),
          colorScheme: colorScheme,
          size: 200.0,
        );
      });

      expect(pngBytes, isNotNull);
      expect(pngBytes!.length, greaterThan(100));
      expect(pngBytes![0], 0x89);
      expect(pngBytes![1], 0x50);
    });

    test('DialSettings pastHoursStyle serialization round-trip', () {
      const settings = DialSettings(
        pastHoursStyle: PastHoursStyle.focusedBlock,
      );
      final json = settings.toJson();
      expect(json['pastHoursStyle'], 'focusedBlock');

      final deserialized = DialSettings.fromJson(json);
      expect(deserialized.pastHoursStyle, PastHoursStyle.focusedBlock);
    });

    testWidgets('renders with PastHoursStyle.focusedBlock', (tester) async {
      Uint8List? focusedBytes;

      await tester.runAsync(() async {
        focusedBytes = await DialImageRenderer.renderDialPng(
          events: events,
          currentTime: now,
          settings: const DialSettings(
            is24HourMode: false,
            pastHoursStyle: PastHoursStyle.focusedBlock,
          ),
          colorScheme: colorScheme,
          size: 200.0,
        );
      });

      expect(focusedBytes, isNotNull);
      expect(focusedBytes![0], 0x89);
    });

    test('DialSettings dialShape serialization round-trip', () {
      const settings = DialSettings(dialShape: DialShape.waveRounded);
      final json = settings.toJson();
      expect(json['dialShape'], 'waveRounded');

      final deserialized = DialSettings.fromJson(json);
      expect(deserialized.dialShape, DialShape.waveRounded);
    });
  });
}
