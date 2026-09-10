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
  int _selectedConnectorMode = 0; // 0: Public HTTPS, 1: Local Wi-Fi, 2: USB ADB

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
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied $label to clipboard!',
          style: TextStyle(
            color: colorScheme.brightness == Brightness.dark
                ? colorScheme.onSurface
                : colorScheme.onInverseSurface,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        backgroundColor: colorScheme.brightness == Brightness.dark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.inverseSurface,
        behavior: SnackBarBehavior.fixed,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showTunnelConfigDialog(
    BuildContext context,
    String currentUrl,
  ) async {
    final textController = TextEditingController(text: currentUrl);
    final colorScheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.link_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Public HTTPS Tunnel',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Google Gemini Spark runs on cloud servers and requires a public HTTPS URL (e.g., from Cloudflare Tunnel or ngrok) ending in /mcp.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Public Tunnel URL',
                hintText: 'https://xxxx.trycloudflare.com/mcp',
                hintStyle: TextStyle(fontSize: 12, color: colorScheme.outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste_rounded, size: 18),
                  tooltip: 'Paste',
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data?.text != null) {
                      textController.text = data!.text!.trim();
                    }
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (currentUrl.isNotEmpty)
            TextButton(
              onPressed: () {
                ref
                    .read(mcpServerControllerProvider.notifier)
                    .setPublicTunnelUrl('');
                Navigator.of(ctx).pop();
              },
              child: Text('Clear', style: TextStyle(color: colorScheme.error)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref
                  .read(mcpServerControllerProvider.notifier)
                  .setPublicTunnelUrl(textController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mcpState = ref.watch(mcpServerControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final claudeConfig =
        '''
// Claude Desktop (claude_desktop_config.json)
{
  "mcpServers": {
    "${AppStrings.appName}": {
      "url": "${mcpState.effectiveMcpUrl}"
    }
  }
}''';

    final chatGptAction = mcpState.openApiUrl;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
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
                      Icons.hub_rounded,
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
                    Tab(text: 'Gemini & Connectors'),
                    Tab(text: 'Claude Desktop'),
                    Tab(text: 'ChatGPT Action'),
                    Tab(text: 'Live Logs'),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Tab contents
              AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  switch (_tabController.index) {
                    case 0:
                      return _buildGeminiConnectorTab(
                        context,
                        mcpState: mcpState,
                        colorScheme: colorScheme,
                      );
                    case 1:
                      return _buildConfigTab(
                        context,
                        colorScheme: colorScheme,
                        title: 'Claude Desktop & Cursor',
                        description: 'Add Radian to your Claude Desktop or Cursor configuration to let AI inspect and plan your circular dial:',
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
                        description: 'Paste this live OpenAPI 3.0 URL into your Custom GPT Action schema so ChatGPT can schedule your day:',
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
      ),
    );
  }

  Widget _buildGeminiConnectorTab(
    BuildContext context, {
    required McpServerState mcpState,
    required ColorScheme colorScheme,
  }) {
    String currentUrl;
    if (_selectedConnectorMode == 0) {
      currentUrl = mcpState.publicTunnelUrl.trim().isNotEmpty
          ? mcpState.effectiveMcpUrl
          : 'https://<your-tunnel>.trycloudflare.com/mcp';
    } else if (_selectedConnectorMode == 1) {
      currentUrl = mcpState.localMcpUrl;
    } else {
      currentUrl = mcpState.loopbackMcpUrl;
    }

    final hasCustomTunnel = mcpState.publicTunnelUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Mode selector chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildModeChip(
                label: 'Public HTTPS (Gemini)',
                icon: Icons.public_rounded,
                isSelected: _selectedConnectorMode == 0,
                onTap: () => setState(() => _selectedConnectorMode = 0),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                label: 'Local Wi-Fi',
                icon: Icons.wifi_rounded,
                isSelected: _selectedConnectorMode == 1,
                onTap: () => setState(() => _selectedConnectorMode = 1),
                colorScheme: colorScheme,
              ),
              const SizedBox(width: 8),
              _buildModeChip(
                label: 'USB ADB',
                icon: Icons.usb_rounded,
                isSelected: _selectedConnectorMode == 2,
                onTap: () => setState(() => _selectedConnectorMode = 2),
                colorScheme: colorScheme,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Custom Connector Card (matches User Screenshot)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Header: Name
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Name',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          AppStrings.appName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy Name',
                    onPressed: () => _copyToClipboard(
                      AppStrings.appName,
                      'Name',
                      colorScheme,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 12),

              // Card Body: Server URL
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Server URL',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurfaceVariant,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        SelectableText(
                          currentUrl,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color:
                                (_selectedConnectorMode == 0 &&
                                    !hasCustomTunnel)
                                ? colorScheme.outline
                                : colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy Server URL',
                    onPressed: () {
                      if (_selectedConnectorMode == 0 && !hasCustomTunnel) {
                        _showTunnelConfigDialog(
                          context,
                          mcpState.publicTunnelUrl,
                        );
                      } else {
                        _copyToClipboard(currentUrl, 'Server URL', colorScheme);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Action Buttons: Copy for Gemini Spark & Configure Tunnel
        if (_selectedConnectorMode == 0) ...[
          if (!hasCustomTunnel) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gemini Spark runs in the cloud and requires a public HTTPS URL. Set your tunnel URL below.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          BouncyPressable(
            scaleDownFactor: 0.95,
            onTap: () =>
                _showTunnelConfigDialog(context, mcpState.publicTunnelUrl),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: hasCustomTunnel
                    ? colorScheme.surfaceContainerHigh
                    : colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: hasCustomTunnel
                      ? colorScheme.outlineVariant
                      : Colors.transparent,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    hasCustomTunnel
                        ? Icons.edit_rounded
                        : Icons.add_link_rounded,
                    size: 17,
                    color: hasCustomTunnel
                        ? colorScheme.primary
                        : colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasCustomTunnel
                        ? 'Edit Public HTTPS Tunnel'
                        : 'Set Public HTTPS Tunnel URL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: hasCustomTunnel
                          ? colorScheme.primary
                          : colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasCustomTunnel) ...[
            const SizedBox(height: 10),
            BouncyPressable(
              scaleDownFactor: 0.95,
              onTap: () =>
                  _copyToClipboard(currentUrl, 'Gemini Spark URL', colorScheme),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 17,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Copy URL for Gemini Spark',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Cloudflare quick helper box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant, width: 1.1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick 1-Line Free Tunnel (PC Terminal)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Run via npx in your terminal to create a free HTTPS URL:',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'npx untun@latest tunnel --port ${mcpState.port}',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 15),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Copy Command',
                        onPressed: () => _copyToClipboard(
                          'npx untun@latest tunnel --port ${mcpState.port}',
                          'Tunnel Command',
                          colorScheme,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ] else if (_selectedConnectorMode == 1) ...[
          BouncyPressable(
            scaleDownFactor: 0.95,
            onTap: () =>
                _copyToClipboard(currentUrl, 'Local Wi-Fi URL', colorScheme),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 17,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Copy Wi-Fi MCP URL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Works for Claude Desktop, Cursor, and Antigravity on your local network without any internet tunnels.',
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
              height: 1.3,
            ),
          ),
        ] else ...[
          BouncyPressable(
            scaleDownFactor: 0.95,
            onTap: () =>
                _copyToClipboard(currentUrl, 'USB ADB URL', colorScheme),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.copy_rounded,
                    size: 17,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Copy USB ADB URL',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'adb reverse tcp:${mcpState.port} tcp:${mcpState.port}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Copy ADB Command',
                  onPressed: () => _copyToClipboard(
                    'adb reverse tcp:${mcpState.port} tcp:${mcpState.port}',
                    'ADB Command',
                    colorScheme,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return BouncyPressable(
      scaleDownFactor: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.4)
                : colorScheme.outlineVariant,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
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
          'No activity yet. Connect Gemini Spark, Claude, or ChatGPT!',
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
