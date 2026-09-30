import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/clock.dart';
import 'package:sectograph_mcp/core/dial_engine_flags.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/core/services/widget_frame_service.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/widget_sync_coordinator.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WidgetSyncCoordinator Unit Tests (Phase 6 Architecture)', () {
    late FakeEventRepository fakeRepo;
    final testNow = DateTime(2026, 9, 29, 8, 30);
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('widget_sync_test_');
      fakeRepo = FakeEventRepository([
        SectorEvent(
          id: 'ev-1',
          title: 'Morning Yoga',
          start: DateTime(2026, 9, 29, 6, 0),
          end: DateTime(2026, 9, 29, 7, 15),
          colorHex: '#10B981',
          category: 'Health',
        ),
        SectorEvent(
          id: 'ev-2',
          title: 'Deep Work',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 12, 0),
          colorHex: '#6366F1',
          category: 'Work',
        ),
      ]);
      WidgetFrameService.baseDirOverride = tempDir;
    });

    tearDown(() {
      WidgetFrameService.baseDirOverride = null;
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    test('Initializes with WidgetSyncStatus.idle', () {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(testNow)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final state = container.read(widgetSyncCoordinatorProvider);
      expect(state.status, equals(WidgetSyncStatus.idle));
      expect(state.lastSyncTime, isNull);
      expect(state.errorMessage, isNull);
    });

    test('syncNow in legacy pipeline (widgetFrameStrip = false) successfully synchronizes', () async {
      final originalFlag = DialEngineFlags.widgetFrameStrip;
      DialEngineFlags.widgetFrameStrip = false;
      addTearDown(() => DialEngineFlags.widgetFrameStrip = originalFlag);

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(testNow)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      // Listen to events so stream emits initial list
      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final coordinator = container.read(widgetSyncCoordinatorProvider.notifier);
      await coordinator.syncNow();

      final state = container.read(widgetSyncCoordinatorProvider);
      expect(state.status, equals(WidgetSyncStatus.success));
      expect(state.lastSyncTime, isNotNull);
      expect(state.errorMessage, isNull);
    });

    test('syncNow with Frame Strip (widgetFrameStrip = true) generates frame plan and deploys', () async {
      final originalFlag = DialEngineFlags.widgetFrameStrip;
      DialEngineFlags.widgetFrameStrip = true;
      addTearDown(() => DialEngineFlags.widgetFrameStrip = originalFlag);

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(testNow)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final coordinator = container.read(widgetSyncCoordinatorProvider.notifier);
      await coordinator.syncNow();

      final state = container.read(widgetSyncCoordinatorProvider);
      expect(state.status, equals(WidgetSyncStatus.success));
      expect(state.lastSyncTime, isNotNull);
      expect(state.lastDataVersion, isNotNull);
      expect(state.errorMessage, isNull);
    });

    test('Debounces rapid updates so multiple changes coalesce into one sync', () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(testNow)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      container.listen(widgetSyncCoordinatorProvider, (_, _) {});

      // Add multiple events rapidly
      fakeRepo.addEvent(
        SectorEvent(
          id: 'ev-rapid-1',
          title: 'Quick Check 1',
          start: DateTime(2026, 9, 29, 13, 0),
          end: DateTime(2026, 9, 29, 13, 15),
          colorHex: '#3B82F6',
        ),
      );

      fakeRepo.addEvent(
        SectorEvent(
          id: 'ev-rapid-2',
          title: 'Quick Check 2',
          start: DateTime(2026, 9, 29, 13, 15),
          end: DateTime(2026, 9, 29, 13, 30),
          colorHex: '#3B82F6',
        ),
      );

      // Before debounce window (800ms) expires, status remains idle
      await Future<void>.delayed(const Duration(milliseconds: 200));
      var state = container.read(widgetSyncCoordinatorProvider);
      expect(state.status, equals(WidgetSyncStatus.idle));

      // After debounce window (800ms) expires, wait for sync to complete
      var elapsed = 0;
      while (container.read(widgetSyncCoordinatorProvider).status != WidgetSyncStatus.success && elapsed < 4000) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        elapsed += 100;
      }
      state = container.read(widgetSyncCoordinatorProvider);
      expect(state.status, equals(WidgetSyncStatus.success));
      expect(state.lastSyncTime, isNotNull);
    });
  });
}
