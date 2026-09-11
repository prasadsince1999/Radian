/// Central layout dimensions, responsive breakpoints, and geometry constants.
abstract final class AppLayoutConstants {
  // --- Material 3 Window Size Class Breakpoints ---
  /// Compact width threshold (< 600dp: portrait phones).
  static const double compactWidthBreakpoint = 600.0;

  /// Medium width threshold (600dp - 840dp: foldables unfolded, small tablets, landscape phones).
  static const double mediumWidthBreakpoint = 840.0;

  /// Screen width threshold above which the layout switches to a two-column tablet view.
  static const double tabletBreakpoint = compactWidthBreakpoint;

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
  static const double innerRadiusRatio = 0.42;
  static const double routineTrackInnerOffset = 2.0;
  static const double routineTrackOuterMargin = 3.5;
  static const double dialSizeHeadroom = 36.0;

  // --- Standard Component Sizes ---
  static const double actionButtonSize = 36.0;
  static const double fabHeight = 48.0;
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;
}
