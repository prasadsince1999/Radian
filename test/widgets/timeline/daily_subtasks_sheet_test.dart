import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/timeline/daily_subtasks_sheet.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('DailySubtasksSheet Widget Tests', () {
    late FakeEventRepository fakeRepo;
    final testDate = DateTime(2026, 9, 7, 10, 0);

    setUp(() {
      fakeRepo = FakeEventRepository();
    });

    testWidgets('renders empty state when day has no subtasks', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            eventRepositoryProvider.overrideWithValue(fakeRepo),
            selectedDayProvider.overrideWith((ref) => testDate),
            currentTimeProvider.overrideWith((ref) => Stream.value(testDate)),
          ],
          child: const MaterialApp(home: Scaffold(body: DailySubtasksSheet())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Daily Subtasks'), findsOneWidget);
      expect(find.text('No Subtasks For This Day'), findsOneWidget);
    });

    testWidgets(
      'renders list of subtasks independently with parent badge and toggles completion',
      (tester) async {
        final subtask1 = SubtaskItem(
          id: 'sub-1',
          parentEventId: 'event-1',
          title: 'Review Pull Request',
          isCompleted: false,
          startTime: const TimeOfDay(hour: 9, minute: 30),
          endTime: const TimeOfDay(hour: 10, minute: 15),
        );
        final subtask2 = SubtaskItem(
          id: 'sub-2',
          parentEventId: 'event-1',
          title: 'Merge Branch',
          isCompleted: true,
          startTime: const TimeOfDay(hour: 10, minute: 15),
          endTime: const TimeOfDay(hour: 10, minute: 45),
        );

        final parentEvent = SectorEvent(
          id: 'event-1',
          title: 'Coding Sprint',
          start: DateTime(2026, 9, 7, 9, 0),
          end: DateTime(2026, 9, 7, 11, 0),
          colorHex: '#3B82F6',
          subtaskItems: [subtask1, subtask2],
        );

        await fakeRepo.addEvent(parentEvent);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              selectedDayProvider.overrideWith((ref) => testDate),
              currentTimeProvider.overrideWith((ref) => Stream.value(testDate)),
            ],
            child: const MaterialApp(
              home: Scaffold(body: DailySubtasksSheet()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify header and progress
        expect(find.text('Daily Subtasks'), findsOneWidget);
        expect(find.text('1 of 2 completed'), findsOneWidget);
        expect(find.text('50%'), findsOneWidget);

        // Verify subtasks are rendered independently
        expect(find.text('Review Pull Request'), findsOneWidget);
        expect(find.text('Merge Branch'), findsOneWidget);
        expect(find.text('Coding Sprint'), findsNWidgets(2));

        // Toggle first subtask completion via its checkbox key
        final checkboxFinder = find.byKey(
          const ValueKey('subtask_checkbox_sub-1'),
        );
        expect(checkboxFinder, findsOneWidget);
        await tester.tap(checkboxFinder);
        await tester.pumpAndSettle();

        // Check repository update
        final events = await fakeRepo.getAllEvents();
        final updatedParent = events.firstWhere((e) => e.id == 'event-1');
        final updatedSub = updatedParent.subtaskItems.firstWhere(
          (s) => s.id == 'sub-1',
        );
        expect(updatedSub.isCompleted, isTrue);
      },
    );
  });
}
