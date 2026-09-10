import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_strings.dart';
import '../../core/services/cloud_sync_service.dart';
import 'clock_controller.dart';

class CloudSyncState {
  final SyncStatus status;
  final DateTime? lastSyncTime;
  final String serverUrl;

  const CloudSyncState({
    this.status = SyncStatus.idle,
    this.lastSyncTime,
    this.serverUrl = AppStrings.cloudflareMcpBaseUrl,
  });

  bool get isSyncing => status == SyncStatus.syncing;

  String get formattedLastSync {
    if (lastSyncTime == null) return 'Never synced';
    final now = DateTime.now();
    final diff = now.difference(lastSyncTime!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${lastSyncTime!.month}/${lastSyncTime!.day}';
  }

  CloudSyncState copyWith({
    SyncStatus? status,
    DateTime? lastSyncTime,
    String? serverUrl,
  }) {
    return CloudSyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }
}

class CloudSyncController extends StateNotifier<CloudSyncState> {
  final CloudSyncService _service;

  CloudSyncController(this._service)
      : super(
          CloudSyncState(
            status: _service.status,
            lastSyncTime: _service.lastSyncTime,
            serverUrl: _service.serverUrl ?? AppStrings.cloudflareMcpBaseUrl,
          ),
        ) {
    _service.statusStream.listen((status) {
      state = state.copyWith(
        status: status,
        lastSyncTime: _service.lastSyncTime,
      );
    });
  }

  Future<bool> syncNow() async {
    final success = await _service.syncNow();
    state = state.copyWith(
      status: _service.status,
      lastSyncTime: _service.lastSyncTime,
    );
    return success;
  }

  Future<void> configureServerUrl(String url) async {
    await _service.configureServerUrl(url);
    state = state.copyWith(
      serverUrl: _service.serverUrl ?? AppStrings.cloudflareMcpBaseUrl,
    );
  }
}

final cloudSyncServiceProvider = Provider<CloudSyncService>((ref) {
  final repo = ref.watch(eventRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  return CloudSyncService(repository: repo, prefs: prefs);
});

final cloudSyncControllerProvider =
    StateNotifierProvider<CloudSyncController, CloudSyncState>((ref) {
      final service = ref.watch(cloudSyncServiceProvider);
      return CloudSyncController(service);
    });
