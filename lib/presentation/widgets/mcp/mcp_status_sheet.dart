import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_layout_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/cloud_sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../controllers/cloud_sync_controller.dart';
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
            Icon(Icons.tune_rounded, color: colorScheme.primary),
            const SizedBox(width: 8),
            const Text(
              'Custom Endpoint',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'By default, Radian connects to the 24/7 hosted Cloudflare server. You can optionally specify a custom self-hosted endpoint.',
              style: TextStyle(fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              autofocus: true,
              style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Custom MCP Endpoint URL',
                hintText: AppStrings.cloudflareMcpEndpoint,
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
              child: Text(
                'Reset to Hosted',
                style: TextStyle(color: colorScheme.error),
              ),
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
// Claude Desktop & Cursor Configuration
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

              // Header: Hosted 24/7 Server
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Icon(
                      Icons.cloud_done_rounded,
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
                              decoration: const BoxDecoration(
                                color: AppColors.statusSuccess,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hosted 24/7 • Cloudflare Edge',
                              style: TextStyle(
                                color: theme.brightness == Brightness.dark
                                    ? AppColors.statusSuccess
                                    : AppColors.statusSuccessLight,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusSuccess.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.statusSuccess.withValues(alpha: 0.3),
                        width: 1.1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: theme.brightness == Brightness.dark
                              ? AppColors.statusSuccess
                              : AppColors.statusSuccessLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cloud 24/7',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: theme.brightness == Brightness.dark
                                ? AppColors.statusSuccess
                                : AppColors.statusSuccessLight,
                          ),
                        ),
                      ],
                    ),
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
                    Tab(text: 'Gemini'),
                    Tab(text: 'Claude'),
                    Tab(text: 'ChatGPT'),
                    Tab(text: 'Cloud Sync'),
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
                      return _buildCloudSyncTab(
                        context,
                        colorScheme: colorScheme,
                        isDark: theme.brightness == Brightness.dark,
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
    final currentUrl = mcpState.effectiveMcpUrl;
    final isCustom = mcpState.publicTunnelUrl.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cloud Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.25),
              width: 1.1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_done_rounded,
                color: colorScheme.primary,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isCustom
                      ? 'Custom endpoint active'
                      : 'Hosted 24/7 on Cloudflare Edge with Cloudflare D1.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Custom Connector Card (matches Google Gemini Connectors format)
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
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    tooltip: 'Copy Server URL',
                    onPressed: () =>
                        _copyToClipboard(currentUrl, 'Server URL', colorScheme),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Primary Action: 1-Tap Copy for Gemini
        BouncyPressable(
          scaleDownFactor: 0.95,
          onTap: () =>
              _copyToClipboard(currentUrl, 'Gemini Connector URL', colorScheme),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_rounded,
                  size: 18,
                  color: colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Copy URL for Gemini',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    color: colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Subtle Override Button
        Center(
          child: TextButton.icon(
            icon: Icon(
              isCustom ? Icons.tune_rounded : Icons.edit_note_rounded,
              size: 16,
            ),
            label: Text(
              isCustom
                  ? 'Edit Custom Endpoint Override'
                  : 'Custom Endpoint Override (Optional)',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            onPressed: () =>
                _showTunnelConfigDialog(context, mcpState.publicTunnelUrl),
          ),
        ),
      ],
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

  Widget _buildCloudSyncTab(
    BuildContext context, {
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    final syncState = ref.watch(cloudSyncControllerProvider);

    Color statusColor;
    String statusLabel;
    IconData statusIcon;

    switch (syncState.status) {
      case SyncStatus.syncing:
        statusColor = Colors.orange;
        statusLabel = 'Syncing in progress...';
        statusIcon = Icons.sync_rounded;
      case SyncStatus.synced:
        statusColor = isDark
            ? AppColors.statusSuccess
            : AppColors.statusSuccessLight;
        statusLabel = 'Synchronized with Cloudflare D1';
        statusIcon = Icons.cloud_done_rounded;
      case SyncStatus.offline:
        statusColor = isDark
            ? AppColors.statusError
            : AppColors.statusErrorLight;
        statusLabel = 'Network offline';
        statusIcon = Icons.cloud_off_rounded;
      case SyncStatus.error:
        statusColor = isDark
            ? AppColors.statusError
            : AppColors.statusErrorLight;
        statusLabel = 'Sync error';
        statusIcon = Icons.error_outline_rounded;
      case SyncStatus.idle:
        statusColor = colorScheme.outline;
        statusLabel = 'Ready to sync';
        statusIcon = Icons.cloud_queue_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 4),
        Text(
          'Cloudflare D1 Synchronization',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 15,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'All sectors and schedule changes sync seamlessly between your mobile dial and the hosted Cloudflare edge.',
          style: TextStyle(
            fontSize: 12,
            color: colorScheme.onSurfaceVariant,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),

        // Status Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Database',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Cloudflare D1 (Global)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Last Synced',
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    syncState.formattedLastSync,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Sync Now Button
        BouncyPressable(
          scaleDownFactor: 0.95,
          onTap: syncState.isSyncing
              ? null
              : () async {
                  final success = await ref
                      .read(cloudSyncControllerProvider.notifier)
                      .syncNow();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          success
                              ? 'Synced successfully with Cloudflare D1!'
                              : 'Sync completed or offline. Ready.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (syncState.isSyncing) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Syncing...',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.sync_rounded,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sync Now with Cloud',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
