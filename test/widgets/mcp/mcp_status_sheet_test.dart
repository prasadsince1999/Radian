import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/core/constants/app_strings.dart';
import 'package:sectograph_mcp/presentation/widgets/mcp/mcp_status_sheet.dart';

void main() {
  group('McpStatusSheet Widget Tests', () {
    testWidgets('renders hosted 24/7 server UI with Name and Cloudflare URL', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: McpStatusSheet())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI Agent & MCP Hub'), findsOneWidget);
      expect(find.text('Hosted 24/7 • Cloudflare Edge'), findsOneWidget);
      expect(find.text('Gemini'), findsOneWidget);
      expect(find.text('Claude'), findsOneWidget);
      expect(find.text('ChatGPT'), findsOneWidget);
      expect(find.text('Cloud Sync'), findsNothing);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text(AppStrings.appName), findsOneWidget);
      expect(find.text('Server URL'), findsOneWidget);
      expect(find.text(AppStrings.cloudflareMcpEndpoint), findsOneWidget);
      expect(find.text('Copy URL for Gemini'), findsOneWidget);

      // Verify odd developer settings are completely removed
      expect(find.text('Local Wi-Fi'), findsNothing);
      expect(find.text('USB ADB'), findsNothing);
      expect(find.textContaining('adb reverse'), findsNothing);
      expect(find.textContaining('npx untun'), findsNothing);
    });

    testWidgets('switches to Claude tab and renders config', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: McpStatusSheet())),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Claude tab
      await tester.tap(find.text('Claude'));
      await tester.pumpAndSettle();

      expect(find.text('Claude Desktop & Cursor'), findsOneWidget);
      expect(find.text('Copy Configuration'), findsOneWidget);
    });
  });
}
