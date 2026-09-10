# Radian (Sectograph MCP) Constitution

## Core Principles

### I. Mathematical Correctness & Deterministic Geometry
The analog dial is the central cognitive canvas of Radian. All sector angles, sweeps, radiuses, and concentric ring layouts must be computed deterministically through pure geometry solvers (`lib/core/geometry/`). Never compute ad-hoc layout logic inside rendering passes or widgets.

### II. Dynamic Space Utilization (No Dead Zones)
Every degree and radial track of the dial represents valuable visual real estate. In Focused Block mode:
- Focus blocks (previous, active, upcoming) anchor situational awareness in the outer ring.
- Non-overlapping secondary schedule blocks must expand to occupy the full radial space (`innerRIn` to `outerROut`) so that block labels, icons, subtasks, and duration tags remain legible without unnecessary cramping.
- Empty radial voids must never be left unutilized where an existing event can expand into it.
- Sectors crossing outer focus boundaries must segment cleanly between full radial track and inner track to avoid collisions while maximizing space.

### III. Dynamic Rolling Horizon over Rigid Modes
The 12-hour dial displays a continuous, rolling horizon relative to the current or scrubbed reference time. Manual toggles such as AM/PM buttons are obsolete; time awareness is maintained through dynamic sector styles (`PastHoursStyle`), the current time needle, and center digital clock readouts.

### IV. Test-Driven Verification (NON-NEGOTIABLE)
All geometry calculations, level allocations, hit testing, and state transitions must have unit and widget tests. Every commit must pass 100% of the test suite (`flutter test`) and have zero analyzer warnings (`dart analyze`).

### V. Physical Device Verification
Desktop and test widget harnesses alone are insufficient for analog dial interactions. All changes affecting dial geometry, touch targets, or typography must be verified on live physical Android hardware via ADB screencaps before task completion.

## Governance

1. All feature changes must trace to a verified specification in `specs/`.
2. Divergences from this constitution must be documented with an architectural decision rationale.
3. Code formatting must strictly adhere to `dart format` and user global rules.

**Version**: 1.0.0 | **Ratified**: 2026-09-11 | **Status**: Active
