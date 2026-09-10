import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../controllers/mcp_server_controller.dart';
import '../common/bouncy_pressable.dart';

class McpStatusSheet extends ConsumerStatefulWidget {
  const McpStatusSheet({super.key});

  @override
  ConsumerState<McpStatusSheet> createState() => _McpStatusSheetState();
}

class _McpStatusSheetState extends ConsumerState<McpStatusSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _copyToClipboard(String text, String label, ColorScheme colorScheme) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied $label to clipboard!',
          style: TextStyle(color: colorScheme.onPrimaryContainer),
        ),
        backgroundColor: colorScheme.primaryContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcpState = ref.watch(mcpServerControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final grokConfig =
        '''
// xAI Grok / Grok Bot Remote MCP Configuration
{
  "tools": [
    {
      "type": "mcp",
      "server_url": "${mcpState.sseUrl}"
    }
  ]
}''';

    final claudeConfig =
        '''
// Claude Desktop (claude_desktop_config.json)
{
  "mcpServers": {
    "${AppStrings.mcpServerName}": {
      "url": "${mcpState.sseUrl}"
    }
  }
}''';

    final chatGptAction = mcpState.openApiUrl;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: AppLayoutConstants.dragHandleWidth,
                height: AppLayoutConstants.dragHandleHeight,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header & Toggle
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.outlineVariant,
                      width: 1.2,
                    ),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Agent & MCP Hub',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: mcpState.isRunning
                                  ? AppColors.statusSuccess
                                  : AppColors.statusError,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            mcpState.isRunning
                                ? 'Server Active • Port ${mcpState.port}'
                                : 'Server Offline',
                            style: TextStyle(
                              color: mcpState.isRunning
                                  ? (theme.brightness == Brightness.dark
                                        ? AppColors.statusSuccess
                                        : AppColors.statusSuccessLight)
                                  : (theme.brightness == Brightness.dark
                                        ? AppColors.statusError
                                        : AppColors.statusErrorLight),
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: mcpState.isRunning,
                  activeThumbColor: colorScheme.primary,
                  activeTrackColor: colorScheme.primaryContainer,
                  inactiveThumbColor: colorScheme.outline,
                  inactiveTrackColor: colorScheme.surfaceContainer,
                  onChanged: (val) {
                    if (val) {
                      ref
                          .read(mcpServerControllerProvider.notifier)
                          .startServer();
                    } else {
                      ref
                          .read(mcpServerControllerProvider.notifier)
                          .stopServer();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab selector
            Container(
              height: 42,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: colorScheme.outlineVariant,
                  width: 1.2,
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                ),
                labelColor: colorScheme.onPrimaryContainer,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(text: 'Grok Bot (xAI)'),
                  Tab(text: 'Claude Desktop'),
                  Tab(text: 'ChatGPT Action'),
                  Tab(text: 'Live Logs'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Tab contents (hugs content tightly)
            AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                switch (_tabController.index) {
                  case 0:
                    return _buildConfigTab(
                      context,
                      colorScheme: colorScheme,
                      title: 'Grok Bot & xAI Remote MCP',
                      description: 'Connect Grok Bot or custom xAI assistants. Paste into grok.com/connectors or supply as remote MCP tool in your xAI API payload:',
                      code: grokConfig,
                      onCopy: () => _copyToClipboard(
                        grokConfig,
                        'Grok Configuration',
                        colorScheme,
                      ),
                    );
                  case 1:
                    return _buildConfigTab(
                      context,
                      colorScheme: colorScheme,
                      title: 'Claude Desktop & Cursor',
                      description: 'Add this server to your Claude Desktop config file to let Claude inspect and bulk-plan your circular dial:',
                      code: claudeConfig,
                      onCopy: () => _copyToClipboard(
                        claudeConfig,
                        'Claude Desktop Configuration',
                        colorScheme,
                      ),
                    );
                  case 2:
                    return _buildConfigTab(
                      context,
                      colorScheme: colorScheme,
                      title: 'ChatGPT Mobile & Custom Actions',
                      description: 'Paste this live OpenAPI 3.0 URL into your Custom GPT Action schema so ChatGPT can plan your day from your phone:',
                      code: chatGptAction,
                      onCopy: () => _copyToClipboard(
                        chatGptAction,
                        'OpenAPI URL',
                        colorScheme,
                      ),
                    );
                  case 3:
                  default:
                    return _buildLogsTab(
                      context,
                      mcpState.logs,
                      colorScheme,
                      theme.brightness == Brightness.dark,
                    );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigTab(
    BuildContext context, {
    required ColorScheme colorScheme,
    required String title,
    required String description,
    required String code,
    required VoidCallback onCopy,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
          ),
          child: SelectableText(
            code,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              color: colorScheme.primary,
              height: 1.45,
            ),
          ),
        ),
        const SizedBox(height: 14),
        BouncyPressable(
          scaleDownFactor: 0.94,
          onTap: onCopy,
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.copy_rounded, size: 16, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Copy Configuration',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogsTab(
    BuildContext context,
    List<String> logs,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    if (logs.isEmpty) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: Text(
          'No activity yet. Send an MCP tool call from Grok or ChatGPT!',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 240),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: logs.length,
        itemBuilder: (context, idx) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Text(
              logs[idx],
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: isDark
                    ? AppColors.statusSuccess
                    : AppColors.statusSuccessLight,
              ),
            ),
          );
        },
      ),
    );
  }
}
