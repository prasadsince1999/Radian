/// Central application strings, branding constants, storage keys, and network defaults.
abstract final class AppStrings {
  // --- Branding & Identity ---
  static const String appName = 'Radian';
  static const String appTagline = '360° AI-NATIVE TIME BLOCKING';
  static const String appVersion = '1.0.0';
  static const String appBuildNumber = '1';
  static const String githubUrl = 'https://github.com/prasadsince1999/Radian';

  // --- Storage Keys ---
  static const String eventsStorageKey = 'radian_events_v1';

  // --- MCP Network Defaults ---
  static const int mcpDefaultPort = 8080;
  static const String mcpFallbackHost = '127.0.0.1';
  static const String mcpServerName = 'radian-mcp';
  static const String mcpServerVersion = '1.0.0';

  // --- Common UI Copy ---
  static const String emptyTimelineTitle = 'No events scheduled for this day';
  static const String emptyTimelineSubtitle =
      'Tap the + button below or ask your AI assistant to plan';
  static const String jumpToToday = 'Jump to Today';
  static const String now = 'Now';
  static const String createBlock = 'Create Block';
  static const String saveChanges = 'Save Changes';
}
