import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/domain/rules/edit_validator.dart';

void main() {
  group('EditValidator Tests', () {
    test('Rejects non-positive or less than 5 min duration', () {
      final invalid = SectorEvent(
        id: 'too-short',
        title: 'Flash',
        start: DateTime(2026, 9, 29, 10, 0),
        end: DateTime(2026, 9, 29, 10, 3), // Only 3 mins
      );

      final result = EditValidator.validateEvent(
        candidate: invalid,
        existingEvents: [],
        is24HourMode: false,
      );

      expect(result.isValid, false);
      expect(result.issues.first.kind, ValidationIssueKind.invalidDuration);
    });

    test('Detects overlap with earlier block and generates shortenEarlier and shiftToNextFree suggestions', () {
      final day = DateTime(2026, 9, 29);
      final existingEarlier = SectorEvent(
        id: 'block-early',
        title: 'Deep Coding',
        start: DateTime(day.year, day.month, day.day, 10, 0),
        end: DateTime(day.year, day.month, day.day, 11, 30),
      );

      // Candidate begins at 11:00 (overlaps last 30 mins of earlier block)
      final candidate = SectorEvent(
        id: 'candidate-meeting',
        title: 'Client Standup',
        start: DateTime(day.year, day.month, day.day, 11, 0),
        end: DateTime(day.year, day.month, day.day, 12, 0),
      );

      final result = EditValidator.validateEvent(
        candidate: candidate,
        existingEvents: [existingEarlier],
        is24HourMode: false,
      );

      expect(result.isValid, false);
      expect(result.issues.length, 1);
      expect(result.issues.first.kind, ValidationIssueKind.overlap);

      // Verify resolution suggestions
      expect(result.suggestions.length, 2);

      // Suggestion 1: Shorten earlier block to 11:00
      final shorten = result.suggestions.firstWhere(
        (s) => s.action == SuggestionAction.shortenEarlier,
      );
      expect(shorten.proposedEnd, DateTime(day.year, day.month, day.day, 11, 0));
      expect(shorten.targetEventId, 'block-early');

      // Suggestion 2: Shift candidate to 11:30
      final shift = result.suggestions.firstWhere(
        (s) => s.action == SuggestionAction.shiftToNextFree,
      );
      expect(shift.proposedStart, DateTime(day.year, day.month, day.day, 11, 30));
      expect(shift.proposedEnd, DateTime(day.year, day.month, day.day, 12, 30));
    });

    test('Subtask clamping: shrinking block from 60 to 30 mins clamps a 45-min subtask', () {
      final day = DateTime(2026, 9, 29);
      final originalStart = DateTime(day.year, day.month, day.day, 14, 0);

      // Subtask scheduled at 14:45 - 15:00
      const subtask = SubtaskItem(
        id: 'sub-1',
        parentEventId: 'parent-1',
        title: 'Code Review',
        isCompleted: false,
        startTime: TimeOfDay(hour: 14, minute: 45),
        endTime: TimeOfDay(hour: 15, minute: 0),
      );

      // Parent resized: new end is 14:30 (shrunk from 60 mins to 30 mins)
      final newEnd = DateTime(day.year, day.month, day.day, 14, 30);

      // Validate subtask against new boundaries
      final validation = EditValidator.validateSubtask(
        subtask: subtask,
        parentStart: originalStart,
        parentEnd: newEnd,
      );

      expect(validation.isValid, false);
      expect(validation.issues.first.kind, ValidationIssueKind.subtaskOutsideBlock);

      // Clamp subtask
      final clamped = EditValidator.clampSubtask(subtask, originalStart, newEnd);
      expect(clamped.startTime, const TimeOfDay(hour: 14, minute: 30));
      expect(clamped.endTime, const TimeOfDay(hour: 14, minute: 30));

      // Clamped subtask is now valid
      final revalidation = EditValidator.validateSubtask(
        subtask: clamped,
        parentStart: originalStart,
        parentEnd: newEnd,
      );
      expect(revalidation.isValid, true);
    });
  });
}
