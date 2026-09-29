import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providing a unified stream of system time, date, timezone, and locale changes.
///
/// Combines native Android broadcast events (`ACTION_TIMEZONE_CHANGED`, `ACTION_TIME_SET`,
/// `ACTION_DATE_CHANGED`, `ACTION_LOCALE_CHANGED`) with Flutter application lifecycle
/// resume events to ensure the dial never stays out-of-sync when the user returns
/// to the app or changes their device clock.
class SystemTimeChangeService with WidgetsBindingObserver {
  static const EventChannel _eventChannel =
      EventChannel('com.ksmxtech.sectograph_mcp/time_changes');

  final _controller = StreamController<String>.broadcast();
  StreamSubscription<dynamic>? _platformSubscription;

  SystemTimeChangeService() {
    WidgetsBinding.instance.addObserver(this);
    _initPlatformListener();
  }

  void _initPlatformListener() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        _platformSubscription = _eventChannel.receiveBroadcastStream().listen(
          (event) {
            _controller.add(event.toString());
          },
          onError: (_) {
            // Non-fatal: Fall back to lifecycle-based resume triggers
          },
        );
      } catch (_) {}
    }
  }

  /// Stream of system time change event actions.
  Stream<String> get systemTimeChanges => _controller.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller.add('ACTION_APP_RESUMED');
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _platformSubscription?.cancel();
    _controller.close();
  }
}

/// Provider for listening to system time, timezone, and date changes.
final systemTimeChangeServiceProvider =
    Provider<SystemTimeChangeService>((ref) {
  final service = SystemTimeChangeService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream provider for live system time changes across the app.
final systemTimeChangesStreamProvider = StreamProvider<String>((ref) {
  final service = ref.watch(systemTimeChangeServiceProvider);
  return service.systemTimeChanges;
});
