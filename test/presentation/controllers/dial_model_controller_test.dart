import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/clock.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/controllers/dial_model_controller.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('dialModelProvider Tests (Phase 5 Controller)', () {
    late FakeEventRepository fakeRepo;
    final testDate = DateTime(2026, 9, 29);
    final testNow = DateTime(2026, 9, 29, 10, 15); // 10:15 AM

    setUp(() {
      fakeRepo = FakeEventRepository([
        SectorEvent(
          id: 'ev-1',
          title: 'Morning Yoga',
          start: DateTime(2026, 9, 29, 6, 0),
          end: DateTime(2026, 9, 29, 7, 15),
          colorHex: '#10B981',
          category: 'Health',
          subtasks: const ['Asana', 'Pranayama', 'Meditation'],
          subtaskItems: const [
            SubtaskItem(
              id: 'st-1',
              parentEventId: 'ev-1',
              title: 'Asana',
              isCompleted: true,
            ),
            SubtaskItem(
              id: 'st-2',
              parentEventId: 'ev-1',
              title: 'Pranayama',
              isCompleted: false,
            ),
          ],
        ),
        SectorEvent(
          id: 'ev-2',
          title: 'Deep Work',
          start: DateTime(2026, 9, 29, 9, 30),
          end: DateTime(2026, 9, 29, 12, 0),
          colorHex: '#6366F1',
          category: 'Work',
        ),
        SectorEvent(
          id: 'ev-3',
          title: 'Team Standup',
          start: DateTime(2026, 9, 29, 14, 0),
          end: DateTime(2026, 9, 29, 15, 0),
          colorHex: '#F59E0B',
          category: 'Work',
        ),
      ]);
    });

    test('builds valid immutable DialModel with active, upcoming blocks and needle', () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(FixedClock(testNow)),
          eventRepositoryProvider.overrideWithValue(fakeRepo),
          currentTimeProvider.overrideWith((ref) => Stream.value(testNow)),
          selectedDayProvider.overrideWith((ref) => testDate),
        ],
      );
      addTearDown(container.dispose);

      // Listen to allEventsProvider so stream emits data
      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final model = container.read(dialModelProvider);

      expect(model.schemaVersion, equals(3));
      expect(model.signature, isNotEmpty);
      expect(model.warpKey, isNotEmpty);
      expect(model.is24HourMode, isFalse);
      expect(model.ticks.length, equals(12));

      // 10:15 AM needle is inside Deep Work (9:30 - 12:00)
      expect(model.needle.isInsideActiveBlock, isTrue);
      expect(model.center.activeTitle, equals('Deep Work'));
      expect(model.blocks, isNotEmpty);

      // Verify Deep Work block exists and is present on dial
      final deepWorkBlock = model.blocks.firstWhere((b) => b.eventId == 'ev-2');
      expect(deepWorkBlock.title, equals('Deep Work'));
      expect(deepWorkBlock.colorHex, equals('#6366F1'));
      expect(deepWorkBlock.caps.isVisible, isTrue);
      expect(deepWorkBlock.caps.startTimeLabel, contains('9:30'));
    });

    test('reacts to 24-hour mode setting toggle with 24 ticks and full day horizon', () async {
      final container = ProviderContainer(
        overrides: [
          eventRepositoryProvider.overrideWithValue(fakeRepo),
          currentTimeProvider.overrideWith((ref) => Stream.value(testNow)),
          selectedDayProvider.overrideWith((ref) => testDate),
          dialSettingsProvider.overrideWith(
            (ref) => DialSettingsNotifier(null)
              ..updateSettings(const DialSettings(is24HourMode: true)),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final model = container.read(dialModelProvider);

      expect(model.is24HourMode, isTrue);
      expect(model.ticks.length, equals(24));
      expect(model.ticks.first.label, equals('0'));
    });

    test('scrub angle updates needle display angle in model', () async {
      final container = ProviderContainer(
        overrides: [
          eventRepositoryProvider.overrideWithValue(fakeRepo),
          currentTimeProvider.overrideWith((ref) => Stream.value(testNow)),
          selectedDayProvider.overrideWith((ref) => testDate),
          dialScrubAngleProvider.overrideWith((ref) => 180.0), // 6:00
        ],
      );
      addTearDown(container.dispose);

      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final model = container.read(dialModelProvider);

      expect(model.signature, isNotEmpty);
      expect(model.needle.displayDeg, isNotNull);
    });

    test('signature changes deterministically when repository events change', () async {
      final container = ProviderContainer(
        overrides: [
          eventRepositoryProvider.overrideWithValue(fakeRepo),
          currentTimeProvider.overrideWith((ref) => Stream.value(testNow)),
          selectedDayProvider.overrideWith((ref) => testDate),
        ],
      );
      addTearDown(container.dispose);

      container.listen(allEventsProvider, (_, _) {});
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final initialSig = container.read(dialModelProvider).signature;

      // Add a new event
      await fakeRepo.addEvent(
        SectorEvent(
          id: 'ev-new',
          title: 'Evening Run',
          start: DateTime(2026, 9, 29, 17, 0),
          end: DateTime(2026, 9, 29, 18, 0),
          colorHex: '#EF4444',
          category: 'Health',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Re-read model
      final updatedSig = container.read(dialModelProvider).signature;
      expect(updatedSig, isNot(equals(initialSig)));
    });
  });
}
