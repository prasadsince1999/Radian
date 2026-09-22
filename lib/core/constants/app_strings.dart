/// Central application strings, branding constants, storage keys, and network defaults.
abstract final class AppStrings {
  // --- Branding & Identity ---
  static const String appName = 'Radian';
  static const String appTagline = '360° AI-NATIVE TIME BLOCKING';
  static const String appVersion = '1.0.15';
  static const String appBuildNumber = '16';
  static const String githubUrl = 'https://github.com/prasadsince1999/Radian';
  static const String websiteUrl = 'https://ksmxtech.com/radian';
  static const String ksmHomeUrl = 'https://ksmxtech.com';
  static const String supportEmail = 'support@ksmxtech.com';
  static const String xTwitterUrl = 'https://x.com/otto_explorer';
  static const String updateEndpoint =
      '$cloudflareMcpBaseUrl/api/updates/latest';

  // --- Storage Keys ---
  static const String eventsStorageKey = 'radian_events_v1';
  static const String mcpPublicTunnelUrlKey = 'mcp_public_tunnel_url';

  // --- MCP Network Defaults ---
  static const int mcpDefaultPort = 8080;
  static const String mcpFallbackHost = '127.0.0.1';
  static const String mcpServerName = 'radian-mcp';
  static const String mcpServerVersion = '1.0.15';

  // --- Cloudflare Hosted Server Defaults ---
  static const String cloudflareMcpBaseUrl =
      'https://sectograph-mcp.kpr25121999.workers.dev';
  static const String cloudflareMcpEndpoint = '$cloudflareMcpBaseUrl/mcp';
  static const String cloudflareOpenApiEndpoint =
      '$cloudflareMcpBaseUrl/api/openapi.json';
  static const String productionWebBaseUrl = 'https://ksmxtech.com/radian/app';

  // --- Common UI Copy ---
  static const String emptyTimelineTitle = 'No events scheduled for this day';
  static const String emptyTimelineSubtitle =
      'Tap the + button below or ask your AI assistant to plan';
  static const String jumpToToday = 'Jump to Today';
  static const String now = 'Now';
  static const String createBlock = 'Create Block';
  static const String saveChanges = 'Save Changes';
}
