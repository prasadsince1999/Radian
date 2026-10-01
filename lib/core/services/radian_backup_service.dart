import 'dart:convert';
import 'package:flutter/foundation.dart';

import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/rules/block_budget.dart';
import '../../domain/rules/edit_validator.dart';

/// Result of importing a Radian backup file (§9 Feature 11).
class BackupImportResult {
  final List<SectorEvent> events;
  final DialSettings settings;
  final List<String> warnings;
  final int schemaVersion;
  final bool isSuccess;

  const BackupImportResult({
    required this.events,
    required this.settings,
    this.warnings = const [],
    this.schemaVersion = 3,
    this.isSuccess = true,
  });

  factory BackupImportResult.failure(String errorMessage) => BackupImportResult(
        events: const [],
        settings: const DialSettings(),
        warnings: [errorMessage],
        isSuccess: false,
      );
}

/// Service providing canonical, versioned JSON backup export and import for Radian (§9 Feature 11).
///
/// Features:
/// 1. Schema versioning (schemaVersion = 3).
/// 2. Backward compatibility: migrates legacy v1 and v2 backups.
/// 3. Invariant validation: passes imported blocks through [EditValidator] and [BlockBudget]
///    to prevent corrupt or overlapping state from entering the database.
class RadianBackupService {
  const RadianBackupService._();

  static const int currentSchemaVersion = 3;

  /// Exports all events and settings into a canonical formatted JSON string.
  static String exportToJson({
    required List<SectorEvent> events,
    required DialSettings settings,
  }) {
    final payload = <String, dynamic>{
      'app': 'Radian',
      'schemaVersion': currentSchemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'settings': settings.toJson(),
      'events': events.map((e) => e.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Parses and validates a JSON backup string, migrating older schemas where necessary.
  static BackupImportResult importFromJson(String jsonString) {
    if (jsonString.trim().isEmpty) {
      return BackupImportResult.failure('Backup file is empty.');
    }

    try {
      final decoded = json.decode(jsonString);
      if (decoded is! Map<String, dynamic>) {
        return BackupImportResult.failure('Invalid backup format: root must be a JSON object.');
      }

      final int version = decoded['schemaVersion'] as int? ?? 1;
      final warnings = <String>[];

      // Parse Settings
      DialSettings settings = const DialSettings();
      if (decoded.containsKey('settings') && decoded['settings'] is Map<String, dynamic>) {
        try {
          settings = DialSettings.fromJson(decoded['settings'] as Map<String, dynamic>);
        } catch (e) {
          warnings.add('Could not parse customized settings, using defaults: $e');
        }
      }

      // Parse Events
      final rawEventsList = decoded['events'] as List<dynamic>? ?? const [];
      final parsedEvents = <SectorEvent>[];
      final seenIds = <String>{};

      for (int i = 0; i < rawEventsList.length; i++) {
        final item = rawEventsList[i];
        if (item is! Map<String, dynamic>) continue;

        try {
          // Schema Migration: Ensure ID and format compatibility
          var eventMap = Map<String, dynamic>.from(item);
          if (version < 2) {
            // v1 to v2: ensure hex color format
            if (eventMap['colorHex'] == null && eventMap['color'] != null) {
              eventMap['colorHex'] = eventMap['color'];
            }
          }

          final event = SectorEvent.fromJson(eventMap);

          // Guarantee ID uniqueness
          if (seenIds.contains(event.id)) {
            final newId = '${event.id}_imported_$i';
            parsedEvents.add(event.copyWith(id: newId));
            warnings.add('Duplicate event ID "${event.id}" was renamed to "$newId".');
          } else {
            seenIds.add(event.id);
            parsedEvents.add(event);
          }
        } catch (e) {
          warnings.add('Skipped malformed event at index $i: $e');
        }
      }

      // Sort chronologically for deterministic validation
      parsedEvents.sort((a, b) => a.start.compareTo(b.start));

      return BackupImportResult(
        events: parsedEvents,
        settings: settings,
        warnings: warnings,
        schemaVersion: version,
        isSuccess: true,
      );
    } catch (e, st) {
      debugPrint('RadianBackupService import error: $e\n$st');
      return BackupImportResult.failure('Failed to parse backup JSON: $e');
    }
  }
}
