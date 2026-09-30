import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dial_engine_flags.dart';
import '../../core/services/widget_frame_service.dart';
import '../../core/theme/expressive_theme.dart';
import '../../core/time/zone_clock.dart';
import '../../domain/models/dial_settings.dart';
import '../../domain/models/sector_event.dart';
import '../../domain/schedule/occurrence_adapter.dart';
import '../../engine/dial_input.dart';
import '../../engine/widget_frame_planner.dart';
import 'clock_controller.dart';

enum WidgetSyncStatus { idle, syncing, success, error }

class WidgetSyncState {
  final WidgetSyncStatus status;
  final DateTime? lastSyncTime;
  final String? lastDataVersion;
  final String? errorMessage;

  const WidgetSyncState({
    this.status = WidgetSyncStatus.idle,
    this.lastSyncTime,
    this.lastDataVersion,
    this.errorMessage,
  });

  WidgetSyncState copyWith({
    WidgetSyncStatus? status,
    DateTime? lastSyncTime,
    String? lastDataVersion,
    String? errorMessage,
  }) {
    return WidgetSyncState(
      status: status ?? this.status,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastDataVersion: lastDataVersion ?? this.lastDataVersion,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Unified coordinator for home-screen widget synchronization (§6.3, RC5, RC6, RC10).
///
/// Features:
/// 1. Single pipeline: replaces fragmented listeners across UI screens.
/// 2. 800ms debounce: coalesces rapid event/settings/clock edits into one render pass.
/// 3. DialEngineFlags-aware: delegates to [WidgetFrameService] (Frame Strip) or legacy [SyncDialWidgetUseCase].
/// 4. Exposes [syncNow] for immediate lifecycle/button invocation.
class WidgetSyncCoordinator extends StateNotifier<WidgetSyncState> {
  final Ref _ref;
  Timer? _debounceTimer;
  bool _isDisposed = false;

  WidgetSyncCoordinator(this._ref) : super(const WidgetSyncState()) {
    _initListeners();
  }

  void _initListeners() {
    // Listen to schedule changes
    _ref.listen<AsyncValue<List<SectorEvent>>>(
      allEventsProvider,
      (prev, next) {
        if (next.hasValue) {
          _scheduleDebouncedSync();
        }
      },
    );

    // Listen to dial preference & theme styling changes
    _ref.listen<DialSettings>(
      dialSettingsProvider,
      (prev, next) {
        _scheduleDebouncedSync();
      },
    );

    // Listen to timezone clock alterations
    _ref.listen<ZoneClock>(
      zoneClockProvider,
      (prev, next) {
        _scheduleDebouncedSync();
      },
    );
  }

  void _scheduleDebouncedSync() {
    if (_isDisposed) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_isDisposed) {
        _performSync();
      }
    });
  }

  /// Triggers an immediate, non-debounced synchronization pass.
  Future<void> syncNow({ThemeData? theme}) async {
    _debounceTimer?.cancel();
    await _performSync(themeOverride: theme);
  }

  Future<void> _performSync({ThemeData? themeOverride}) async {
    if (!mounted || _isDisposed) return;
    state = state.copyWith(status: WidgetSyncStatus.syncing);

    try {
      final allEventsAsync = _ref.read(allEventsProvider);
      final events = allEventsAsync.value ?? const <SectorEvent>[];
      final settings = _ref.read(dialSettingsProvider);
      final zoneClock = _ref.read(zoneClockProvider);
      final now = zoneClock.now();

      if (DialEngineFlags.widgetFrameStrip) {
        // --- Phase 6: Frame Strip Architecture ---
        final snapshot = zoneClock.snapshot();
        final occurrences = OccurrenceAdapter.projectOccurrencesForHorizon(
          events: events,
          clock: snapshot,
          is24HourMode: settings.is24HourMode,
        );

        final enginePrefs = DialPrefs(
          is24HourMode: settings.is24HourMode,
          previousBlocksCount: settings.previousBlocksCount,
          futureBlocksCount: settings.futureBlocksCount,
          isFocusLensEnabled: settings.isFocusLensEnabled,
          lensMagnification: settings.lensMagnification,
        );

        final plan = WidgetFramePlanner.plan(
          clock: snapshot,
          occurrences: occurrences,
          prefs: enginePrefs,
        );

        final deployed = await WidgetFrameService.deployFrameStrip(
          plan: plan,
          settings: settings,
        );

        if (!mounted || _isDisposed) return;

        if (deployed) {
          state = state.copyWith(
            status: WidgetSyncStatus.success,
            lastSyncTime: DateTime.now(),
            lastDataVersion: plan.dataVersion,
            errorMessage: null,
          );
        } else {
          state = state.copyWith(
            status: WidgetSyncStatus.error,
            errorMessage: 'Failed to deploy widget frame strip',
          );
        }
      } else {
        // --- Legacy Pipeline Fallback ---
        final activeEvent = _ref.read(currentActiveEventProvider);
        final theme = themeOverride ?? ExpressiveTheme.light(settings.seedColor);
        await _ref.read(syncDialWidgetUseCaseProvider).execute(
          events: events,
          activeEvent: activeEvent,
          currentTime: now,
          settings: settings,
          theme: theme,
        );

        if (!mounted || _isDisposed) return;

        state = state.copyWith(
          status: WidgetSyncStatus.success,
          lastSyncTime: DateTime.now(),
          errorMessage: null,
        );
      }
    } catch (e, st) {
      debugPrint('WidgetSyncCoordinator._performSync error: $e\n$st');
      if (!mounted || _isDisposed) return;
      state = state.copyWith(
        status: WidgetSyncStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final widgetSyncCoordinatorProvider =
    StateNotifierProvider<WidgetSyncCoordinator, WidgetSyncState>((ref) {
      return WidgetSyncCoordinator(ref);
    });
