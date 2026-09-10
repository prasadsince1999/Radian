# Feature Specification: Smart 7-Block Focus Horizon (3 Prev + 1 Active + 3 Next) & Dim Mode Removal

**Feature Branch**: `001-focused-blocks-full-space`  
**Created**: 2026-09-11  
**Status**: In Review  
**Input**: User feedback: 
> "dim mode remove it fully plan like smartly no one check very old blocks so showing them taking space and text are getting overlapped or getting outside of blocks. inner ring show previous block 2 outer ring already showing 1 upcoming also show 2 now its like current block total previous block 3 total upcoming 3 and how we can present that red hour indicator line do we need to break that for two rings or how we design them"

---

## Architecture & Conceptual Model

### 1. Removal of Dim Mode (`birdsEye`)
- Dim mode (`PastHoursStyle.birdsEye`) kept ancient completed events visible at reduced opacity across the dial.
- This caused text overlapping, sector overcrowding, and 12-hour wrap collisions with distant upcoming events.
- **Decision**: Completely remove dim mode (`birdsEye`). The dial offers clean, purposeful modes:
  - `focusedBlock` (Smart 7-Block Horizon with Concentric Rings)
  - `disappear` (Dynamic real-time sweep consumption)

---

### 2. Smart 7-Block Focus Horizon (3 Prev + 1 Active + 3 Next)
Instead of rendering all scheduled events across 24 hours, the dial focuses on an immediate, high-value 7-block horizon relative to `effectiveTime`:

```text
       ┌─────────────────────────────────────────────────────────────┐
       │                   SMART 7-BLOCK HORIZON                     │
       └─────────────────────────────────────────────────────────────┘
                                      │
           ┌──────────────────────────┴──────────────────────────┐
           ▼                                                     ▼
    [ OUTER RING: Tier 1 ]                                [ INNER RING: Tier 2 ]
    (Immediate Situational Focus)                         (Contextual Lookahead/Lookback)
    - Prev 1 (Immediately preceding block)               - Prev 3 (3rd preceding block)
    - Active Block (Current event NOW / selected)         - Prev 2 (2nd preceding block)
    - Next 1 (Immediately succeeding block)               - Next 2 (2nd upcoming block)
                                                          - Next 3 (3rd upcoming block)
```

- **Older Events**: Any event completed before `Prev 3` is **not rendered on the dial**.
- **Farther Events**: Any event starting after `Next 3` is **not rendered on the dial** (they remain accessible in the timeline below).
- **Result**: Zero overlapping text, zero clutter, no 12-hour collisions, and every block gets generous radial height and readable labels.

---

### 3. Red Hour Indicator Line ("NOW" Sweep Needle) Design
**Design Proposal: Two-Stage Hierarchical Needle**
- **Inner Ring Segment** (Center Hub to `outerRIn`):
  - Refined, high-precision hairline (1.5dp stroke, subtle 50% opacity).
  - Glides across inner blocks (`Prev 2`, `Prev 3`, `Next 2`, `Next 3`) without slicing harshly through inner text, icons, or duration badges.
- **Concentric Junction Transition**:
  - Micro-junction step at `outerRIn` demarcating the boundary between contextual tier and active focus tier.
- **Outer Ring Segment** (across the Active Block from `outerRIn` to `outerROut`):
  - Bold, vibrant 3.2dp crimson needle with soft ambient glow.
  - Strongly grounds the current minute inside the active block.
- **Outer Rim Node**:
  - Signature 8dp solid crimson beacon with crisp white rim and dynamic Day/Night sun/moon glyph.

---

## User Scenarios & Acceptance Criteria

### User Story 1 - Smart 7-Block Dial Allocation (Priority: P1) 🎯 MVP

As a Radian user in Focused Blocks mode:
- The dial shows at most 7 blocks: [Prev 3, Prev 2, Prev 1, ACTIVE, Next 1, Next 2, Next 3].
- Outer ring houses: `[Prev 1, ACTIVE, Next 1]`.
- Inner ring houses: `[Prev 3, Prev 2, Next 2, Next 3]`.
- Ancient past events and distant future events do not appear on the dial canvas.

**Acceptance Scenarios**:
1. **Given** a schedule with 9+ daily events, **When** viewing in Focused Blocks mode, **Then** only the active event, 3 previous events, and 3 upcoming events are rendered on the dial.
2. **Given** `Prev 1` and `Next 1`, **Then** they render in the outer ring (`outerRIn` to `outerROut`).
3. **Given** `Prev 2`, `Prev 3`, `Next 2`, `Next 3`, **Then** they render in the inner ring (`innerRIn` to `innerROut`).
4. **Given** any event older than `Prev 3` or farther than `Next 3`, **Then** it is omitted from dial rendering.

---

### User Story 2 - Removal of Dim Mode (Priority: P2)

As a Radian user:
- The settings modal offers `Focused Blocks` (Smart 7-Block) and `Disappear` modes.
- `birdsEye` is deprecated and removed from the UI and defaults.
- Existing installations defaulting to `birdsEye` automatically migrate to `focusedBlock`.

**Acceptance Scenarios**:
1. **Given** the Dial Settings modal, **When** inspecting past hours options, **Then** "Bird's Eye" / dim mode is absent.
2. **Given** an app session, **When** default settings load, **Then** `pastHoursStyle` is `focusedBlock`.

---

### User Story 3 - Two-Stage Hierarchical Red Needle (Priority: P3)

As a Radian user:
- The red "NOW" indicator line presents a subtle, non-intrusive hairline across the inner ring and a bold, glowing crimson needle across the outer ring.
- The outer rim features the signature glowing red sun/moon node.

**Acceptance Scenarios**:
1. **Given** the dial is rendered, **When** the red needle crosses the inner ring, **Then** it renders as a refined hairline that preserves readability of underlying text.
2. **Given** the needle crosses the active block in the outer ring, **Then** it renders with bold crimson intensity and ambient glow.
