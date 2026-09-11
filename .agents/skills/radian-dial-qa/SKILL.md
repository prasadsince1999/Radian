---
name: radian-dial-qa
description: Autonomous testing, ARTEMIS visual verification, and geometry inspection pipeline for the Radian sectograph dial.
---

# Radian Dial QA Skill

Use this skill when auditing, testing, or verifying changes made to the circular dial, sector pill geometry, time badge caps, needle indicator, or touch gestures.

## Workflow

1. **Static Analysis & Fast Tests**:
   - Run `dart analyze lib/ test/` to verify zero static issues.
   - Run `flutter test test/widgets/sectograph_dial_test.dart` to verify dial rendering and polar touch hit testing.

2. **Hot Reload / Hot Restart Verification**:
   - Never rebuild full APKs or run `adb install` for routine Dart/Flutter UI updates.
   - Use the active Flutter daemon session with Hot Restart (`R\n`) or Hot Reload (`r\n`) via `manage_task` (takes ~1.2s).

3. **Live Device Capture (ARTEMIS / ADB)**:
   - Capture device screenshot via ADB:
     `adb exec-out screencap -p > screenshot.png`
   - Inspect visually using `view_file` to verify:
     - The dial circle maximizes available width with minimal wasted margins.
     - The continuous red hour needle hand terminates cleanly inside the celestial beacon.
     - The celestial beacon (sun/moon badge) is strictly contained within the outer circle outline (zero overflow).
     - Overlapping sector tiles cast drop shadows only onto successor blocks with zero inner shadow blur.
     - Time badge caps are compact and uniform in span.

4. **Regression Gate**:
   - Run full test suite: `flutter test`.
   - Ensure all 138+ tests pass before committing.
