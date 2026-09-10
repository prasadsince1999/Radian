import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/presentation/widgets/controls/elastic_push_segment_row.dart';

void main() {
  group('ElasticPushSegmentRow Widget Tests', () {
    testWidgets('renders all options with labels and icons', (tester) async {
      int selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ElasticPushSegmentRow(
              options: const [
                SegmentOption(label: '12H', icon: Icons.schedule_rounded),
                SegmentOption(label: '24H', icon: Icons.timelapse_rounded),
              ],
              selectedIndex: selected,
              onOptionSelected: (idx) => selected = idx,
            ),
          ),
        ),
      );

      expect(find.text('12H'), findsOneWidget);
      expect(find.text('24H'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      expect(find.byIcon(Icons.timelapse_rounded), findsOneWidget);
    });

    testWidgets(
      'triggers onOptionSelected callback on tap and updates selection',
      (tester) async {
        int selected = 0;
        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setState) {
              return MaterialApp(
                home: Scaffold(
                  body: ElasticPushSegmentRow(
                    options: const [
                      SegmentOption(label: '12H'),
                      SegmentOption(label: '24H'),
                    ],
                    selectedIndex: selected,
                    onOptionSelected: (idx) {
                      setState(() {
                        selected = idx;
                      });
                    },
                  ),
                ),
              );
            },
          ),
        );

        expect(selected, 0);
        await tester.tap(find.text('24H'));
        await tester.pumpAndSettle();

        expect(selected, 1);
      },
    );
  });
}
