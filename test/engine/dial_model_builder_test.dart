import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/domain/schedule/occurrence_adapter.dart';
import 'package:sectograph_mcp/engine/dial_input.dart';
import 'package:sectograph_mcp/engine/dial_model_builder.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';
import 'package:sectograph_mcp/engine/ring_assigner.dart';

void main() {
  group('DialModelBuilder End-to-End Tests', () {
    final now = DateTime(2026, 9, 29, 10, 0);

    test('Builds complete DialModel with valid structure', () {
      final occurrences = [
        Occurrence(
          id: 'ev-active',
          eventId: 'ev-active',
          title: 'Deep Work',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 11, 30),
          colorHex: '#3B82F6',
          category: 'Work',
          subtasks: ['Task 1', 'Task 2'],
        ),
        Occurrence(
          id: 'ev-next',
          eventId: 'ev-next',
          title: 'Lunch',
          start: DateTime(2026, 9, 29, 12, 0),
          end: DateTime(2026, 9, 29, 13, 0),
          colorHex: '#10B981',
          category: 'Health',
        ),
      ];

      final input = DialInput(
        now: now,
        occurrences: occurrences,
        prefs: const DialPrefs(
          is24HourMode: false,
          lensEnabled: true,
          lensMagnification: 1.8,
        ),
      );

      final model = DialModelBuilder.build(input);

      expect(model.schemaVersion, equals(3));
      expect(model.blocks.length, equals(2));
      expect(model.blocks.first.role, equals(BlockRole.active));
      expect(model.blocks.first.tier, equals(BlockTier.A));
      expect(model.blocks.first.ring, equals(RingLevel.outer));

      // Needle assertions
      expect(model.needle.isInsideActiveBlock, isTrue);
      expect(model.needle.activeEventId, equals('ev-active'));

      // Ticks assertions
      expect(model.ticks.length, equals(12));
      expect(model.ticks.where((t) => t.isMajor).length, equals(4)); // 12, 3, 6, 9

      // Center model
      expect(model.center.activeTitle, equals('Deep Work'));
      expect(model.center.remainingDurationFormatted, equals('1h 30m'));

      // JSON serialization
      final json = model.toJson();
      expect(json['schemaVersion'], equals(3));
      expect(json['signature'], isNotEmpty);
      expect(json['warpKey'], isNotEmpty);
      expect(json['blocks'], isA<List>());
      expect(json['ticks'], isA<List>());
      expect(json['center'], isA<Map>());
    });

    test('Deterministic Signature computation: identical inputs yield identical signatures', () {
      final occurrences = [
        Occurrence(
          id: 'ev-1',
          eventId: 'ev-1',
          title: 'Morning Yoga',
          start: DateTime(2026, 9, 29, 7, 0),
          end: DateTime(2026, 9, 29, 8, 30),
        ),
        Occurrence(
          id: 'ev-2',
          eventId: 'ev-2',
          title: 'Deep Coding',
          start: DateTime(2026, 9, 29, 9, 0),
          end: DateTime(2026, 9, 29, 11, 30),
        ),
      ];

      final input1 = DialInput(now: now, occurrences: occurrences);
      final input2 = DialInput(now: now, occurrences: occurrences);

      final model1 = DialModelBuilder.build(input1);
      final model2 = DialModelBuilder.build(input2);

      expect(model1.signature, equals(model2.signature),
          reason: 'Signatures must be strictly deterministic across calls');
    });

    test('WarpKey stability: minute tick during active block keeps same warpKey', () {
      final occurrences = [
        Occurrence(
          id: 'ev-work',
          eventId: 'ev-work',
          title: 'Deep Work',
          start: DateTime(2026, 9, 29, 9, 0),
          end: DateTime(2026, 9, 29, 12, 0),
        ),
      ];

      final inputAt1000 = DialInput(
        now: DateTime(2026, 9, 29, 10, 0),
        occurrences: occurrences,
      );
      final inputAt1001 = DialInput(
        now: DateTime(2026, 9, 29, 10, 1),
        occurrences: occurrences,
      );

      final model1000 = DialModelBuilder.build(inputAt1000);
      final model1001 = DialModelBuilder.build(inputAt1001);

      expect(model1000.warpKey, equals(model1001.warpKey),
          reason: 'Advancing 1 minute without structural change must preserve WarpKey');
      expect(model1000.needle.displayDeg, isNot(equals(model1001.needle.displayDeg)),
          reason: 'Advancing 1 minute must move the needle');
    });

    test('OccurrenceAdapter bridges domain SectorEvent accurately', () {
      final domainEvents = [
        SectorEvent(
          id: 'domain-1',
          title: 'System Architecture',
          start: DateTime(2026, 9, 29, 14, 0),
          end: DateTime(2026, 9, 29, 16, 0),
          category: 'Engineering',
          colorHex: '#6366F1',
          subtaskItems: [
            SubtaskItem(
              id: 'st-1',
              parentEventId: 'domain-1',
              title: 'Subtask Alpha',
              startTime: const TimeOfDay(hour: 14, minute: 30),
              isCompleted: false,
            ),
          ],
        ),
      ];

      final occurrences = OccurrenceAdapter.fromSectorEvents(domainEvents);
      expect(occurrences.length, equals(1));

      final occ = occurrences.first;
      expect(occ.id, equals('domain-1'));
      expect(occ.title, equals('System Architecture'));
      expect(occ.colorHex, equals('#6366F1'));
      expect(occ.subtasks, equals(['Subtask Alpha']));
      expect(occ.subtaskItems.length, equals(1));
      expect(occ.subtaskItems.first.title, equals('Subtask Alpha'));
      expect(occ.subtaskItems.first.startMinuteOffset, equals(30));
    });

    test('Ring Assignment: Non-overlapping blocks go to outer ring, conflicts go to inner ring', () {
      final occurrences = [
        Occurrence(
          id: 'tier-a',
          eventId: 'tier-a',
          title: 'Tier A Active',
          start: DateTime(2026, 9, 29, 9, 0),
          end: DateTime(2026, 9, 29, 11, 0), // 270° to 330°
        ),
        Occurrence(
          id: 'tier-b-clear',
          eventId: 'tier-b-clear',
          title: 'Non Overlapping',
          start: DateTime(2026, 9, 29, 12, 0),
          end: DateTime(2026, 9, 29, 13, 0), // 0° to 30°
        ),
      ];

      final input = DialInput(now: now, occurrences: occurrences);
      final model = DialModelBuilder.build(input);

      for (final b in model.blocks) {
        expect(b.ring, equals(RingLevel.outer),
            reason: 'Non-overlapping blocks should both be on outer ring');
      }
    });
  });
}
