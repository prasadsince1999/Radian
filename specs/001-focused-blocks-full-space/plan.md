# Implementation Plan: Smart 7-Block Focus Horizon & Dim Mode Removal

**Branch**: `001-focused-blocks-full-space` | **Date**: 2026-09-11 | **Spec**: [specs/001-focused-blocks-full-space/spec.md](file:///c:/Projects/KSM%20x%20Tech%20-%20Projects/sectograph_mcp/specs/001-focused-blocks-full-space/spec.md)

## Summary

Implement the user's smart architecture:
1. **Remove Dim Mode (`birdsEye`)**:
   - Clean out `PastHoursStyle.birdsEye` from `dial_settings.dart`, UI settings modal, and painter.
   - Set default `pastHoursStyle` to `focusedBlock`.
2. **Implement Smart 7-Block Focus Horizon in `FocusedBlockLayoutResolver`**:
   - Resolve:
     - `Active Event` (Current time event or selected event).
     - `prevEvents`: 3 immediately preceding completed blocks (`[Prev 1, Prev 2, Prev 3]`).
     - `nextEvents`: 3 immediately succeeding upcoming blocks (`[Next 1, Next 2, Next 3]`).
   - Radial Ring Allocation:
     - `outerEventIds = {Prev 1, Active, Next 1, Selected}` $\to$ Outer Ring (`outerROut` to `outerRIn`).
     - `innerEventIds = {Prev 3, Prev 2, Next 2, Next 3}` $\to$ Inner Ring (`innerROut` to `innerRIn`).
   - Filter `computedEvents` so only these 7 blocks are rendered on the dial canvas! Any older past blocks or distant future blocks are excluded from the dial.
3. **Two-Stage Hierarchical Red Hour Indicator Needle**:
   - Inner segment (Hub to `outerRIn`): 1.5dp refined hairline at 50% opacity.
   - Outer segment (`outerRIn` to outer rim): 3.2dp bold crimson needle with ambient glow + signature sun/moon node.
   - Eliminates harsh visual slicing through inner text/icons while emphasizing current progress in the active outer block.
4. **Hit Testing & Settings Integration**:
   - Update `SectographDial` touch hit-testing to map outer/inner ring radii for the 7 blocks.
   - Update `DialSettingsModal` to show clean binary choices: `Focused Blocks` (Default) and `Disappear`.

---

## Technical Context

**Language/Version**: Dart 3.7+ / Flutter 3.29+  
**Primary Dependencies**: flutter, flutter_riverpod, intl  
**Target Platform**: Android (primary physical Nothing Phone 00160353N000148, Android 16), iOS, Web  
**Testing**: `flutter test`, `dart analyze`  

---

## Constitution Check

- **I. Mathematical Correctness**: 7-block horizon resolved via pure geometry in `lib/core/geometry/`. ✅ PASS
- **II. Dynamic Space Utilization**: Ancient blocks eliminated, preventing text overlap and dial crowding. ✅ PASS
- **III. Dynamic Rolling Horizon**: Continuous 7-block window around current time. ✅ PASS
- **IV. Test-Driven Verification**: Unit tests for resolver + widget tests for dial. ✅ PASS
- **V. Physical Device Verification**: Live verification on Nothing Phone via ADB. ✅ PASS

---

## Project Structure & Architecture

```text
lib/
├── core/
│   └── geometry/
│       └── focused_block_layout_resolver.dart     # [NEW] 7-block horizon resolver (3 prev, 1 active, 3 next)
├── domain/
│   └── models/
│       └── dial_settings.dart                     # [MODIFY] Remove birdsEye, default to focusedBlock
├── presentation/
│   └── widgets/
│       ├── dial/
│       │   ├── sectograph_dial.dart               # [MODIFY] Filter to 7-block horizon & update hit testing
│       │   └── sectograph_painter.dart            # [MODIFY] Two-stage red needle & 7-block ring radii
│       └── editor/
│           └── components/
│               └── dial_time_format_section.dart  # [MODIFY] Remove Bird's Eye tile, showcase Focused Blocks & Disappear
test/
├── core/
│   └── focused_block_layout_resolver_test.dart    # [NEW] Unit tests for 7-block horizon
└── widgets/
    └── sectograph_dial_test.dart                  # [MODIFY] Test 7-block rendering & 2-stage needle
```
