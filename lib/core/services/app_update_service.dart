import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../constants/app_strings.dart';

/// Metadata for an OTA update fetched from Cloudflare/GitHub.
class AppUpdateInfo {
  final String version;
  final String tag;
  final String downloadUrl;
  final String apkName;
  final int sizeBytes;
  final String releaseNotes;
  final DateTime publishedAt;
  final String htmlUrl;

  const AppUpdateInfo({
    required this.version,
    required this.tag,
    required this.downloadUrl,
    required this.apkName,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.publishedAt,
    required this.htmlUrl,
  });

  factory AppUpdateInfo.fromJson(Map<String, dynamic> json) {
    return AppUpdateInfo(
      version: json['version'] as String? ?? '1.0.0',
      tag: json['tag'] as String? ?? 'v1.0.0',
      downloadUrl: json['downloadUrl'] as String? ?? '',
      apkName: json['apkName'] as String? ?? 'Radian.apk',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      releaseNotes: json['releaseNotes'] as String? ?? '',
      publishedAt:
          DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      htmlUrl: json['htmlUrl'] as String? ?? '',
    );
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '55 MB';
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Service managing Over-The-Air (OTA) updates, background release checks,
/// chunked APK streaming, and triggering Android Package Installer.
class AppUpdateService {
  static const MethodChannel _updaterChannel = MethodChannel(
    'com.ksmxtech.sectograph_mcp/updater',
  );

  final http.Client _client;

  AppUpdateService({http.Client? client}) : _client = client ?? http.Client();

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Compares current version with remote version (e.g. 1.0.1 vs 1.0.2).
  static bool isNewerVersion(String current, String remote) {
    List<int> parse(String v) => v
        .replaceAll(RegExp(r'[^0-9.]'), '')
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();

    final cParts = parse(current);
    final rParts = parse(remote);
    final maxLen = math.max(cParts.length, rParts.length);

    for (var i = 0; i < maxLen; i++) {
      final c = i < cParts.length ? cParts[i] : 0;
      final r = i < rParts.length ? rParts[i] : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }

  /// Fetches latest update metadata from Cloudflare Edge Worker.
  Future<AppUpdateInfo?> checkLatestRelease({
    String endpoint = AppStrings.updateEndpoint,
  }) async {
    try {
      final response = await _client
          .get(Uri.parse(endpoint), headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return AppUpdateInfo.fromJson(data);
      }
    } catch (_) {}
    return null;
  }

  /// Returns the target APK file path in app internal cache.
  Future<String?> getCacheApkPath() async {
    if (!isAndroid) return null;
    try {
      return await _updaterChannel.invokeMethod<String>('getCacheApkPath');
    } catch (_) {
      return null;
    }
  }

  /// Checks if the app is granted permission to install unknown apps.
  Future<bool> canInstallPackages() async {
    if (!isAndroid) return false;
    try {
      final can = await _updaterChannel.invokeMethod<bool>(
        'canInstallPackages',
      );
      return can ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system settings screen for "Install unknown apps".
  Future<void> openInstallPermissionSettings() async {
    if (!isAndroid) return;
    try {
      await _updaterChannel.invokeMethod('openInstallPermissionSettings');
    } catch (_) {}
  }

  /// Downloads the APK file into the app cache directory with streaming progress.
  Future<File?> downloadApk(
    String downloadUrl, {
    required void Function(double progress, int receivedBytes, int totalBytes)
    onProgress,
    int expectedTotalBytes = 0,
  }) async {
    if (!isAndroid) return null;
    final path = await getCacheApkPath();
    if (path == null) return null;

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
    await file.create(recursive: true);

    final request = http.Request('GET', Uri.parse(downloadUrl));
    final streamedResponse = await _client.send(request);

    if (streamedResponse.statusCode != 200) {
      throw Exception(
        'Failed to download APK: HTTP ${streamedResponse.statusCode}',
      );
    }

    final total = streamedResponse.contentLength ?? expectedTotalBytes;
    var received = 0;
    final sink = file.openWrite();

    try {
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) {
          final progress = (received / total).clamp(0.0, 1.0);
          onProgress(progress, received, total);
        } else {
          onProgress(0.5, received, total);
        }
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    onProgress(1.0, received, received);
    return file;
  }

  /// Launches Android's native package installer sheet via FileProvider.
  Future<bool> installApk(String filePath) async {
    if (!isAndroid) return false;
    try {
      final success = await _updaterChannel.invokeMethod<bool>('installApk', {
        'filePath': filePath,
      });
      return success ?? false;
    } catch (e) {
      debugPrint('[AppUpdateService] installApk failed: $e');
      return false;
    }
  }

  /// Displays an Android system notification alerting the user about an available update.
  Future<void> showUpdateNotification({
    required String version,
    String title = 'Radian Update Available',
    String? body,
  }) async {
    if (!isAndroid) return;
    try {
      await _updaterChannel.invokeMethod('showUpdateNotification', {
        'title': title,
        'body': body ?? 'Version $version is ready to download and install.',
        'version': version,
      });
    } catch (_) {}
  }
}
