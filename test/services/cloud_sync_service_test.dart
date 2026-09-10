import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/services/cloud_sync_service.dart';
import 'package:sectograph_mcp/data/repositories/local_event_repository.dart';

void main() {
  group('CloudSyncService Tests', () {
    late LocalEventRepository repo;

    setUp(() {
      repo = LocalEventRepository();
    });

    test('returns false and stays idle if serverUrl is not set', () async {
      final syncService = CloudSyncService(
        repository: repo,
        initialServerUrl: null,
      );
      final result = await syncService.syncNow();

      expect(result, isFalse);
      expect(syncService.status, equals(SyncStatus.idle));
    });

    test(
      'syncs incoming delta events from mock Cloudflare D1 server',
      () async {
        final syncService = CloudSyncService(
          repository: repo,
          transport: (uri, headers, body) async {
            if (uri.path == '/api/sync') {
              return (
                statusCode: 200,
                body: jsonEncode({
                  'success': true,
                  'serverTime': '2026-09-09T12:00:00.000Z',
                  'deltaCount': 1,
                  'delta': [
                    {
                      'id': 'cf_event_1',
                      'title': 'Cloudflare Scheduled Event',
                      'start': '2026-09-09T14:00:00.000Z',
                      'end': '2026-09-09T15:00:00.000Z',
                      'category': 'Work',
                      'color_hex': '#10B981',
                      'notes': 'Synced from D1',
                      'is_all_day': 0,
                      'deleted_at': null,
                    },
                  ],
                }),
              );
            }
            return (statusCode: 404, body: 'Not Found');
          },
        );
        await syncService.configureServerUrl(
          'https://sectograph.example.workers.dev',
        );

        final success = await syncService.syncNow();
        expect(success, isTrue);
        expect(syncService.status, equals(SyncStatus.synced));

        final allEvents = await repo.getAllEvents();
        final syncedEvent = allEvents.firstWhere((e) => e.id == 'cf_event_1');
        expect(syncedEvent.title, equals('Cloudflare Scheduled Event'));
        expect(syncedEvent.category, equals('Work'));
      },
    );

    test('transitions to SyncStatus.offline on SocketException', () async {
      final syncService = CloudSyncService(
        repository: repo,
        transport: (uri, headers, body) async {
          throw const SocketException('Failed host lookup');
        },
      );
      await syncService.configureServerUrl('https://unreachable.workers.dev');

      final success = await syncService.syncNow();
      expect(success, isFalse);
      expect(syncService.status, equals(SyncStatus.offline));
    });

    test('transitions to SyncStatus.error on HTTP 500', () async {
      final syncService = CloudSyncService(
        repository: repo,
        transport: (uri, headers, body) async {
          return (statusCode: 500, body: 'Internal Server Error');
        },
      );
      await syncService.configureServerUrl('https://error.workers.dev');

      final success = await syncService.syncNow();
      expect(success, isFalse);
      expect(syncService.status, equals(SyncStatus.error));
    });
  });
}
