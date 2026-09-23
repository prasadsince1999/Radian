import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/app_update_service.dart';

/// Lifecycle status for Over-The-Air app update checks and downloads.
enum AppUpdateStatus {
  idle,
  checking,
  available,
  downloading,
  readyToInstall,
  upToDate,
  error,
}

/// State tracking OTA update availability, download stream progress, and installer path.
class AppUpdateState {
  final AppUpdateStatus status;
  final AppUpdateInfo? updateInfo;
  final String currentVersion;
  final double downloadProgress;
  final int receivedBytes;
  final int totalBytes;
  final String? downloadedFilePath;
  final String? errorMessage;
  final DateTime? lastCheckedTime;

  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.updateInfo,
    this.currentVersion = AppStrings.appVersion,
    this.downloadProgress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.downloadedFilePath,
    this.errorMessage,
    this.lastCheckedTime,
  });

  bool get isChecking => status == AppUpdateStatus.checking;
  bool get isDownloading => status == AppUpdateStatus.downloading;
  bool get isAvailable => status == AppUpdateStatus.available;
  bool get isReadyToInstall => status == AppUpdateStatus.readyToInstall;
  bool get isUpToDate => status == AppUpdateStatus.upToDate;
  bool get hasError => status == AppUpdateStatus.error;

  String get progressPercent => '${(downloadProgress * 100).toInt()}%';

  String get progressDetail {
    if (totalBytes <= 0) {
      final recMb = receivedBytes / (1024 * 1024);
      return '${recMb.toStringAsFixed(1)} MB downloaded';
    }
    final recMb = receivedBytes / (1024 * 1024);
    final totMb = totalBytes / (1024 * 1024);
    return '${recMb.toStringAsFixed(1)} / ${totMb.toStringAsFixed(1)} MB';
  }

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    AppUpdateInfo? updateInfo,
    String? currentVersion,
    double? downloadProgress,
    int? receivedBytes,
    int? totalBytes,
    String? downloadedFilePath,
    String? errorMessage,
    DateTime? lastCheckedTime,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      currentVersion: currentVersion ?? this.currentVersion,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      downloadedFilePath: downloadedFilePath ?? this.downloadedFilePath,
      errorMessage: errorMessage ?? this.errorMessage,
      lastCheckedTime: lastCheckedTime ?? this.lastCheckedTime,
    );
  }
}

/// Controller managing update checks, streaming download with progress,
/// permission checks, and native APK package installation.
class AppUpdateController extends StateNotifier<AppUpdateState> {
  final AppUpdateService _service;

  AppUpdateController(this._service) : super(const AppUpdateState());

  /// Checks the Cloudflare Edge endpoint for new GitHub releases.
  /// If [isSilent] is true, errors are ignored and an Android notification is scheduled on update.
  Future<bool> checkForUpdates({bool isSilent = false}) async {
    if (state.isChecking || state.isDownloading) return false;

    state = state.copyWith(
      status: AppUpdateStatus.checking,
      errorMessage: null,
    );

    try {
      final info = await _service.checkLatestRelease();
      if (info == null) {
        if (!isSilent) {
          state = state.copyWith(
            status: AppUpdateStatus.error,
            errorMessage:
                'Unable to check for updates. Check internet connection.',
            lastCheckedTime: DateTime.now(),
          );
        } else {
          state = state.copyWith(
            status: AppUpdateStatus.idle,
            lastCheckedTime: DateTime.now(),
          );
        }
        return false;
      }

      final currentVersion = await _service.getInstalledVersion();
      final hasUpdate = AppUpdateService.isNewerVersion(
        currentVersion,
        info.version,
      );

      if (hasUpdate) {
        state = state.copyWith(
          status: AppUpdateStatus.available,
          updateInfo: info,
          currentVersion: currentVersion,
          downloadProgress: 0.0,
          lastCheckedTime: DateTime.now(),
        );

        if (isSilent) {
          await _service.showUpdateNotification(
            version: info.version,
            title: 'Radian v${info.version} Available',
            body: 'Tap to update Radian with the latest features and fixes.',
          );
        }
        return true;
      } else {
        state = state.copyWith(
          status: AppUpdateStatus.upToDate,
          updateInfo: info,
          currentVersion: currentVersion,
          lastCheckedTime: DateTime.now(),
        );
        return false;
      }
    } catch (e) {
      if (!isSilent) {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: 'Update check failed: $e',
          lastCheckedTime: DateTime.now(),
        );
      } else {
        state = state.copyWith(
          status: AppUpdateStatus.idle,
          lastCheckedTime: DateTime.now(),
        );
      }
      return false;
    }
  }

  /// Downloads the latest APK from GitHub/Cloudflare and initiates installation.
  Future<void> startDownloadAndInstall() async {
    final info = state.updateInfo;
    if (info == null || info.downloadUrl.isEmpty || state.isDownloading) return;

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      downloadProgress: 0.0,
      receivedBytes: 0,
      totalBytes: info.sizeBytes,
      errorMessage: null,
    );

    try {
      final file = await _service.downloadApk(
        info.downloadUrl,
        expectedTotalBytes: info.sizeBytes,
        onProgress: (progress, received, total) {
          state = state.copyWith(
            downloadProgress: progress,
            receivedBytes: received,
            totalBytes: total,
          );
        },
      );

      if (file == null) {
        state = state.copyWith(
          status: AppUpdateStatus.error,
          errorMessage: 'APK could not be saved to internal storage.',
        );
        return;
      }

      state = state.copyWith(
        status: AppUpdateStatus.readyToInstall,
        downloadedFilePath: file.path,
        downloadProgress: 1.0,
      );

      // Trigger installation immediately
      await installApk();
    } catch (e) {
      debugPrint('[AppUpdateController] Download error: $e');
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Download failed: $e',
      );
    }
  }

  /// Launches the native Android package installer sheet.
  /// If unknown app installation permission is not yet granted, opens Android settings.
  Future<bool> installApk() async {
    final path = state.downloadedFilePath;
    if (path == null) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Downloaded APK not found.',
      );
      return false;
    }

    final canInstall = await _service.canInstallPackages();
    if (!canInstall) {
      await _service.openInstallPermissionSettings();
      // On return, the user can press Install again
      return false;
    }

    final success = await _service.installApk(path);
    if (!success) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        errorMessage: 'Android package installer could not be launched.',
      );
    }
    return success;
  }

  /// Resets update state back to idle.
  void dismiss() {
    state = state.copyWith(status: AppUpdateStatus.idle, errorMessage: null);
  }
}

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService();
});

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
      final service = ref.watch(appUpdateServiceProvider);
      return AppUpdateController(service);
    });
