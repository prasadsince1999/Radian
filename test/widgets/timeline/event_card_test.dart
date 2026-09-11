import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/presentation/widgets/timeline/event_card.dart';

void main() {
  group('EventCard Widget Tests', () {
    testWidgets('renders title, time range, and category', (tester) async {
      final event = SectorEvent(
        id: 'ev-1',
        title: 'Team Standup',
        start: DateTime(2026, 9, 10, 10, 0),
        end: DateTime(2026, 9, 10, 10, 30),
        colorHex: '#3B82F6',
        category: 'Work',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              isSelected: false,
              isActive: false,
              is24HourMode: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Team Standup'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
    });

    testWidgets('renders subtasks chips when present', (tester) async {
      final event = SectorEvent(
        id: 'ev-2',
        title: 'Study Session',
        start: DateTime(2026, 9, 10, 14, 0),
        end: DateTime(2026, 9, 10, 18, 0),
        colorHex: '#F97316',
        category: 'Deep Focus',
        subtasks: ['Math quiz', 'Physics lab', 'Essay draft'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              isSelected: false,
              isActive: false,
              is24HourMode: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Math quiz'), findsOneWidget);
      expect(find.text('Physics lab'), findsOneWidget);
      expect(find.text('Essay draft'), findsOneWidget);
    });

    testWidgets('renders +N overflow chip when more than 4 subtasks', (
      tester,
    ) async {
      final event = SectorEvent(
        id: 'ev-3',
        title: 'Sprint Backlog',
        start: DateTime(2026, 9, 10, 9, 0),
        end: DateTime(2026, 9, 10, 12, 0),
        colorHex: '#10B981',
        category: 'Work',
        subtasks: ['Task A', 'Task B', 'Task C', 'Task D', 'Task E', 'Task F'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              isSelected: false,
              isActive: false,
              is24HourMode: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('Task A'), findsOneWidget);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.text('Task C'), findsOneWidget);
      expect(find.text('Task D'), findsOneWidget);
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('invokes onEdit on long press', (tester) async {
      var edited = false;
      final event = SectorEvent(
        id: 'ev-4',
        title: 'Design Review',
        start: DateTime(2026, 9, 10, 15, 0),
        end: DateTime(2026, 9, 10, 16, 0),
        colorHex: '#8B5CF6',
        category: 'Work',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              isSelected: false,
              isActive: false,
              is24HourMode: false,
              onTap: () {},
              onEdit: () {
                edited = true;
              },
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Design Review'));
      await tester.pumpAndSettle();

      expect(edited, isTrue);
    });

    testWidgets('renders expanded subtasks checklist when isSelected is true', (
      tester,
    ) async {
      final event = SectorEvent(
        id: 'ev-expanded',
        title: 'AI/ML Sprint',
        start: DateTime(2026, 9, 10, 20, 0),
        end: DateTime(2026, 9, 10, 23, 0),
        colorHex: '#8EA865',
        category: 'Code',
        subtasks: const [
          'LinAlg',
          'PyTorch',
          'Transformers',
          'Loss & Eval',
          'LeetCode',
        ],
        notes: 'Prepare for top tier AI research roles',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EventCard(
              event: event,
              isSelected: true,
              isActive: false,
              is24HourMode: false,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('SUBTASKS (5)'), findsOneWidget);
      expect(find.text('LinAlg'), findsOneWidget);
      expect(find.text('PyTorch'), findsOneWidget);
      expect(find.text('Transformers'), findsOneWidget);
      expect(find.text('Loss & Eval'), findsOneWidget);
      expect(find.text('LeetCode'), findsOneWidget);
      expect(
        find.text('Prepare for top tier AI research roles'),
        findsOneWidget,
      );
    });
  });
}
