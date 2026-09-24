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
  static const double innerRadiusRatio = 0.34;
  static const double routineTrackInnerOffset = 1.0;
  static const double routineTrackOuterMargin = 1.8;
  static const double dialSizeHeadroom = 36.0;

  // --- Standard Component Sizes ---
  static const double actionButtonSize = 36.0;
  static const double fabHeight = 48.0;
  static const double dragHandleWidth = 36.0;
  static const double dragHandleHeight = 4.0;

  // --- Dial Capacity & Time Badge Geometry ---
  static const int maxDialVisibleBlocks = 10;
  static const int maxBlocks12H = 12;
  static const int maxBlocks24H = 18;
  static const double standardCapSpanDeg24H = 7.2;
  static const double standardCapSpanDeg12H = 9.2;
  static const double minSweepForCaps24H = 10.0;
  static const double minSweepForCaps12H = 14.0;

  // --- Content-Aware Natural Block Stretch Constants ---
  /// Minimum sweep angle in 24H mode so caps + icon + title keyword + duration fit with zero overlap.
  static const double minContentSweepDeg24H = 24.0;

  /// Minimum sweep angle in 12H mode so caps + icon + title keyword + duration fit with zero overlap.
  static const double minContentSweepDeg12H = 34.0;

  /// Minimum sweep angle in 12H mode for an active or focused block with subtasks so river pebble chips fit with generous breathing room.
  static const double minActiveSubtaskSweepDeg12H = 70.0;

  /// Minimum sweep angle in 24H mode for an active or focused block with subtasks.
  static const double minActiveSubtaskSweepDeg24H = 40.0;

  /// Computes the target sweep angle in 12H mode for an active or focused block based on subtask count.
  static double targetActiveSubtaskSweepDeg12H(int subtaskCount) {
    if (subtaskCount <= 1) return minActiveSubtaskSweepDeg12H;
    if (subtaskCount == 2) return 88.0;
    if (subtaskCount == 3) return 110.0;
    return (110.0 + (subtaskCount - 3) * 10.0).clamp(
      minActiveSubtaskSweepDeg12H,
      130.0,
    );
  }

  /// Computes the target sweep angle in 24H mode for an active or focused block based on subtask count.
  static double targetActiveSubtaskSweepDeg24H(int subtaskCount) {
    if (subtaskCount <= 1) return minActiveSubtaskSweepDeg24H;
    if (subtaskCount == 2) return 50.0;
    if (subtaskCount == 3) return 62.0;
    return (62.0 + (subtaskCount - 3) * 6.0).clamp(
      minActiveSubtaskSweepDeg24H,
      80.0,
    );
  }

  /// Minimum effective sweep angle threshold to display subtask river pebble chips.
  static const double minSubtaskPebbleSweepDeg12H = 10.0;

  /// Minimum effective sweep angle threshold to display subtask river pebble chips in 24H mode.
  static const double minSubtaskPebbleSweepDeg24H = 10.0;

  /// Minimum buffer preserved between distinct non-contiguous blocks on the dial face.
  static const double minInterBlockGapDeg = 3.5;
}
