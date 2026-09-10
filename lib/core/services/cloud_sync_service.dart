import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_strings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/repositories/event_repository.dart';

enum SyncStatus { idle, syncing, synced, offline, error }

typedef SyncHttpTransport = Future<({int statusCode, String body})> Function(
  Uri uri,
  Map<String, String> headers,
  String body,
);

/// Background synchronization service connecting the local Sectograph repository
/// to Cloudflare D1 via the remote Cloudflare Worker API.
class CloudSyncService {
  static const String defaultServerUrl = AppStrings.cloudflareMcpBaseUrl;
  static const String _lastSyncKey = 'sectograph_cf_last_sync';
  static const String _serverUrlKey = 'sectograph_cf_server_url';

  final EventRepository repository;
  final SharedPreferences? prefs;
  final SyncHttpTransport _transport;

  String? _serverUrl;
  SyncStatus _status = SyncStatus.idle;
  DateTime? _lastSyncTime;
  final _statusController = StreamController<SyncStatus>.broadcast();

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

  void _init() {
    if (prefs != null) {
      _serverUrl = prefs!.getString(_serverUrlKey) ?? _serverUrl ?? defaultServerUrl;
      final lastStr = prefs!.getString(_lastSyncKey);
      if (lastStr != null) {
        _lastSyncTime = DateTime.tryParse(lastStr);
      }
    }
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

  /// Performs a delta synchronization pass with the Cloudflare D1 server.
  Future<bool> syncNow() async {
    if (_serverUrl == null || _serverUrl!.isEmpty) {
      _updateStatus(SyncStatus.idle);
      return false;
    }

    _updateStatus(SyncStatus.syncing);

    try {
      final syncEndpoint = Uri.parse('$_serverUrl/api/sync');
      final allLocalEvents = await repository.getAllEvents();

      final payload = {
        'since': _lastSyncTime?.toIso8601String(),
        'mutations': allLocalEvents.map((e) {
          return {
            'action': 'upsert',
            'event': {
              'id': e.id,
              'title': e.title,
              'start': e.start.toIso8601String(),
              'end': e.end.toIso8601String(),
              'category': e.category,
              'color_hex': e.colorHex,
              'notes': e.notes,
              'is_all_day': e.isAllDay ? 1 : 0,
              'icon_name': e.iconName,
              'reminder_minutes': e.reminderMinutes,
              'repeat_days': e.repeatDays != null
                  ? jsonEncode(e.repeatDays)
                  : null,
              'recurrence_end_date': e.recurrenceEndDate?.toIso8601String(),
            },
          };
        }).toList(),
      };

      final response = await _transport(syncEndpoint, {
        'Content-Type': 'application/json',
      }, jsonEncode(payload));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? delta = data['delta'] as List<dynamic>?;

        if (delta != null && delta.isNotEmpty) {
          final incomingEvents = <SectorEvent>[];
          for (final raw in delta) {
            final map = raw as Map<String, dynamic>;
            if (map['deleted_at'] != null) {
              await repository.deleteEvent(map['id'] as String);
            } else {
              List<int>? repeatDays;
              if (map['repeat_days'] != null) {
                try {
                  final decoded = jsonDecode(map['repeat_days'] as String);
                  repeatDays = (decoded as List).map((i) => i as int).toList();
                } catch (_) {}
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
                ),
              );
            }
          }

          if (incomingEvents.isNotEmpty) {
            await repository.bulkAddEvents(incomingEvents);
          }
        }

        final serverTimeStr = data['serverTime'] as String?;
        _lastSyncTime = serverTimeStr != null
            ? DateTime.tryParse(serverTimeStr) ?? DateTime.now()
            : DateTime.now();

        if (prefs != null) {
          await prefs!.setString(
            _lastSyncKey,
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
    final client = HttpClient();
    try {
      final request = await client.postUrl(uri);
      headers.forEach((k, v) => request.headers.set(k, v));
      request.write(body);
      final response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final respBody = await response.transform(utf8.decoder).join();
      return (statusCode: response.statusCode, body: respBody);
    } finally {
      client.close();
    }
  }

  void _updateStatus(SyncStatus newStatus) {
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(newStatus);
    }
  }

  void dispose() {
    _statusController.close();
  }
}
