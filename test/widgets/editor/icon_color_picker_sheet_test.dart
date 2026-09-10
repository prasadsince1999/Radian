import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/color_wheel_dialog.dart';
import 'package:sectograph_mcp/presentation/widgets/editor/icon_color_picker_sheet.dart';

void main() {
  group('IconColorPickerSheet Widget Tests', () {
    testWidgets('renders Icon header, search bar, grid, and bottom color row', (
      tester,
    ) async {
      (String, String)? selectedResult;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedResult = await IconColorPickerSheet.show(
                    context,
                    initialIconName: 'coffee',
                    initialColorHex: '#3B82F6',
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Icon'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);

      // Test Search filtering
      await tester.enterText(find.byType(TextField), 'swim');
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.pool_rounded), findsOneWidget);
      expect(find.byIcon(Icons.coffee_rounded), findsNothing);

      // Tap swimming icon
      await tester.tap(find.byIcon(Icons.pool_rounded));
      await tester.pumpAndSettle();

      // Tap 'Done'
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      expect(selectedResult, isNotNull);
      expect(selectedResult!.$1, equals('swimming'));
      expect(selectedResult!.$2, equals('#3B82F6'));
    });

    testWidgets(
      'ColorWheelDialog allows picking preset color and returns Color',
      (tester) async {
        Color? pickedColor;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () async {
                    pickedColor = await ColorWheelDialog.show(
                      context,
                      const Color(0xFF3B82F6),
                    );
                  },
                  child: const Text('Open Dialog'),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.text('Choose color'), findsOneWidget);
        expect(find.text('Recent Colors'), findsOneWidget);
        expect(find.text('CANCEL'), findsOneWidget);
        expect(find.text('OK'), findsOneWidget);

        // Tap OK
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(pickedColor, isNotNull);
      },
    );
  });
}
