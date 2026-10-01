import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/radian_backup_service.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';

void main() {
  group('RadianBackupService', () {
    final testEvent = SectorEvent(
      id: 'test-event-1',
      title: 'Sprint Retrospective',
      start: DateTime(2026, 10, 2, 14, 0),
      end: DateTime(2026, 10, 2, 15, 30),
      colorHex: '#3B82F6',
      category: 'Work',
      subtasks: const ['Review achievements', 'Identify bottlenecks'],
    );

    const testSettings = DialSettings(
      is24HourMode: true,
      previousBlocksCount: 2,
      futureBlocksCount: 3,
      secondaryTimeZone: 'UTC',
    );

    test('exports events and settings to versioned JSON bundle', () {
      final jsonStr = RadianBackupService.exportToJson(
        events: [testEvent],
        settings: testSettings,
      );

      final map = json.decode(jsonStr) as Map<String, dynamic>;
      expect(map['app'], 'Radian');
      expect(map['schemaVersion'], 3);
      expect(map['exportedAt'], isNotNull);
      expect(map['settings']['is24HourMode'], isTrue);
      expect(map['settings']['secondaryTimeZone'], 'UTC');

      final eventsList = map['events'] as List<dynamic>;
      expect(eventsList.length, 1);
      expect(eventsList[0]['title'], 'Sprint Retrospective');
    });

    test('round-trip import cleanly restores events and settings', () {
      final jsonStr = RadianBackupService.exportToJson(
        events: [testEvent],
        settings: testSettings,
      );

      final result = RadianBackupService.importFromJson(jsonStr);

      expect(result.isSuccess, isTrue);
      expect(result.events.length, 1);
      expect(result.events[0].id, 'test-event-1');
      expect(result.events[0].title, 'Sprint Retrospective');
      expect(result.events[0].subtasks.length, 2);

      expect(result.settings.is24HourMode, isTrue);
      expect(result.settings.secondaryTimeZone, 'UTC');
      expect(result.warnings, isEmpty);
    });

    test('handles empty or malformed JSON gracefully', () {
      final emptyResult = RadianBackupService.importFromJson('');
      expect(emptyResult.isSuccess, isFalse);
      expect(emptyResult.warnings.first, contains('empty'));

      final invalidResult = RadianBackupService.importFromJson('not json');
      expect(invalidResult.isSuccess, isFalse);
      expect(invalidResult.warnings.first, contains('Failed to parse'));
    });

    test('resolves duplicate event IDs on import with warnings', () {
      final duplicateEvents = [testEvent, testEvent.copyWith(title: 'Duplicate Event')];
      final jsonStr = RadianBackupService.exportToJson(
        events: duplicateEvents,
        settings: testSettings,
      );

      final result = RadianBackupService.importFromJson(jsonStr);

      expect(result.isSuccess, isTrue);
      expect(result.events.length, 2);
      expect(result.events[0].id, 'test-event-1');
      expect(result.events[1].id, contains('imported'));
      expect(result.warnings.length, 1);
      expect(result.warnings.first, contains('Duplicate event ID'));
    });
  });
}
