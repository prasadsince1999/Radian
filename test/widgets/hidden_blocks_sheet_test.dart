import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/dial_settings.dart';
import 'package:sectograph_mcp/engine/dial_model.dart';
import 'package:sectograph_mcp/engine/horizon_selector.dart';
import 'package:sectograph_mcp/engine/warp_map.dart';
import 'package:sectograph_mcp/presentation/widgets/dial/components/hidden_blocks_sheet.dart';

void main() {
  testWidgets('HiddenBlocksSheet renders title, reasons, and event list', (tester) async {
    final hiddenSummary = HiddenSummary(
      hiddenCount: 2,
      hiddenEvents: [
        HiddenEventInfo(
          eventId: 'ev-hidden-1',
          title: 'Evening Run',
          reason: 'exceedsHorizon:next>3',
          start: DateTime(2026, 10, 2, 19, 0),
          end: DateTime(2026, 10, 2, 20, 0),
          category: 'Fitness',
          colorHex: '#10B981',
        ),
        HiddenEventInfo(
          eventId: 'ev-hidden-2',
          title: 'Night Study Session',
          reason: 'aliasesWith:ev-morning-1',
          start: DateTime(2026, 10, 2, 22, 0),
          end: DateTime(2026, 10, 2, 23, 0),
          category: 'Learning',
          colorHex: '#8B5CF6',
        ),
      ],
    );

    final model = DialModel(
      signature: 'test-sig',
      warpKey: 'test-warp',
      is24HourMode: false,
      blocks: const [],
      hidden: hiddenSummary,
      warp: WarpMap.identity(),
      needle: const NeedleModel(
        displayDeg: 100.0,
        naturalDeg: 100.0,
        isInsideActiveBlock: false,
      ),
      ticks: const [],
      center: const CenterModel(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: HiddenBlocksSheet(
              model: model,
              settings: const DialSettings(is24HourMode: false),
            ),
          ),
        ),
      ),
    );

    // Verify header and count
    expect(find.text('Hidden Blocks (2)'), findsOneWidget);
    expect(find.text('Scheduled events hidden to maintain clarity (I10)'), findsOneWidget);

    // Verify hidden events
    expect(find.text('Evening Run'), findsOneWidget);
    expect(find.text('Night Study Session'), findsOneWidget);

    // Verify translated reasons
    expect(find.text('Beyond upcoming horizon (N=3)'), findsOneWidget);
    expect(find.text('12H angle collision with earlier block'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Try 24H View'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });
}
