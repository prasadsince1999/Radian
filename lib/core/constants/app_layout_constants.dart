/// Central layout dimensions, responsive breakpoints, and geometry constants.
abstract final class AppLayoutConstants {
  // --- Breakpoints ---
  /// Screen width threshold above which the layout switches to a two-column tablet view.
  static const double tabletBreakpoint = 700.0;

  // --- Max Width Constraints ---
  /// Maximum width for modal sheets on wide screens / tablets.
  static const double modalMaxWidth = 600.0;

  /// Maximum width for the timeline card column on wide screens.
  static const double timelineMaxWidth = 680.0;

  // --- Modal Sheet Height Factors ---
  static const double dialSettingsModalHeightFactor = 0.78;
  static const double mcpSheetHeightFactor = 0.80;

  // --- Dial Geometry ---
  static const int scallopLobes = 12;
  static const double scallopAmp = 0.0;
  static const double innerRadiusRatio = 0.35;
  static const double routineTrackInnerOffset = 2.0;
  static const double routineTrackOuterMargin = 8.0;
  static const double dialSizeHeadroom = 48.0;

  // --- Standard Component Sizes ---
  static const double actionButtonSize = 36.0;
  static const double fabHeight = 48.0;
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;
}
