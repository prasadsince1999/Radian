import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/core/services/app_update_service.dart';
import 'package:sectograph_mcp/presentation/controllers/app_update_controller.dart';

void main() {
  group('AppUpdateService Semver Comparison Tests', () {
    test('identifies newer patch version', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.2'), isTrue);
    });

    test('identifies newer minor version', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.1.0'), isTrue);
    });

    test('identifies newer major version', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '2.0.0'), isTrue);
    });

    test('returns false for identical versions', () {
      expect(AppUpdateService.isNewerVersion('1.0.1', '1.0.1'), isFalse);
    });

    test('returns false when current version is newer', () {
      expect(AppUpdateService.isNewerVersion('1.1.0', '1.0.9'), isFalse);
      expect(AppUpdateService.isNewerVersion('2.0.0', '1.9.9'), isFalse);
    });

    test('handles v prefixes and special characters', () {
      expect(AppUpdateService.isNewerVersion('v1.0.1', 'v1.0.2'), isTrue);
      expect(AppUpdateService.isNewerVersion('1.0.1+1', '1.0.2+2'), isTrue);
      expect(AppUpdateService.isNewerVersion('v1.0.2', 'v1.0.1'), isFalse);
    });
  });

  group('AppUpdateInfo JSON Model Tests', () {
    test('parses full Cloudflare update JSON payload correctly', () {
      final json = {
        'version': '1.0.2',
        'tag': 'v1.0.2',
        'downloadUrl': 'https://github.com/prasadsince1999/Radian/releases/download/v1.0.2/Radian.apk',
        'apkName': 'Radian.apk',
        'sizeBytes': 57881395,
        'releaseNotes': 'Added OTA in-app updater and notifications.',
        'publishedAt': '2026-09-18T18:00:00Z',
        'htmlUrl':
            'https://github.com/prasadsince1999/Radian/releases/tag/v1.0.2',
      };

      final info = AppUpdateInfo.fromJson(json);

      expect(info.version, equals('1.0.2'));
      expect(info.tag, equals('v1.0.2'));
      expect(
        info.downloadUrl,
        equals(
          'https://github.com/prasadsince1999/Radian/releases/download/v1.0.2/Radian.apk',
        ),
      );
      expect(info.apkName, equals('Radian.apk'));
      expect(info.sizeBytes, equals(57881395));
      expect(info.formattedSize, equals('55.2 MB'));
      expect(
        info.releaseNotes,
        equals('Added OTA in-app updater and notifications.'),
      );
      expect(info.publishedAt.year, equals(2026));
      expect(
        info.htmlUrl,
        equals('https://github.com/prasadsince1999/Radian/releases/tag/v1.0.2'),
      );
    });

    test('handles fallback when fields are missing or empty', () {
      final info = AppUpdateInfo.fromJson({});

      expect(info.version, equals('1.0.0'));
      expect(info.tag, equals('v1.0.0'));
      expect(info.downloadUrl, isEmpty);
      expect(info.sizeBytes, equals(0));
      expect(info.formattedSize, equals('55 MB'));
      expect(info.releaseNotes, isEmpty);
    });
  });

  group('AppUpdateService Network Client Tests', () {
    test('fetches and deserializes latest release from endpoint', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/updates/latest') {
          return http.Response(
            jsonEncode({
              'version': '1.0.2',
              'tag': 'v1.0.2',
              'downloadUrl': 'https://example.com/Radian.apk',
              'apkName': 'Radian.apk',
              'sizeBytes': 52428800,
              'releaseNotes': 'New update available.',
              'publishedAt': '2026-09-18T12:00:00Z',
              'htmlUrl': 'https://github.com/prasadsince1999/Radian/releases',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = AppUpdateService(client: mockClient);
      final updateInfo = await service.checkLatestRelease(
        endpoint: 'https://example.com/api/updates/latest',
      );

      expect(updateInfo, isNotNull);
      expect(updateInfo!.version, equals('1.0.2'));
      expect(updateInfo.formattedSize, equals('50.0 MB'));
    });

    test('returns null when endpoint returns 500 error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = AppUpdateService(client: mockClient);
      final updateInfo = await service.checkLatestRelease(
        endpoint: 'https://example.com/api/updates/latest',
      );

      expect(updateInfo, isNull);
    });

    test('returns null when client throws exception', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Network unreachable');
      });

      final service = AppUpdateService(client: mockClient);
      final updateInfo = await service.checkLatestRelease(
        endpoint: 'https://example.com/api/updates/latest',
      );

      expect(updateInfo, isNull);
    });
  });

  group('AppUpdateController State Tests', () {
    test(
      'updates state to available when newer release is discovered',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({
              'version': '9.9.9',
              'tag': 'v9.9.9',
              'downloadUrl': 'https://example.com/Radian-9.9.9.apk',
              'apkName': 'Radian.apk',
              'sizeBytes': 50000000,
              'releaseNotes': 'Future version with quantum sync.',
              'publishedAt': '2026-09-18T12:00:00Z',
              'htmlUrl': 'https://example.com',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final service = AppUpdateService(client: mockClient);
        final controller = AppUpdateController(service);

        expect(controller.state.status, equals(AppUpdateStatus.idle));

        final hasUpdate = await controller.checkForUpdates();

        expect(hasUpdate, isTrue);
        expect(controller.state.status, equals(AppUpdateStatus.available));
        expect(controller.state.updateInfo?.version, equals('9.9.9'));
        expect(controller.state.isAvailable, isTrue);
      },
    );

    test('updates state to upToDate when same version is discovered', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'version': AppStrings.appVersion,
            'tag': 'v${AppStrings.appVersion}',
            'downloadUrl': 'https://example.com/Radian-${AppStrings.appVersion}.apk',
            'apkName': 'Radian.apk',
            'sizeBytes': 50000000,
            'releaseNotes': 'Current release.',
            'publishedAt': '2026-09-18T12:00:00Z',
            'htmlUrl': 'https://example.com',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = AppUpdateService(client: mockClient);
      final controller = AppUpdateController(service);

      final hasUpdate = await controller.checkForUpdates();

      expect(hasUpdate, isFalse);
      expect(controller.state.status, equals(AppUpdateStatus.upToDate));
      expect(controller.state.isUpToDate, isTrue);
      expect(controller.state.currentVersion, equals(AppStrings.appVersion));
    });

    test('getInstalledVersion falls back to AppStrings.appVersion in test environment', () async {
      final service = AppUpdateService();
      final version = await service.getInstalledVersion();
      expect(version, equals(AppStrings.appVersion));
    });

    test('dismiss resets state to idle', () {
      final service = AppUpdateService();
      final controller = AppUpdateController(service);
      controller.dismiss();

      expect(controller.state.status, equals(AppUpdateStatus.idle));
      expect(controller.state.errorMessage, isNull);
    });
  });
}
