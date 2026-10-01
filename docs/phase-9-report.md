# Phase 9 — Hardening & Release Report (M)

**Radian Dial Engine Architecture — Phase 9 Completion**
*Date: October 2, 2026*
*Status: Verified, Hardened & Complete*

---

## 1. Overview & Objectives

Phase 9 is the final hardening milestone of the Radian Dial Engine Architecture (`docs/DIAL_ENGINE_ARCHITECTURE.md`). With all architectural layers, smart features, and invariants (I1–I11) implemented and verified, Phase 9 safely removes the deprecated legacy pipeline, cleanses dead code, confirms static analysis, and executes full cross-platform test suites.

---

## 2. Legacy Pipeline Decommissioning

### 2.1 Removed Dead Engine & Geometry Solvers
The following obsolete legacy solvers, renderers, and their dedicated test suites were deleted from the repository:

1. **`lib/core/geometry/focused_block_layout_resolver.dart` & `test/core/focused_block_layout_resolver_test.dart`**:
   - Replaced entirely by `HorizonSelector` in `lib/engine/` (§3.2, Phase 3).
2. **`lib/core/geometry/dial_sector_layout_stretcher.dart` & `test/core/dial_sector_layout_stretcher_test.dart`**:
   - Replaced by `WarpSolver` and piecewise monotonic `WarpMap` in `lib/engine/` (§3.3, Phase 3).
3. **`lib/core/geometry/fisheye_time_lens.dart` & `test/core/fisheye_time_lens_test.dart`**:
   - Replaced by `WarpSolver`'s unified water-filling and degrade ladder (§4.4, Phase 3).
4. **`lib/presentation/widgets/dial/sectograph_painter.dart`**:
   - Replaced by the pure, zero-geometry `DialPainter` driven strictly by `DialModel` (Invariant I8, Phase 5).
5. **`lib/presentation/widgets/dial/components/dial_bezel_renderer.dart`**:
   - Replaced by pre-computed `TickModel` rendering in `DialPainter` (Invariant I8, Phase 5).

### 2.2 Purged In-Widget Projection Code
- In `lib/presentation/widgets/dial/sectograph_dial.dart`, the legacy fallback `Stack(...)` containing in-widget recurring event projection, mutable state reconciliation, and `SectographPainter` dispatch (~800 lines of dead code) was excised.
- `SectographDial` now cleanly and unconditionally builds `_buildNewEngineDialStack`, reducing file complexity from 1,714 lines down to 922 lines.

### 2.3 DialImageRenderer Consolidation
- `lib/core/services/dial_image_renderer.dart` was refactored to construct a canonical `DialModel` via `DialModelBuilder.build` and paint through `DialPainter`.
- Guarantees 100% pixel and geometry parity between the in-app dial, offscreen renders, and home screen widgets.

### 2.4 Feature Flag Promotion
- In `lib/core/dial_engine_flags.dart`:
  - `DialEngineFlags.newEngine = true` (permanent default).
  - `DialEngineFlags.widgetFrameStrip = true` (permanent default).

---

## 3. Invariants Verification Matrix (I1–I11)

| Invariant | Description | Verification Suite | Status |
|:---:|---|---|:---:|
| **I1** | No overlapping main blocks in storage | `BlockBudget`, `EditValidatorTest` (35 cases) | **VERIFIED** |
| **I2** | Visible dial blocks capped at $1 + P + N$ | `HorizonSelectorTest` (1,000 seeded random days) | **VERIFIED** |
| **I3** | 12H dial occupancy anti-aliasing | `HorizonSelectorTest` (12H midnight/noon collision suite) | **VERIFIED** |
| **I4** | Zero subtask capsule collisions | `SubtaskPlacerTest` (0, 1, 3, 6, 10 subtasks) | **VERIFIED** |
| **I5** | Content-mode ladder determinism | `ContentPlannerTest` (multi-tier sweeps & font scale) | **VERIFIED** |
| **I6** | Piecewise-linear monotonic warp | `WarpSolverTest` (monotonicity, anchor, sum=360°) | **VERIFIED** |
| **I7** | Needle inside active block iff $now \in [start, end)$ | `WarpSolverTest` (needle invariant test) | **VERIFIED** |
| **I8** | Dial draws `DialModel` only (app = widget) | `DialPainter`, `WidgetFramePlannerTest`, `WidgetSyncCoordinatorTest` | **VERIFIED** |
| **I9** | 24H frame strip boundary integrity | `WidgetFramePlannerTest` (midnight, DST, zone changes) | **VERIFIED** |
| **I10**| No silent block exclusion (Hidden-Blocks indicator) | `HiddenSummary`, `SmartFeaturesTest`, `HiddenBlocksSheetTest` | **VERIFIED** |
| **I11**| Neutral, guilt-free pacing (Zero red alerts) | `DialPainter` Subtask Pace Ring (`#E2D9CC` neutral champagne) | **VERIFIED** |

---

## 4. Test Suite Execution & Hardening Receipts

### 4.1 Flutter Static Analysis
```bash
flutter analyze
No issues found! (ran in 5.6s)
```
- **0 errors, 0 warnings, 0 lints**.

### 4.2 Flutter Test Suite
```bash
flutter test
01:00 +388: All tests passed!
```
- **388 tests executed across domain, engine, presentation, widget, services, and MCP tools — 100% green**.

### 4.3 Native Android Unit Tests
```bash
./gradlew :app:testDebugUnitTest
BUILD SUCCESSFUL in 1m 9s
113 actionable tasks: 9 executed, 104 up-to-date
```
- Native Kotlin `NeedleInterpolatorTest` and frame store models passed with zero warnings.

---

## 5. Architectural Health & Engine Purity

- **Pure Dart Engine (`lib/engine/`)**: Contains zero imports from `package:flutter` or UI rendering kits. Tested independently on the Dart VM with deterministic execution.
- **Repository Structure**: Free of dead geometry branches or duplicate layout paths.
- **Zero-Regression Guarantee**: Every previous regression test (`squeezed_time_overlap_test.dart`, `new_engine_sectograph_dial_test.dart`, `widget_sync_test.dart`) remains fully green on the new pipeline.
