# Tasks: Smart 7-Block Focus Horizon & Dim Mode Removal

## Phase 1: Setup & Domain Refactor (Dim Mode Removal)

- [ ] T001 Remove `birdsEye` from `PastHoursStyle` in `lib/domain/models/dial_settings.dart` and set default `pastHoursStyle` to `focusedBlock`.
- [ ] T002 Update `lib/presentation/widgets/editor/components/dial_time_format_section.dart` to remove the "Bird's Eye" tile, presenting `Focused Blocks` (Smart 7-Block Horizon) and `Disappear` (Dynamic Sweep).
- [ ] T003 Fix any test references to `PastHoursStyle.birdsEye`.

## Phase 2: Foundational (7-Block Horizon Resolver)

- [ ] T004 Create `lib/core/geometry/focused_block_layout_resolver.dart`:
  - Input: `List<SectorEvent> allEvents`, `DateTime effectiveTime`, `SectorEvent? selectedEvent`.
  - Output: `FocusedHorizonResult`:
    - `activeEvent`: current/selected event.
    - `prevOuter`: `Prev 1` (immediately preceding event).
    - `prevInner`: `[Prev 2, Prev 3]` (two earlier preceding events).
    - `nextOuter`: `Next 1` (immediately upcoming event).
    - `nextInner`: `[Next 2, Next 3]` (two subsequent upcoming events).
    - `visibleEvents`: list of exactly the $\le 7$ events to render on the dial.
    - `outerEventIds`: IDs assigned to outer ring (`Prev 1, Active, Next 1, Selected`).
    - `innerEventIds`: IDs assigned to inner ring (`Prev 3, Prev 2, Next 2, Next 3`).
- [ ] T005 Unit tests in `test/core/focused_block_layout_resolver_test.dart` verifying 3+1+3 extraction, boundary cases (< 3 prev/next events), and exclusion of older/distant events.

## Phase 3: Dial & Painter Integration

- [ ] T006 Update `sectograph_dial.dart` to use `FocusedBlockLayoutResolver`:
  - When in `focusedBlock` mode, filter `computedEvents` to only the resolved 7 horizon events.
  - Update `PolarHitTest` radii mapping so outer and inner events are hit-tested at their exact ring tracks.
- [ ] T007 Update `sectograph_painter.dart`:
  - Assign `outerROut` to `outerRIn` for outer ring events (`Prev 1, Active, Next 1`).
  - Assign `innerROut` to `innerRIn` for inner ring events (`Prev 3, Prev 2, Next 2, Next 3`).
  - Implement **Two-Stage Hierarchical Red Hour Indicator Needle**:
    - Inner hairline (1.5dp, 50% alpha) from hub to `outerRIn`.
    - Outer bold crimson needle (3.2dp with glow) across active block from `outerRIn` to outer rim.
    - Sun/moon beacon at outer rim.
  - Scope concentric divider stroke to only outline outer focus sectors at `outerRIn`.

## Phase 4: Verification & Polish

- [ ] T008 Update `test/widgets/sectograph_dial_test.dart` for 7-block horizon and two-stage needle.
- [ ] T009 Run `flutter test` across all tests and ensure 100% pass.
- [ ] T010 Run `dart analyze` and ensure 0 issues.
- [ ] T011 Run `dart format` on all modified files.
- [ ] T012 Deploy debug APK to Nothing Phone (`00160353N000148`), capture screencaps, and verify visual design.
