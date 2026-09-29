/// Feature flags for the new Dial Engine.
///
/// All new engine code runs behind these flags so the old code path stays
/// runnable until Phase 9 sign-off.
library;

/// Central feature flags for the dial engine rewrite.
///
/// Defaults are chosen so the app ships with the **old** pipeline until
/// each phase is signed off.
abstract final class DialEngineFlags {
  /// Master switch for the new engine pipeline.
  ///
  /// When `false` (default), the app uses the existing `FisheyeTimeLens` +
  /// `DialSectorLayoutStretcher` + `ConcentricSolver` path.
  ///
  /// When `true`, the app uses the new `DialModelBuilder` pipeline:
  /// `HorizonSelector → WarpSolver → RingAssigner → ContentPlanner → DialModel`.
  ///
  /// Flipped to `true` at the end of Phase 5 after owner sign-off.
  static bool newEngine = true;

  /// When `true`, the widget uses the Frame Strip architecture (Phase 6)
  /// instead of the per-minute Flutter re-render.
  static bool widgetFrameStrip = false;

  /// When `true`, time is stored with timezone info (Phase 1).
  /// Existing offset-less data is migrated on first launch.
  static bool timeZoneAware = false;
}
