import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/fab/expressive_speed_dial_fab.dart';

void main() {
  group('ExpressiveSpeedDialFab Widget Tests', () {
    testWidgets('renders hero button with icon and tooltip', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ExpressiveSpeedDialFab(
              tooltip: 'Add Block',
              actions: const [
                SpeedDialAction(
                  id: 'focus',
                  icon: Icons.bolt_rounded,
                  label: 'Focus Block',
                ),
              ],
              onActionSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Add Block'), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      // Before expansion, action label is not visible
      expect(find.text('Focus Block'), findsNothing);
    });

    testWidgets('expands actions on tap and selects action', (tester) async {
      String? selectedId;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            floatingActionButton: ExpressiveSpeedDialFab(
              actions: const [
                SpeedDialAction(
                  id: 'focus',
                  icon: Icons.bolt_rounded,
                  label: '90m Focus',
                ),
                SpeedDialAction(
                  id: 'nap',
                  icon: Icons.bedtime_rounded,
                  label: '25m Nap',
                ),
              ],
              onActionSelected: (id) => selectedId = id,
            ),
          ),
        ),
      );

      // Tap hero button to expand
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(find.text('90m Focus'), findsOneWidget);
      expect(find.text('25m Nap'), findsOneWidget);

      // Tap the focus action
      await tester.tap(find.byIcon(Icons.bolt_rounded));
      await tester.pumpAndSettle();

      expect(selectedId, 'focus');
    });
  });
}
