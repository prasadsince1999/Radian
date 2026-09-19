import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/components/subtask_timeline_slider.dart';

void main() {
  group('SubtaskTimelineSlider Widget Tests', () {
    testWidgets('renders start, end vertical times, subtask pill and presets', (
      tester,
    ) async {
      TimeOfDay currentStart = const TimeOfDay(hour: 10, minute: 0);
      TimeOfDay currentEnd = const TimeOfDay(hour: 11, minute: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SubtaskTimelineSlider(
                  parentStartTime: const TimeOfDay(hour: 9, minute: 0),
                  parentEndTime: const TimeOfDay(hour: 12, minute: 0),
                  subtaskStartTime: currentStart,
                  subtaskEndTime: currentEnd,
                  parentColor: Colors.deepPurple,
                  is24Hour: false,
                  parentTitle: 'Deep Work',
                  onChanged: (newStart, newEnd) {
                    setState(() {
                      currentStart = newStart;
                      currentEnd = newEnd;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header and vertical time labels
      expect(find.text('SUBTASK TIMING'), findsOneWidget);
      expect(find.text('START'), findsOneWidget);
      expect(find.text('END'), findsOneWidget);
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('12:00'), findsOneWidget);

      // Verify Within block badge is removed
      expect(find.textContaining('Within block:'), findsNothing);

      // Verify pill edge caps render subtask start and end times
      expect(find.textContaining('10:00'), findsWidgets);
      expect(find.textContaining('11:00'), findsWidgets);
      expect(find.text('60 min'), findsOneWidget); // Header badge
      expect(find.text('1h'), findsOneWidget); // Center duration

      // Drag right end cap to adjust duration
      await tester.drag(
        find.textContaining('11:00').first,
        const Offset(30, 0),
      );
      await tester.pumpAndSettle();

      expect(currentEnd.minute, isNot(equals(0)));
    });

    testWidgets('handles overnight parent block across midnight correctly', (
      tester,
    ) async {
      TimeOfDay currentStart = const TimeOfDay(hour: 22, minute: 0);
      TimeOfDay currentEnd = const TimeOfDay(hour: 1, minute: 0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return SubtaskTimelineSlider(
                  parentStartTime: const TimeOfDay(
                    hour: 20,
                    minute: 0,
                  ), // 8:00 PM
                  parentEndTime: const TimeOfDay(hour: 2, minute: 0), // 2:00 AM
                  subtaskStartTime: currentStart,
                  subtaskEndTime: currentEnd,
                  parentColor: Colors.blueAccent,
                  is24Hour: false,
                  onChanged: (newStart, newEnd) {
                    setState(() {
                      currentStart = newStart;
                      currentEnd = newEnd;
                    });
                  },
                );
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('8:00'), findsOneWidget);
      expect(find.text('PM'), findsWidgets);
      expect(find.text('2:00'), findsOneWidget);
      expect(find.text('AM'), findsWidgets);

      // Verify live edge caps on subtask pill
      expect(find.textContaining('10:00'), findsWidgets);
      expect(find.textContaining('1:00'), findsWidgets);
    });
  });
}
