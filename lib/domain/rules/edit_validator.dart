import 'package:flutter/material.dart';

import '../models/sector_event.dart';
import '../models/subtask_item.dart';
import 'block_budget.dart';

enum ValidationIssueKind {
  /// The event duration is non-positive or less than 5 minutes.
  invalidDuration,

  /// The dial window capacity has been exceeded.
  budgetFull,

  /// Two blocks collide or overlap in time on the same dial day.
  overlap,

  /// A subtask's scheduled interval falls outside the parent block boundaries.
  subtaskOutsideBlock,
}

enum SuggestionAction {
  /// Shorten the earlier colliding block's end time to the candidate's start time.
  shortenEarlier,

  /// Shift the candidate block's start time to the colliding block's end time.
  shiftToNextFree,

  /// Clamp the subtask interval to fit completely within the parent block.
  clampSubtask,
}

@immutable
class ValidationSuggestion {
  final SuggestionAction action;
  final String label;
  final String description;
  final DateTime? proposedStart;
  final DateTime? proposedEnd;
  final String? targetEventId;

  const ValidationSuggestion({
    required this.action,
    required this.label,
    required this.description,
    this.proposedStart,
    this.proposedEnd,
    this.targetEventId,
  });

  Map<String, dynamic> toJson() => {
        'action': action.name,
        'label': label,
        'description': description,
        if (proposedStart != null) 'proposedStart': proposedStart!.toIso8601String(),
        if (proposedEnd != null) 'proposedEnd': proposedEnd!.toIso8601String(),
        if (targetEventId != null) 'targetEventId': targetEventId,
      };

  @override
  String toString() => 'ValidationSuggestion($action: $label)';
}

@immutable
class ValidationIssue {
  final ValidationIssueKind kind;
  final String message;
  final String? conflictingEventId;
  final String? conflictingEventTitle;

  const ValidationIssue({
    required this.kind,
    required this.message,
    this.conflictingEventId,
    this.conflictingEventTitle,
  });

  Map<String, dynamic> toJson() => {
        'kind': kind.name,
        'message': message,
        if (conflictingEventId != null) 'conflictingEventId': conflictingEventId,
        if (conflictingEventTitle != null) 'conflictingEventTitle': conflictingEventTitle,
      };

  @override
  String toString() => 'ValidationIssue($kind: $message)';
}

@immutable
class ValidationResult {
  final bool isValid;
  final List<ValidationIssue> issues;
  final List<ValidationSuggestion> suggestions;

  const ValidationResult({
    required this.isValid,
    this.issues = const [],
    this.suggestions = const [],
  });

  const ValidationResult.ok()
      : isValid = true,
        issues = const [],
        suggestions = const [];

  factory ValidationResult.conflict({
    required List<ValidationIssue> issues,
    List<ValidationSuggestion> suggestions = const [],
  }) {
    return ValidationResult(
      isValid: false,
      issues: issues,
      suggestions: suggestions,
    );
  }

  Map<String, dynamic> toJson() => {
        'isValid': isValid,
        'issues': issues.map((i) => i.toJson()).toList(),
        'suggestions': suggestions.map((s) => s.toJson()).toList(),
      };
}

/// Domain validator making invalid scheduling states unrepresentable (I1, I3, RC2, RC3).
///
/// Enforces:
/// 1. Positive duration (minimum 5 minutes).
/// 2. Block budget compliance per dial window.
/// 3. Strict non-overlapping invariant for stored blocks on the same day.
/// 4. Subtask containment within parent block bounds.
class EditValidator {
  const EditValidator._();

  static const Duration minEventDuration = Duration(minutes: 5);

  /// Validates a candidate event against existing stored events and dial budget.
  static ValidationResult validateEvent({
    required SectorEvent candidate,
    required List<SectorEvent> existingEvents,
    required bool is24HourMode,
  }) {
    final issues = <ValidationIssue>[];
    final suggestions = <ValidationSuggestion>[];

    // 1. Validate duration
    if (!candidate.end.isAfter(candidate.start) || candidate.duration < minEventDuration) {
      issues.add(
        const ValidationIssue(
          kind: ValidationIssueKind.invalidDuration,
          message: 'Block duration must be at least 5 minutes and end time must be after start time.',
        ),
      );
      return ValidationResult.conflict(issues: issues);
    }

    // 2. Validate block budget
    final budgetCheck = BlockBudget.check(
      existingEvents: existingEvents,
      candidate: candidate,
      is24HourMode: is24HourMode,
    );
    if (!budgetCheck.allowed) {
      issues.add(
        ValidationIssue(
          kind: ValidationIssueKind.budgetFull,
          message: budgetCheck.reason ?? 'Dial capacity budget full.',
        ),
      );
    }

    // 3. Validate subtask containment
    for (final subtask in candidate.subtaskItems) {
      final subtaskCheck = validateSubtask(
        subtask: subtask,
        parentStart: candidate.start,
        parentEnd: candidate.end,
      );
      if (!subtaskCheck.isValid) {
        issues.addAll(subtaskCheck.issues);
        suggestions.addAll(subtaskCheck.suggestions);
      }
    }

    // 4. Overlap detection against existing events
    final candidateDay = DateTime(
      candidate.start.year,
      candidate.start.month,
      candidate.start.day,
    );

    for (final other in existingEvents) {
      if (other.id == candidate.id) continue;

      final otherDay = DateTime(
        other.start.year,
        other.start.month,
        other.start.day,
      );
      if (candidateDay != otherDay) continue;

      // Check overlap: startA < endB && endA > startB
      final hasOverlap = candidate.start.isBefore(other.end) && candidate.end.isAfter(other.start);

      if (hasOverlap) {
        issues.add(
          ValidationIssue(
            kind: ValidationIssueKind.overlap,
            message: 'Collides with existing block "${other.title}" (${_formatTime(other.start)} - ${_formatTime(other.end)}).',
            conflictingEventId: other.id,
            conflictingEventTitle: other.title,
          ),
        );

        // Compute resolution suggestions:
        // A. If other started earlier and overlaps candidate's start:
        // Offer to shorten other's end to candidate's start
        if (other.start.isBefore(candidate.start)) {
          suggestions.add(
            ValidationSuggestion(
              action: SuggestionAction.shortenEarlier,
              label: 'Shorten "${other.title}"',
              description: 'Trim "${other.title}" to end at ${_formatTime(candidate.start)} so "${candidate.title}" can begin.',
              proposedStart: other.start,
              proposedEnd: candidate.start,
              targetEventId: other.id,
            ),
          );
        }

        // B. Offer to shift candidate to immediately after other's end
        final candidateDuration = candidate.duration;
        final shiftedStart = other.end;
        final shiftedEnd = shiftedStart.add(candidateDuration);
        suggestions.add(
          ValidationSuggestion(
            action: SuggestionAction.shiftToNextFree,
            label: 'Shift to ${_formatTime(shiftedStart)}',
            description: 'Move "${candidate.title}" to start right after "${other.title}" (${_formatTime(shiftedStart)} - ${_formatTime(shiftedEnd)}).',
            proposedStart: shiftedStart,
            proposedEnd: shiftedEnd,
            targetEventId: candidate.id,
          ),
        );
      }
    }

    if (issues.isNotEmpty) {
      return ValidationResult.conflict(
        issues: issues,
        suggestions: suggestions,
      );
    }

    return const ValidationResult.ok();
  }

  /// Validates that a subtask's start/end times fall within parent block bounds.
  static ValidationResult validateSubtask({
    required SubtaskItem subtask,
    required DateTime parentStart,
    required DateTime parentEnd,
  }) {
    if (subtask.startTime == null && subtask.endTime == null) {
      return const ValidationResult.ok();
    }

    final parentStartMins = parentStart.hour * 60 + parentStart.minute;
    final parentEndMins = parentEnd.hour * 60 + parentEnd.minute;

    bool isOutside = false;
    TimeOfDay? clampedStart = subtask.startTime;
    TimeOfDay? clampedEnd = subtask.endTime;

    if (subtask.startTime != null) {
      final subStartMins = subtask.startTime!.hour * 60 + subtask.startTime!.minute;
      if (subStartMins < parentStartMins) {
        isOutside = true;
        clampedStart = TimeOfDay(hour: parentStart.hour, minute: parentStart.minute);
      }
    }

    if (subtask.endTime != null) {
      final subEndMins = subtask.endTime!.hour * 60 + subtask.endTime!.minute;
      if (subEndMins > parentEndMins) {
        isOutside = true;
        clampedEnd = TimeOfDay(hour: parentEnd.hour, minute: parentEnd.minute);
      }
    }

    if (isOutside) {
      return ValidationResult.conflict(
        issues: [
          ValidationIssue(
            kind: ValidationIssueKind.subtaskOutsideBlock,
            message: 'Subtask "${subtask.title}" exceeds parent block interval (${_formatTime(parentStart)} - ${_formatTime(parentEnd)}).',
          ),
        ],
        suggestions: [
          ValidationSuggestion(
            action: SuggestionAction.clampSubtask,
            label: 'Clamp subtask',
            description: 'Clamp "${subtask.title}" to within parent block interval.',
            proposedStart: clampedStart != null
                ? DateTime(parentStart.year, parentStart.month, parentStart.day, clampedStart.hour, clampedStart.minute)
                : null,
            proposedEnd: clampedEnd != null
                ? DateTime(parentEnd.year, parentEnd.month, parentEnd.day, clampedEnd.hour, clampedEnd.minute)
                : null,
          ),
        ],
      );
    }

    return const ValidationResult.ok();
  }

  /// Clamps subtasks to fit strictly within parent block boundaries.
  static SubtaskItem clampSubtask(
    SubtaskItem subtask,
    DateTime parentStart,
    DateTime parentEnd,
  ) {
    if (subtask.startTime == null && subtask.endTime == null) return subtask;

    final parentStartMins = parentStart.hour * 60 + parentStart.minute;
    final parentEndMins = parentEnd.hour * 60 + parentEnd.minute;

    TimeOfDay? newStart = subtask.startTime;
    TimeOfDay? newEnd = subtask.endTime;

    if (newStart != null) {
      final subStartMins = newStart.hour * 60 + newStart.minute;
      if (subStartMins < parentStartMins) {
        newStart = TimeOfDay(hour: parentStart.hour, minute: parentStart.minute);
      } else if (subStartMins > parentEndMins) {
        newStart = TimeOfDay(hour: parentEnd.hour, minute: parentEnd.minute);
      }
    }

    if (newEnd != null) {
      final subEndMins = newEnd.hour * 60 + newEnd.minute;
      if (subEndMins > parentEndMins) {
        newEnd = TimeOfDay(hour: parentEnd.hour, minute: parentEnd.minute);
      } else if (subEndMins < parentStartMins) {
        newEnd = TimeOfDay(hour: parentStart.hour, minute: parentStart.minute);
      }
      if (newStart != null) {
        final startMins = newStart.hour * 60 + newStart.minute;
        final endMins = newEnd.hour * 60 + newEnd.minute;
        if (endMins < startMins) {
          newEnd = newStart;
        }
      }
    }

    return subtask.copyWith(
      startTime: newStart,
      endTime: newEnd,
    );
  }

  /// Automatically clamps all subtasks of a parent block when the parent is resized.
  static List<SubtaskItem> clampAllSubtasks(
    List<SubtaskItem> subtasks,
    DateTime parentStart,
    DateTime parentEnd,
  ) {
    return subtasks.map((s) => clampSubtask(s, parentStart, parentEnd)).toList();
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
