import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/models/subtask_item.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/subtask_edit_sheet.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('SubtaskEditSheet Widget Tests', () {
    late FakeEventRepository fakeRepo;
    final testDate = DateTime(2026, 9, 20);

    setUp(() async {
      fakeRepo = FakeEventRepository();
      await fakeRepo.addEvent(
        SectorEvent(
          id: 'parent-block-1',
          title: 'Deep Work Block',
          start: DateTime(2026, 9, 20, 9, 0),
          end: DateTime(2026, 9, 20, 12, 0),
          colorHex: '#6366F1',
          category: 'Focus',
          iconName: 'laptop',
        ),
      );
    });

    testWidgets(
      'renders schedule section with start date, end date, and infinite toggle',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1400);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              selectedDayProvider.overrideWith((ref) => testDate),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SubtaskEditSheet(
                  initialParentEventId: 'parent-block-1',
                  initialDate: testDate,
                  parentStartTime: const TimeOfDay(hour: 9, minute: 0),
                  parentEndTime: const TimeOfDay(hour: 12, minute: 0),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify sections
        expect(find.text('New Subtask'), findsOneWidget);
        expect(find.text('SCHEDULE & DURATION'), findsOneWidget);
        expect(find.text('START DATE'), findsOneWidget);
        expect(find.text('END DATE'), findsOneWidget);
        expect(find.text('Same day'), findsOneWidget);
        expect(find.text('Infinite'), findsOneWidget);

        // Verify Reminder card is below date section
        expect(find.text('REMINDER'), findsOneWidget);
        expect(find.text('Subtask alert'), findsOneWidget);

        // Tap Infinite toggle
        await tester.tap(find.text('Infinite'));
        await tester.pumpAndSettle();

        // End date should now indicate Ongoing ∞
        expect(find.text('Ongoing ∞'), findsOneWidget);

        // Enter title and save
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Review Architecture Docs');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save Subtask'));
        await tester.pumpAndSettle();

        final updatedEvents = await fakeRepo.getAllEvents();
        expect(updatedEvents.first.subtaskItems.length, equals(1));
        final savedSubtask = updatedEvents.first.subtaskItems.first;
        expect(savedSubtask.title, equals('Review Architecture Docs'));
        expect(savedSubtask.isUnlimited, isTrue);
        expect(savedSubtask.isScheduledForDate(DateTime(2026, 9, 25)), isTrue);
      },
    );

    testWidgets(
      'editing existing subtask restores endDate and unlimited state',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1400);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final existing = SubtaskItem(
          id: 'subtask-1',
          parentEventId: 'parent-block-1',
          title: 'Ongoing Habit',
          isUnlimited: true,
          startTime: const TimeOfDay(hour: 9, minute: 15),
          endTime: const TimeOfDay(hour: 10, minute: 0),
          date: testDate,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              eventRepositoryProvider.overrideWithValue(fakeRepo),
              selectedDayProvider.overrideWith((ref) => testDate),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SubtaskEditSheet(
                  existingSubtask: existing,
                  initialDate: testDate,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Edit Subtask'), findsOneWidget);
        expect(find.text('Ongoing Habit'), findsOneWidget);
        expect(find.text('Ongoing ∞'), findsOneWidget);
        expect(find.text('Update Subtask'), findsOneWidget);
      },
    );
  });
}
