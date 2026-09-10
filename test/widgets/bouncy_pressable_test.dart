import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/theme/tactile_motion_tokens.dart';
import 'package:sectograph_mcp/presentation/widgets/common/bouncy_pressable.dart';

void main() {
  group('BouncyPressable Widget Tests', () {
    testWidgets('renders child content correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: BouncyPressable(child: Text('Press Me'))),
        ),
      );

      expect(find.text('Press Me'), findsOneWidget);
    });

    testWidgets('fires onTap callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BouncyPressable(
              onTap: () {
                tapped = true;
              },
              child: const Text('Press Me'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Press Me'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('animates scale on tap and springs back to 1.0', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: BouncyPressable(
                scaleDownFactor: 0.85,
                pressDownDuration: const Duration(milliseconds: 100),
                springBackDuration: const Duration(milliseconds: 200),
                onTap: () {},
                child: Container(
                  key: const ValueKey('box'),
                  width: 100,
                  height: 100,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ),
      );

      final transformFinder = find.descendant(
        of: find.byType(BouncyPressable),
        matching: find.byType(Transform),
      );

      // Initial scale is 1.0
      Transform transform = tester.widget(transformFinder);
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));

      // Tap the widget to trigger compression and spring back
      await tester.tap(find.byKey(const ValueKey('box')));
      await tester.pump(const Duration(milliseconds: 50));

      // Animation is in flight
      expect(find.byType(BouncyPressable), findsOneWidget);

      // Settle animation back to rest
      await tester.pumpAndSettle();

      transform = tester.widget(transformFinder);
      expect(transform.transform.getMaxScaleOnAxis(), closeTo(1.0, 0.01));
    });

    testWidgets('fires onLongPress when held', (tester) async {
      var longPressed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BouncyPressable(
              onLongPress: () {
                longPressed = true;
              },
              child: const Text('Hold Me'),
            ),
          ),
        ),
      );

      await tester.longPress(find.text('Hold Me'));
      await tester.pumpAndSettle();

      expect(longPressed, isTrue);
    });

    testWidgets(
      'returns bare child without GestureDetector when no callbacks provided',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(body: BouncyPressable(child: Text('Static Child'))),
          ),
        );

        expect(find.byType(GestureDetector), findsNothing);
        expect(find.text('Static Child'), findsOneWidget);
      },
    );

    testWidgets('BouncyPressable.fab sets pressScaleFab factor (0.88)', (
      tester,
    ) async {
      const widget = BouncyPressable.fab(onTap: null, child: SizedBox());

      expect(widget.scaleDownFactor, equals(TactileMotionTokens.pressScaleFab));
      expect(widget.scaleDownFactor, equals(0.88));
    });

    testWidgets(
      'BouncyPressable.standard sets pressScaleStandard factor (0.92)',
      (tester) async {
        const widget = BouncyPressable.standard(onTap: null, child: SizedBox());

        expect(
          widget.scaleDownFactor,
          equals(TactileMotionTokens.pressScaleStandard),
        );
        expect(widget.scaleDownFactor, equals(0.92));
      },
    );

    testWidgets('BouncyPressable.card sets pressScaleCard factor (0.96)', (
      tester,
    ) async {
      const widget = BouncyPressable.card(onTap: null, child: SizedBox());

      expect(
        widget.scaleDownFactor,
        equals(TactileMotionTokens.pressScaleCard),
      );
      expect(widget.scaleDownFactor, equals(0.96));
    });
  });
}
