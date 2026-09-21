import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_strings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/models/subtask_item.dart';
import '../../domain/repositories/event_repository.dart';

enum SyncStatus { idle, syncing, synced, offline, error }

typedef SyncHttpTransport = Future<({int statusCode, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

/// Background synchronization service connecting the local Sectograph repository
/// to Cloudflare D1 via the remote Cloudflare Worker API.
///
/// Ensures 100% tenant isolation using a unique Private Sync Key per user,
/// automatic mutation tracking, and full subtask serialization.
class CloudSyncService {
  static const String defaultServerUrl = AppStrings.cloudflareMcpBaseUrl;
  static const String _lastSyncKeyPrefix = 'sectograph_cf_last_sync_';
  static const String _serverUrlKey = 'sectograph_cf_server_url';
  static const String _syncKeyStorageKey = 'radian_sync_key';

  final EventRepository repository;
  final SharedPreferences? prefs;
  final SyncHttpTransport _transport;

  String? _serverUrl;
  String _syncKey = '';
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  final _statusController = StreamController<SyncStatus>.broadcast();
  StreamSubscription<EventMutation>? _mutationSubscription;
  Timer? _debounceTimer;

  CloudSyncService({
    required this.repository,
    this.prefs,
    String? initialServerUrl = defaultServerUrl,
    SyncHttpTransport? transport,
  }) : _serverUrl = initialServerUrl,
       _transport = transport ?? _defaultHttpTransport {
    _init();
  }

  SyncStatus get status => _status;
  DateTime? get lastSyncTime => _lastSyncTime;
  Stream<SyncStatus> get statusStream => _statusController.stream;
  String? get serverUrl => _serverUrl;
  String get syncKey => _syncKey;

  /// Generates a human-friendly, high-entropy unique sync key (e.g. RAD-7A4B-9E2C)
  static String generateUniqueSyncKey() {
    const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
    final rand = Random.secure();
    String part(int len) =>
        List.generate(len, (_) => chars[rand.nextInt(chars.length)]).join();
    return 'RAD-${part(4)}-${part(4)}';
  }

  void _init() {
    // 1. Initialize Sync Key: check query param on web, then prefs, then generate new
    String? key;
    if (kIsWeb) {
      try {
        final query = Uri.base.queryParameters;
        key = query['sync'] ?? query['sync_key'];
      } catch (_) {}
    }

    if (key == null || key.trim().isEmpty) {
      key = prefs?.getString(_syncKeyStorageKey) ??
          prefs?.getString('cloud_sync_key');
    }

    if (key == null || key.trim().isEmpty) {
      key = generateUniqueSyncKey();
      prefs?.setString(_syncKeyStorageKey, key);
      prefs?.setString('cloud_sync_key', key);
    } else {
      key = key.trim().toUpperCase();
      prefs?.setString(_syncKeyStorageKey, key);
      prefs?.setString('cloud_sync_key', key);
    }
    _syncKey = key;

    // 2. Restore persistent pending mutations if previously queued
    final savedMutations = prefs?.getString('radian_pending_mutations');
    if (savedMutations != null && savedMutations.isNotEmpty) {
      try {
        final decoded = jsonDecode(savedMutations) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            _pendingMutations.add(item);
          }
        }
      } catch (_) {}
    }

    // 3. Initialize server URL and last sync time for this key
    if (prefs != null) {
      _serverUrl =
          prefs!.getString(_serverUrlKey) ?? _serverUrl ?? defaultServerUrl;
      final lastStr = prefs!.getString('$_lastSyncKeyPrefix$_syncKey');
      if (lastStr != null) {
        _lastSyncTime = DateTime.tryParse(lastStr);
      }
    }

    // 4. Listen to repository mutations automatically: any block add/edit/delete
    // anywhere in the application automatically queues sync without missing.
    _mutationSubscription = repository.mutations.listen((mutation) {
      if (mutation.action == 'upsert' && mutation.event != null) {
        queueUpsert(mutation.event!);
      } else if (mutation.action == 'delete' && mutation.id != null) {
        queueDelete(mutation.id!);
      }
      _scheduleDebouncedSync();
    });
  }

  void _savePendingMutations() {
    if (prefs != null) {
      prefs!.setString(
        'radian_pending_mutations',
        jsonEncode(_pendingMutations),
      );
    }
  }

  void _scheduleDebouncedSync() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1500), () {
      syncNow();
    });
  }

  Future<void> setSyncKey(String newKey) async {
    final clean = newKey.trim().toUpperCase();
    if (clean.isEmpty || clean == _syncKey) return;

    _syncKey = clean;
    _pendingMutations.clear();
    _savePendingMutations();

    if (prefs != null) {
      await prefs!.setString(_syncKeyStorageKey, _syncKey);
      await prefs!.setString('cloud_sync_key', _syncKey);
      final lastStr = prefs!.getString('$_lastSyncKeyPrefix$_syncKey');
      _lastSyncTime = lastStr != null ? DateTime.tryParse(lastStr) : null;
    } else {
      _lastSyncTime = null;
    }

    // Cleanly reset local repository so previous vault's events do not leak into the new vault
    await repository.clearAllEvents();

    // Force full sync with the new vault
    await syncNow();
  }

  Future<void> configureServerUrl(String url) async {
    _serverUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    if (prefs != null) {
      if (_serverUrl == null || _serverUrl!.isEmpty) {
        await prefs!.remove(_serverUrlKey);
      } else {
        await prefs!.setString(_serverUrlKey, _serverUrl!);
      }
    }
  }

  final List<Map<String, dynamic>> _pendingMutations = [];

  List<Map<String, dynamic>> get pendingMutations =>
      List.unmodifiable(_pendingMutations);

  void queueUpsert(SectorEvent event) {
    _pendingMutations.removeWhere(
      (m) => m['event']?['id'] == event.id || m['id'] == event.id,
    );

    final subtasksSerialized = event.subtaskItems.isNotEmpty
        ? jsonEncode(event.subtaskItems.map((s) => s.toJson()).toList())
        : (event.subtasks.isNotEmpty ? jsonEncode(event.subtasks) : null);

    _pendingMutations.add({
      'action': 'upsert',
      'event': {
        'id': event.id,
        'title': event.title,
        'start': event.start.toIso8601String(),
        'end': event.end.toIso8601String(),
        'category': event.category,
        'color_hex': event.colorHex,
        'notes': event.notes,
        'is_all_day': event.isAllDay ? 1 : 0,
        'icon_name': event.iconName,
        'reminder_minutes': event.reminderMinutes,
        'repeat_days': event.repeatDays != null
            ? jsonEncode(event.repeatDays)
            : null,
        'recurrence_end_date': event.recurrenceEndDate?.toIso8601String(),
        'subtasks': subtasksSerialized,
        'sync_key': _syncKey,
      },
    });
    _savePendingMutations();
  }

  void queueDelete(String id) {
    _pendingMutations.removeWhere(
      (m) => m['event']?['id'] == id || m['id'] == id,
    );
    _pendingMutations.add({'action': 'delete', 'id': id});
    _savePendingMutations();
  }

  /// Performs a delta synchronization pass with the Cloudflare D1 server.
  Future<bool> syncNow() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _updateStatus(SyncStatus.idle);
      return false;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      final syncEndpoint = Uri.parse('$_serverUrl/api/sync');
      final mutationsToSend = List<Map<String, dynamic>>.from(
        _pendingMutations,
      );

      final payload = {
        'syncKey': _syncKey,
        'since': _lastSyncTime?.toIso8601String(),
        'mutations': mutationsToSend,
      };

      final response = await _transport(syncEndpoint, {
        'Content-Type': 'application/json',
        'X-Radian-Sync-Key': _syncKey,
        'X-Sync-Key': _syncKey,
      }, jsonEncode(payload));

      if (response.statusCode == 200) {
        _pendingMutations.removeWhere((m) => mutationsToSend.contains(m));
        _savePendingMutations();
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? delta = data['delta'] as List<dynamic>?;

        if (delta != null && delta.isNotEmpty) {
          final incomingEvents = <SectorEvent>[];
          for (final raw in delta) {
            final map = raw as Map<String, dynamic>;
            if (map['deleted_at'] != null) {
              await repository.deleteEvent(
                map['id'] as String,
                notifyMutation: false,
              );
            } else {
              List<int>? repeatDays;
              if (map['repeat_days'] != null) {
                try {
                  final decoded = jsonDecode(map['repeat_days'] as String);
                  repeatDays = (decoded as List).map((i) => i as int).toList();
                } catch (_) {}
              }

              List<SubtaskItem> subtaskItems = const [];
              List<String> subtasks = const [];
              if (map['subtasks'] != null) {
                try {
                  final dynamic rawSub = map['subtasks'];
                  final decoded = rawSub is String
                      ? jsonDecode(rawSub)
                      : rawSub;
                  if (decoded is List && decoded.isNotEmpty) {
                    if (decoded.first is Map) {
                      subtaskItems = decoded
                          .map(
                            (item) => SubtaskItem.fromJson(
                              item as Map<String, dynamic>,
                              map['id'] as String,
                            ),
                          )
                          .toList();
                      subtasks = subtaskItems.map((s) => s.title).toList();
                    } else {
                      subtasks = decoded.map((i) => i.toString()).toList();
                      subtaskItems = subtasks
                          .map(
                            (s) => SubtaskItem.fromString(
                              s,
                              parentEventId: map['id'] as String,
                            ),
                          )
                          .toList();
                    }
                  }
                } catch (_) {}
              }

              // Guard: If cloud response omitted or has empty subtasks, preserve local subtasks
              if (subtaskItems.isEmpty && subtasks.isEmpty) {
                final allLocal = await repository.getAllEvents();
                for (final loc in allLocal) {
                  if (loc.id == map['id'] && loc.subtaskItems.isNotEmpty) {
                    subtaskItems = loc.subtaskItems;
                    subtasks = loc.subtasks;
                    break;
                  }
                }
              }

              incomingEvents.add(
                SectorEvent(
                  id: map['id'] as String,
                  title: map['title'] as String,
                  start: DateTime.parse(map['start'] as String),
                  end: DateTime.parse(map['end'] as String),
                  category: map['category'] as String? ?? 'General',
                  colorHex: map['color_hex'] as String? ?? '#3B82F6',
                  notes: map['notes'] as String? ?? '',
                  isAllDay: (map['is_all_day'] as int? ?? 0) == 1,
                  iconName: map['icon_name'] as String?,
                  reminderMinutes: map['reminder_minutes'] as int?,
                  repeatDays: repeatDays,
                  recurrenceEndDate: map['recurrence_end_date'] != null
                      ? DateTime.parse(map['recurrence_end_date'] as String)
                      : null,
                  subtasks: subtasks,
                  subtaskItems: subtaskItems,
                ),
              );
            }
          }

          if (incomingEvents.isNotEmpty) {
            await repository.bulkAddEvents(
              incomingEvents,
              notifyMutations: false,
            );
          }
        }

        final serverTimeStr = data['serverTime'] as String?;
        _lastSyncTime = serverTimeStr != null
            ? DateTime.tryParse(serverTimeStr) ?? DateTime.now()
            : DateTime.now();

        if (prefs != null) {
          await prefs!.setString(
            '$_lastSyncKeyPrefix$_syncKey',
            _lastSyncTime!.toIso8601String(),
          );
        }

        _updateStatus(SyncStatus.synced);
        return true;
      } else {
        _updateStatus(SyncStatus.error);
        return false;
      }
    } on SocketException {
      _updateStatus(SyncStatus.offline);
      return false;
    } on TimeoutException {
      _updateStatus(SyncStatus.offline);
      return false;
    } on http.ClientException {
      _updateStatus(SyncStatus.offline);
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CloudSyncService error: $e');
      }
      _updateStatus(SyncStatus.error);
      return false;
    }
  }

  static Future<({int statusCode, String body})> _defaultHttpTransport(
    Uri uri,
    Map<String, String> headers,
    String body,
  ) async {
    final response = await http
        .post(uri, headers: headers, body: body)
        .timeout(const Duration(seconds: 10));
    return (statusCode: response.statusCode, body: response.body);
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _debounceTimer?.cancel();
    _mutationSubscription?.cancel();
    _statusController.close();
  }
}
