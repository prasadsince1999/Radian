/// Central feature flags for the Radian dial engine.
///
/// Post-Phase 9: The new Dial Engine and Widget Frame Strip architecture
/// are permanent defaults. Legacy solvers have been removed.
library;

/// Central architecture flags for the Radian engine.
abstract final class DialEngineFlags {
  /// Unified [DialModelBuilder] engine pipeline (Permanent default: true).
  /// `HorizonSelector → WarpSolver → RingAssigner → ContentPlanner → DialModel`.
  static bool newEngine = true;

  /// Native home screen widget Frame Strip architecture (Permanent default: true).
  static bool widgetFrameStrip = true;

  /// Timezone-aware schedule storage (Phase 1).
  static bool timeZoneAware = true;
}
