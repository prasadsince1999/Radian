import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/health/m3_activity_heatmap.dart';

void main() {
  group('M3ActivityHeatmap Widget Tests', () {
    testWidgets('renders title, streak badge, and legend', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: M3ActivityHeatmap(currentStreak: 12, totalHours: 56),
            ),
          ),
        ),
      );

      expect(find.text('Routine Heat Map'), findsOneWidget);
      expect(find.text('12 Day Streak'), findsOneWidget);
      expect(find.text('56 Total Hours Scheduled'), findsOneWidget);
      expect(find.text('Less'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('renders 4 tile shapes without layout errors', (tester) async {
      for (final shape in HeatmapTileShape.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: M3ActivityHeatmap(
                  tileShape: shape,
                  currentStreak: 5,
                  totalHours: 20,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.text('Routine Heat Map'), findsOneWidget);
      }
    });
  });
}
