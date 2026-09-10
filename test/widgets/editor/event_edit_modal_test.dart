import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/controllers/clock_controller.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/event_edit_modal.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/icon_color_picker_sheet.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('EventEditModal Widget Tests', () {
    late FakeEventRepository fakeRepo;
    final testDate = DateTime(2026, 9, 7);

    setUp(() {
      fakeRepo = FakeEventRepository();
    });

    testWidgets('renders New Time Block form elements', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Time Block'), findsOneWidget);
      expect(find.byType(TextField), findsNWidgets(2)); // Title & Subtasks
      expect(find.text('Deep Focus'), findsOneWidget);
      expect(find.text('Create Block'), findsOneWidget);
      expect(find.byKey(const ValueKey('select_icon_button')), findsOneWidget);
    });

    testWidgets('empty title prevents saving event', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Create Block'));
      await tester.pumpAndSettle();

      // Tap 'Create Block' without entering title
      await tester.tap(find.text('Create Block'));
      await tester.pumpAndSettle();

      // No event should be created in the repository
      final allEvents = await fakeRepo.getAllEvents();
      expect(allEvents, isEmpty);
    });

    testWidgets(
      'entering title, selecting icon via + button, and saving adds event with iconName',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Scaffold(body: EventEditModal(initialDate: testDate)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter title
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Coding Sprint');
        await tester.pumpAndSettle();

        // Tap '+' icon button to open picker
        final iconBtn = find.byKey(const ValueKey('select_icon_button'));
        await tester.tap(iconBtn);
        await tester.pumpAndSettle();

        // Tap 'coffee' icon tile in bottom sheet
        final coffeeIcon = find.byIcon(Icons.coffee_rounded);
        expect(coffeeIcon, findsOneWidget);
        await tester.tap(coffeeIcon);
        await tester.pumpAndSettle();

        // Tap 'Done' in icon sheet
        final doneBtn = find.text('Done');
        expect(doneBtn, findsOneWidget);
        await tester.tap(doneBtn);
        await tester.pumpAndSettle();

        // Tap 'Create Block'
        await tester.ensureVisible(find.text('Create Block'));
        await tester.tap(find.text('Create Block'));
        await tester.pumpAndSettle();

        final allEvents = await fakeRepo.getAllEvents();
        expect(allEvents.length, equals(1));
        expect(allEvents.first.title, equals('Coding Sprint'));
        expect(allEvents.first.iconName, equals('coffee'));
      },
    );

    testWidgets('enforces 30-character limit on event name', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, '123456789012345678901234567890EXTRA');
      await tester.pumpAndSettle();

      final titleWidget = tester.widget<TextField>(titleField);
      expect(titleWidget.controller?.text.length, lessThanOrEqualTo(30));
    });

    testWidgets('editing existing event updates repository', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existing = SectorEvent(
        id: 'existing-1',
        title: 'Original Title',
        start: DateTime(2026, 9, 7, 10, 0),
        end: DateTime(2026, 9, 7, 11, 0),
        colorHex: '#3B82F6',
        category: 'Work',
        iconName: 'laptop',
      );
      await fakeRepo.addEvent(existing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(
              body: EventEditModal(event: existing, initialDate: testDate),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Time Block'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);

      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Updated Title');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      final allEvents = await fakeRepo.getAllEvents();
      expect(allEvents.length, equals(1));
      expect(allEvents.first.title, equals('Updated Title'));
    });

    testWidgets('renders MiniSectorDial preview and duration slider', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify All-day toggle is present
      expect(find.byKey(const ValueKey('all_day_toggle')), findsOneWidget);

      // Verify Slider and bottom hero Create Block button
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('Create Block'), findsOneWidget);
    });

    testWidgets('deleting existing event via trash icon removes it from repo', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final existing = SectorEvent(
        id: 'to-delete',
        title: 'Delete Me',
        start: DateTime(2026, 9, 7, 14, 0),
        end: DateTime(2026, 9, 7, 15, 0),
        colorHex: '#EF4444',
      );
      await fakeRepo.addEvent(existing);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(
              body: EventEditModal(event: existing, initialDate: testDate),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find delete button
      final deleteBtn = find.byTooltip('Delete');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      final allEvents = await fakeRepo.getAllEvents();
      expect(allEvents, isEmpty);
    });

    testWidgets(
      'renders Date selection cards and updates Unlimited state dynamically',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Scaffold(body: EventEditModal(initialDate: testDate)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Start & End date cards and Unlimited toggle exist
        expect(find.byKey(const ValueKey('start_date_tile')), findsOneWidget);
        expect(find.byKey(const ValueKey('end_date_tile')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('unlimited_date_toggle')),
          findsOneWidget,
        );

        // Initially Unlimited is active
        expect(find.text('Unlimited'), findsOneWidget);
        expect(find.text('∞'), findsOneWidget);

        // Tap Unlimited toggle to switch to fixed end date
        await tester.tap(find.byKey(const ValueKey('unlimited_date_toggle')));
        await tester.pumpAndSettle();

        // End date should now show a formatted date
        expect(find.byKey(const ValueKey('end_date_tile')), findsOneWidget);
      },
    );

    testWidgets(
      'selecting weekly days (clock style) saves repeatDays and recurrence in repository',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Scaffold(body: EventEditModal(initialDate: testDate)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter title
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Morning Standup');
        await tester.pumpAndSettle();

        // Verify Repeat header exists
        expect(find.text('Repeat'), findsOneWidget);

        // Tap "M" (Monday) weekday bubble
        await tester.tap(find.text('M'));
        await tester.pumpAndSettle();

        // Unlimited toggle should appear
        expect(find.text('Unlimited'), findsOneWidget);
        expect(find.text('∞'), findsOneWidget);

        // Tap "Create Block"
        await tester.ensureVisible(find.text('Create Block'));
        await tester.tap(find.text('Create Block'));
        await tester.pumpAndSettle();

        final allEvents = await fakeRepo.getAllEvents();
        expect(allEvents.length, equals(1));
        final created = allEvents.first;
        expect(created.title, equals('Morning Standup'));
        expect(created.repeatDays, equals([1]));
        expect(created.recurrenceEndDate, isNull); // Unlimited
      },
    );

    testWidgets('selecting reminder chip saves reminderMinutes in repository', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Team Standup');
      await tester.pumpAndSettle();

      // Scroll to Reminder section and tap '15 min'
      await tester.ensureVisible(find.text('Reminder'));
      expect(find.text('15 min'), findsOneWidget);
      await tester.tap(find.text('15 min'));
      await tester.pumpAndSettle();

      // Tap 'Create Block'
      await tester.ensureVisible(find.text('Create Block'));
      await tester.tap(find.text('Create Block'));
      await tester.pumpAndSettle();

      final allEvents = await fakeRepo.getAllEvents();
      expect(allEvents.length, equals(1));
      expect(allEvents.first.title, equals('Team Standup'));
      expect(allEvents.first.reminderMinutes, equals(15));
    });

    testWidgets(
      'toggling All-day collapses time rows and updates dial centerText to 24h',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Scaffold(body: EventEditModal(initialDate: testDate)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Initially Start & End times are visible
        expect(find.byKey(const ValueKey('start_time_tile')), findsOneWidget);
        expect(find.byKey(const ValueKey('end_time_tile')), findsOneWidget);
        expect(find.byKey(const ValueKey('all_day_toggle')), findsOneWidget);

        // Tap the All-day toggle
        await tester.tap(find.byKey(const ValueKey('all_day_toggle')));
        await tester.pumpAndSettle();

        // Start & End times should be collapsed, and All-day banner should be visible
        expect(find.byKey(const ValueKey('start_time_tile')), findsNothing);
        expect(find.byKey(const ValueKey('end_time_tile')), findsNothing);
        expect(find.text('All-day Block'), findsOneWidget);
        expect(find.byType(Slider), findsNothing);
      },
    );

    testWidgets(
      'selecting color and icon in IconColorPickerSheet updates sector color on event',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(800, 1200);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
            child: MaterialApp(
              home: Scaffold(body: EventEditModal(initialDate: testDate)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Enter title
        final titleField = find.byType(TextField).first;
        await tester.enterText(titleField, 'Health Checkup');
        await tester.pumpAndSettle();

        // Open Icon & Color sheet
        final iconBtn = find.byKey(const ValueKey('select_icon_button'));
        await tester.tap(iconBtn);
        await tester.pumpAndSettle();

        // Verify Icon sheet is displayed
        expect(find.text('Icon'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);

        // Search for 'med'
        final searchField = find.descendant(
          of: find.byType(IconColorPickerSheet),
          matching: find.byType(TextField),
        );
        expect(searchField, findsOneWidget);
        await tester.enterText(searchField, 'med');
        await tester.pumpAndSettle();

        // Tap 'medication' icon
        final medIcon = find.byIcon(Icons.medication_rounded);
        expect(medIcon, findsOneWidget);
        await tester.tap(medIcon);
        await tester.pumpAndSettle();

        // Tap Done
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        // Tap Create Block
        await tester.ensureVisible(find.text('Create Block'));
        await tester.tap(find.text('Create Block'));
        await tester.pumpAndSettle();

        final allEvents = await fakeRepo.getAllEvents();
        expect(allEvents.length, equals(1));
        expect(allEvents.first.title, equals('Health Checkup'));
        expect(allEvents.first.iconName, equals('medication'));
      },
    );

    testWidgets('adding and removing subtasks persists in repository', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [eventRepositoryProvider.overrideWithValue(fakeRepo)],
          child: MaterialApp(
            home: Scaffold(body: EventEditModal(initialDate: testDate)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter title
      final titleField = find.byType(TextField).first;
      await tester.enterText(titleField, 'Cook Dinner');
      await tester.pumpAndSettle();

      // Enter subtask in subtask field
      final subtaskField = find.byType(TextField).last;
      await tester.ensureVisible(subtaskField);
      await tester.enterText(subtaskField, 'Chop Onions');
      await tester.pumpAndSettle();

      // Tap 'Add' button
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      // Enter second subtask
      await tester.enterText(subtaskField, 'Boil Pasta');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Chop Onions'), findsOneWidget);
      expect(find.text('Boil Pasta'), findsOneWidget);
      expect(find.text('Subtasks (2)'), findsOneWidget);

      // Save
      await tester.ensureVisible(find.text('Create Block'));
      await tester.tap(find.text('Create Block'));
      await tester.pumpAndSettle();

      final allEvents = await fakeRepo.getAllEvents();
      expect(allEvents.length, equals(1));
      expect(allEvents.first.title, equals('Cook Dinner'));
      expect(allEvents.first.subtasks, equals(['Chop Onions', 'Boil Pasta']));
    });
  });
}
