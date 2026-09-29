# Radian — Dial Engine Architecture & Phased Implementation Plan

Version 1.0 · 29 Sep 2026 · Owner: PrasaD (KSM X Tech) · Audience: implementation agent

---

## 0. How the agent must use this document

1. Work **one phase at a time**, in order. Do not start phase N+1 until every acceptance criterion of phase N passes.
2. Every phase ships behind the feature flag `DialEngineFlags.newEngine` (default OFF until Phase 5 sign-off). The old code path stays runnable until Phase 9.
3. Never change behaviour outside the phase scope. If you find another bug, add it to `docs/BUG_LEDGER.md` and move on.
4. Every phase ends with: `flutter analyze` clean, `flutter test` green, new tests for the phase, and a short `docs/phase-N-report.md` (what changed, files touched, what is still risky).
5. Sections 1 and 2 are **specification**. If code contradicts section 1, the code is wrong.

---

## 1. Product rules locked by the owner (invariants)

These come directly from the owner's design intent. They are the acceptance contract for the whole engine.

| # | Invariant |
|---|-----------|
| **I1** | The number of **main blocks** a user can add is capped. One `BlockBudget` object owns every limit. No other file may hard-code a block limit. |
| **I2** | The dial shows only a **horizon**: the active block + `P` previous blocks (P = 0..3) + `N` next blocks (N = 0..3). `P = 0` means **zero** previous blocks, with no exception. Total visible ≤ 1 + P + N ≤ 7. |
| **I3** | Showing few blocks is deliberate: it gives subtasks room, and it prevents 12 PM→12 AM and 12 AM→12 PM blocks from landing on the same angles. **A block that would collide is not selected. It is never drawn on top of another and never silently dropped at paint time.** |
| **I4** | **Subtasks live inside a main block** as capsules, each with an optional time inside that block. Capsules are positioned by that time. |
| **I5** | The **active block** (needle inside it) and the **next block** always show their subtasks. Other visible blocks show subtasks best-effort only. |
| **I6** | The dial **stretches** angular space towards the active and next blocks so their subtasks are readable. Outer-edge time labels compress elsewhere. The stretch is guaranteed, not incidental. |
| **I7** | The needle is inside the active block's drawn arc **if and only if** now ∈ [start, end). |
| **I8** | **One input → one DialModel → identical result on every surface** (app dial, home widget, future Wear tile, notification). Proven by a parity hash in tests and in a debug overlay. |
| **I9** | Time is **wall-clock** on a clock face. Routines follow the user across time zones by default. Fixed-instant events (meetings) never move in absolute time. Must work for IST (+5:30), Nepal (+5:45), and DST zones. |
| **I10** | The user is never left guessing: if blocks are hidden by I2/I3, a small "+N" indicator says so. |
| **I11** | Guilt-free philosophy stays: no red overdue states, no nagging notifications. |

---

## 2. Diagnosis: why the circle "sometimes shows completely different blocks"

Verified by reading the repo (commit `11695c2`). Each root cause is mapped to the phase that removes it.

| RC | Root cause | Where | Fixed in |
|----|-----------|-------|----------|
| RC1 | **Two dial pipelines.** The in-app dial projects recurring events, de-dupes, and applies a rolling 12h window **inside a widget `build()`**. The widget uses `DialImageRenderer` with a different provider, a fixed AM/PM half, and `ConcentricSolver`. Same settings, different subsets. | `sectograph_dial.dart` (~L118–430) vs `dial_image_renderer.dart` | P3, P5, P6 |
| RC2 | **Silent dropping.** In-app 12h "deconflict" keeps the first overlapping event and discards the rest at display time. The timeline list still shows the dropped one, so list and dial disagree. | `sectograph_dial.dart` (deconflicted loop) | P2, P3 |
| RC3 | **Limits contradict each other.** `maxBlocks12H = 12`, `maxBlocks24H = 18`, `maxDialVisibleBlocks = 10`, `previousBlocksCount 0..3`, `futureBlocksCount 0..3`. The painter forces `max(1, previousBlocksCount)` for subtasks and `min(1, futureBlocksCount)`, so P = 0 still shows a previous block. | `app_layout_constants.dart`, `sectograph_painter.dart` L520/532, `dial_settings.dart` | P2, P3 |
| RC4 | **Two-stage warp with hidden coupling.** `FisheyeTimeLens` then `DialSectorLayoutStretcher` (which also reads `currentTime`). The native widget receives only `focusAngle` + `magnification`, not the stretcher's result, so the needle cannot be exact. | `dial_image_renderer.dart`, `android_widget_service.dart` | P3, P6 |
| RC5 | **Stale widget image.** Sync fires only from `ref.listen` inside `HomeScreen.build`, so only while the app screen is alive. The theme is not a trigger. | `home_screen.dart` L251–260 | P6 |
| RC6 | **Sync inputs differ by entry point.** Auto-sync uses today's projected events. The "Sync widget" button uses `allEventsProvider ?? []`. | `dial_system_integrations_section.dart` | P6 |
| RC7 | **No time-zone model at all.** Events are stored with `toIso8601String()` on a local `DateTime`, which produces **no offset**. Cloud sync and MCP use the same strings. Travel, DST, and cross-device sync all become ambiguous. | `sector_event.dart` L247, `cloud_sync_service.dart` L203, `mcp_tools.dart` | P1 |
| RC8 | **Content collision uses a 12° midpoint heuristic**, not real geometry. Titles, pebbles and time caps overlap once the lens stretches a block. | `sectograph_painter.dart` (~L576) | P4 |
| RC9 | **Build blocker:** `SectographWidgetProvider.kt` contains only `PLACEHOLDER`. | `android/.../SectographWidgetProvider.kt` | P0 |
| RC10 | The widget `syncWidget` re-renders a 1080² PNG every minute and copies it to three files. It wastes battery and is exposed to torn reads. | `WidgetSyncHelper.kt` | P6 |

---

## 3. Target architecture

### 3.1 Layers (dependencies point downward only)

```
┌───────────────────────────────────────────────────────────────┐
│ PRESENTATION   DialView · Timeline · Editor · Settings · Widget│
│                (dumb: draws a DialModel, forwards gestures)    │
├───────────────────────────────────────────────────────────────┤
│ APPLICATION    dialModelProvider · widgetFramePlanner          │
│                editValidator · clock/tick providers            │
├───────────────────────────────────────────────────────────────┤
│ DIAL ENGINE    (pure Dart, no Flutter imports, deterministic)  │
│   DayProjector → HorizonSelector → WarpSolver →                │
│   RingAssigner → ContentPlanner(SubtaskPlacer) → DialModel     │
├───────────────────────────────────────────────────────────────┤
│ DOMAIN         Event · Subtask · Routine · TimeSpec · ZoneClock│
│                BlockBudget · DialPrefs                         │
├───────────────────────────────────────────────────────────────┤
│ DATA           LocalRepo · CloudSync · MCP · Android bridges   │
└───────────────────────────────────────────────────────────────┘
```

**Golden rule:** `CustomPainter.paint()` contains **no layout decisions**. It only draws what `DialModel` says.

### 3.2 Pipeline

```
Events (stored) ─▶ DayProjector ─▶ Occurrences (absolute + wall-clock)
                                        │
   DialInput{ clock, occurrences, prefs, window, focus, surface }
                                        ▼
                             HorizonSelector   (I2, I3, I5)
                                        ▼
                               WarpSolver      (I6, I7)
                                        ▼
                     RingAssigner + ContentPlanner + SubtaskPlacer
                                        ▼
                                   DialModel ──▶ DialPainter (app)
                                        │  └───▶ DialPainter (widget frames)
                                        └──────▶ Semantics (TalkBack)
```

### 3.3 Core contracts

```dart
/// Everything the engine needs. No providers, no BuildContext, no DateTime.now().
class DialInput {
  final ZoneClockSnapshot clock;      // now (instant) + zone id + wall-clock now
  final List<Occurrence> occurrences; // already projected for the horizon
  final DialPrefs prefs;              // 12/24h, P, N, lens, style
  final DialWindow window;            // rolling | segment(am|pm) | fullDay24
  final DialFocus focus;              // none | selected(id) | scrub(angle)
  final DialSurface surface;          // app | widget | wear  (size + text scale)
}

class DialModel {
  final int schemaVersion;
  final String signature;             // stable hash of everything below (parity)
  final List<DialBlock> blocks;       // visible blocks only
  final HiddenSummary hidden;         // count + ids hidden by I2/I3
  final WarpMap warp;                 // forward(naturalDeg) / inverse(displayDeg)
  final NeedleModel needle;           // displayDeg via warp.forward(now)
  final List<TickModel> ticks;        // hour labels placed via warp, thinned
  final CenterModel center;
}

class DialBlock {
  final String eventId; final int segmentIndex;   // midnight-crossing => 2 segments
  final BlockTier tier;               // A: active,next1  B: prev1,next2  C: rest
  final BlockRole role;               // active | next | prev
  final double startDeg, sweepDeg;    // display angles (already warped)
  final RingLevel ring;               // outer | inner
  final ContentMode content;          // full | compact | iconKeyword | iconOnly
  final List<CapsulePlacement> capsules;
  final CapLabels caps;               // start/end time label placement
}
```

Both `WarpMap` and `DialModel` are immutable, `==`/`hashCode` by value, and JSON-serialisable (needed for widget frames and golden tests).

---

## 4. Core algorithms

### 4.1 Block budget (I1, RC3)

One class replaces every limit:

```dart
class BlockBudget {
  static const maxPerWindow12H = 12;   // keep owner's existing values
  static const maxPerWindow24H = 18;
  static int maxVisible(DialPrefs p) => 1 + p.previousBlocks + p.nextBlocks; // ≤ 7
  static BudgetResult check(List<Event> existing, Event candidate, DialWindow w);
}
```

- Cap is counted **per dial window** (an AM half, a PM half, or the 24h day). A block crossing the boundary counts once, in the window where it starts.
- `maxDialVisibleBlocks = 10` is **deleted**. Visibility is a function of P and N only.
- Enforced in exactly three write paths: Editor, MCP tools, Cloud-sync import. All call `EditValidator` (see 4.2).

### 4.2 Write-time overlap policy (I3, RC2)

The dial cannot show overlapping main blocks. So overlaps must not exist in stored data.

`EditValidator.validate(event, existing, budget)` returns `ok` or `conflict(kind, suggestions[])`, where kind ∈ {`overlap`, `budgetFull`, `outsideBlockSubtask`}.

Editor UX on overlap: three one-tap resolutions: *Shorten the earlier block*, *Move to next free slot*, *Cancel*. MCP returns the same conflict as a structured error with suggestions so the AI assistant can self-correct instead of silently creating a hidden block.

Remove the title+time de-duplication hack from the dial. Enforce uniqueness at write time and run a one-off dedupe in the data migration (P2).

### 4.3 Horizon selection (I2, I3, I5)

Window is **rolling** for live display: candidates are events whose interval intersects `[now − 12h, now + 12h)`. This is what lets an 11 PM user still see tomorrow's 6 AM block. Edit mode uses `segment(am|pm)`. 24h mode uses `fullDay24`.

Steps:

1. `focus` = selected block, else active block, else the next upcoming block (needle in a gap).
2. Build ordered candidate list:
   `selected, active, next1, prev1, next2, prev2, next3, prev3`
   (next before prev for the same rank. The owner wants the user "alert to the upcoming task". Confirm in section 10.)
3. Respect counts: skip `prevK` if `K > P`; skip `nextK` if `K > N`.
4. **Angular occupancy test** (12h only; 24h windows cannot alias): keep an interval set on the circle. Admit a candidate only if its natural-angle interval (with a small guard gap) does not intersect an admitted interval. Otherwise put it in `hidden` with reason `aliasesWith:<id>`.
5. A midnight-crossing block is one logical event and is split into segments for drawing (`id#0`, `id#1`).
6. Output: `visible: List<Occurrence>` in priority order + `HiddenSummary`.

Invariants tested by property tests: `visible.length ≤ 1+P+N`; P = 0 ⇒ no prev; no two visible intervals intersect; result is independent of input list order.

### 4.4 Warp solver (I6, I7, RC4)

Replace `FisheyeTimeLens` + `DialSectorLayoutStretcher` + `FocusedWarp` with **one** solver that produces a piecewise-linear, monotonic map.

Inputs: the circle partitioned into segments (visible blocks and the gaps between them; hidden blocks' time collapses into gaps).

For each segment *i*:

- `natural_i`: sweep from linear time (0.5°/min in 12h, 0.25°/min in 24h).
- `min_i`: smallest sweep that still fits the required content. For a block: start/end caps + icon + title keyword + duration, plus `k` capsules if tier A. For a gap: a small floor (0° for contiguous blocks).
- `want_i`: Tier A blocks get `contentIdeal(block)` (grows with subtask count, capped, never less than natural). Everything else wants `natural_i`.

Solve: minimise Σ (s_i − want_i)² / natural_i subject to Σ s_i = 360° and s_i ≥ min_i. Use water-filling: start from proportional scaling, clamp segments below their minimum, redistribute the remainder among unclamped segments, repeat until stable (≤ 10 iterations).

**Degrade ladder** if Σ min_i > 360°: (1) lower Tier C content mode → (2) lower Tier B → (3) reduce Tier A ideal to its minimum → (4) demote a Tier C block to `hidden` (never Tier A). Always reported in `DialModel.hidden`.

Output `WarpMap` = sorted breakpoints `(naturalDeg → displayDeg)`, exposing `forward()` and `inverse()`.

Rules:

- **Anchor:** natural 12 o'clock maps to display 12 o'clock. Only relative spacing moves.
- **Needle** = `warp.forward(nowNaturalDeg)`. It is inside the active block's arc by construction (I7).
- **Touch scrub / drag handles** use `warp.inverse()`. This fixes drag imprecision while stretched.
- **Stability:** the warp is recomputed only when its **WarpKey** changes (visible set, content keys, prefs, focus). A minute tick moves only the needle. When the key changes in-app, animate breakpoints over ~250 ms.
- **Ticks:** hour labels are placed with `warp.forward`. If two adjacent labels are closer than the text height, thin them (keep 12/3/6/9 always, drop the rest). Optional uniform reference ring (see 9).

### 4.5 Subtask placer (I4, I5, RC8)

Input: one block (display arc + ring thickness), its subtasks, measured text sizes (cached `TextPainter`).

1. Each subtask has `at` (optional time inside the block). Clamp to `[block.start, block.end]`. No time → spread evenly.
2. Desired angle = `warp.forward(at)` (already inside the block arc).
3. Measure capsule width along the arc from text + padding.
4. **Reserved zones** (oriented rectangles in cartesian space): start cap, end cap, title/icon box. Capsules may not intersect them.
5. Greedy lane packing: sort by desired angle; put each capsule in the first radial lane (2–3 lanes inside the ring thickness) where it does not intersect an existing capsule or reserved zone; if none fits, shrink text one step (2 steps max); if still none, fold into a `+N` capsule.
6. Tier A guarantees: the warp gave enough sweep for `k` capsules, so a `+N` capsule on Tier A is a bug worth a failing test.
7. Output `CapsulePlacement{subtaskId, center, angle, size, lane, folded}`.

`ContentMode` ladder per block (chosen from the final sweep, not before): `full` (title + duration + icon + caps + capsules) → `compact` (icon + keyword + duration) → `iconKeyword` → `iconOnly`.

### 4.6 Ring assignment

Keep the existing outer/inner ring idea, but as a pure step: Tier A → outer ring. Others go to the outer ring if there is no angular conflict with a block already on it, else inner. Widget and app both call this same step (kills the `ConcentricSolver` divergence).

---

## 5. Time & timezone design (I9, RC7)

### 5.1 Data model

```dart
sealed class TimeSpec {}
class InstantTime  extends TimeSpec { int utcMillis; String tzid; }      // meetings, one-offs
class FloatingTime extends TimeSpec {                                     // routines
  LocalDate date; int startMinuteOfDay; int durationMinutes;
  ZoneMode zoneMode;   // device (default) | fixed(tzid)
}
```

Recurrence stays wall-clock: weekday set + interval + until date (RRULE-lite). `DayProjector(localDay, zone)` turns any event into `Occurrence{startLocal, endLocal, startInstant, endInstant}`.

### 5.2 Rules

- **Angle is computed from wall-clock minutes-of-day** in the display zone. Duration for sweep uses wall-clock difference. On DST days the face is still a normal clock; the elapsed-time label uses real elapsed time.
- **Half-hour and 45-minute zones** are first-class (IST +5:30, Nepal +5:45, Lord Howe 30-min DST). No `hour * 60` assumptions anywhere. Add these to the test matrix.
- **DST gap** (spring forward): a nonexistent local time shifts to the first valid instant. **DST overlap** (fall back): first occurrence wins.
- **Zone change while running:** listen for Android `ACTION_TIMEZONE_CHANGED`, `ACTION_TIME_SET`, `ACTION_DATE_CHANGED`, `ACTION_LOCALE_CHANGED`, and re-check on app resume. Any change invalidates the projection, the WarpKey, and widget frames.
- **Settings:** `dialZoneMode`: `device` (default) or `home(IANA)`. `travelBehavior`: routines follow device zone (default) or stay in home zone. Optional secondary zone marker (section 9).

### 5.3 Storage, sync, MCP

- Persist instants as **epoch millis + tzid** (or ISO-8601 **with offset**). Never offset-less strings.
- **Migration** (P1): existing offset-less strings are interpreted in the device zone at migration time and marked `assumedZone = true`. Keep a backup table for one release.
- Cloud sync: send UTC instants + tzid; server uses last-writer-wins on `updated_at` (UTC epoch) with tombstones for deletes; `since` cursor is UTC.
- MCP tools: accept ISO with offset. Offset-less input is assumed to be in the user's dial zone and the response includes `assumedZone`. `get_state` returns `currentTime` with offset and `tzid`.

### 5.4 Locale

- Default 12/24h from the platform setting; user override wins.
- `intl` formatting with the active locale everywhere (this also fixes the "Sept"/"Sep" mismatch). One `DateLabels` helper, used by app and widget.
- Bundle Noto fallbacks for Devanagari, Bengali, Odia, Tamil, Telugu, Arabic and CJK so canvas text (titles, capsules) renders in widget frames too. Set `locale` on every `TextPainter`.
- Numerals: option for native digits (Devanagari/Bengali/Odia/Arabic-Indic) in labels.
- RTL: the dial stays clockwise. Only surrounding UI mirrors.

---

## 6. Widget architecture: the "Frame Strip" (RC5, RC6, RC10)

Problem: a Flutter-rendered image goes stale, and the native needle is guessed from lens parameters.

Solution: **precompute the day** with the same engine, so native code only *selects* a frame and draws a needle.

### 6.1 Dart side: `WidgetFramePlanner` (pure + renderer)

1. Compute boundary instants for today and the first hours of tomorrow: every block start/end, midnight, the 12:00 flip in 12h mode, DST transitions, and subtask start/end **only if** the center shows "current subtask".
2. For each interval `[B_k, B_{k+1})` build a `DialModel` at `B_k` using `surface = widget`.
3. De-duplicate frames whose `signature` is identical.
4. Render each with the **same** `DialPainter` (`needle: false`, `centerClock: false`) at **720×720** (RemoteViews bitmap memory limit; 1080² is too large and wasteful) into `filesDir/widget_frames/<dataVersion>/k.png`.
5. Write `frames.json`:

```json
{
  "dataVersion": "…", "tzid": "Asia/Kolkata", "validUntilMs": 0,
  "themeVariants": ["light", "dark"],
  "frames": [{ "fromMs": 0, "toMs": 0, "file": "3.png",
               "warp": [[0.0, 0.0], [30.0, 12.4]],
               "center": {"mode": "digital"} }]
}
```

6. Render both light and dark variants when the widget follows the system theme. It doubles storage, but frames are small (≈ 50–120 KB) so the day totals a few MB.
7. Write via a temp directory + atomic rename of the whole `<dataVersion>` folder, then update a single `current` pointer file. No torn reads.

### 6.2 Native side (Kotlin)

- `WidgetFrameStore`: reads `frames.json`, picks the frame for `now` in the frame's `tzid`, verifies `dataVersion`.
- **Needle:** angle = piecewise-linear interpolation over the frame's `warp` table (about 20 lines of Kotlin). This is the same math as `WarpMap.forward`. Cover with a shared JSON test vector run by both Dart and Kotlin tests.
- **Center clock/date:** drawn natively from `DateLabels` strings supplied per locale.
- **Scheduling:** at the next of {next minute, next frame boundary}: `AlarmManager.setExactAndAllowWhileIdle` when `canScheduleExactAlarms()`, otherwise `setAndAllowWhileIdle` plus a WorkManager fallback. Re-arm on `BOOT_COMPLETED`, `TIMEZONE_CHANGED`, `TIME_SET`, `DATE_CHANGED`, `LOCALE_CHANGED`, and `uiMode` change.
- **Freshness contract:** if `now > validUntilMs` or `dataVersion` mismatches, show the last frame with a small "tap to refresh" dot. The widget must never confidently show wrong blocks without a hint.
- **Refresh while the app is closed:** a daily WorkManager job (~00:05 local) and an expedited job on zone/theme change run a headless Flutter engine entrypoint (`widgetRefreshMain`) that reads the repo, builds frames and writes them. If the engine cannot start, native falls back to the freshness dot.
- Restore `SectographWidgetProvider.kt` in P0 (currently `PLACEHOLDER`).

### 6.3 Single sync trigger

Delete the `ref.listen` calls inside `HomeScreen.build`. Replace with **one** `WidgetSyncCoordinator` (Riverpod `Notifier`, lives with the app scope) that listens to: events, prefs, theme, zone change. Debounce 800 ms. The manual "Sync widget" button calls the same coordinator, so it uses identical inputs (RC6).

---

## 7. Phased implementation plan

Effort: S ≤ 1 day · M 2–3 days · L ≥ 4 days (agent-days, rough).

### Phase 0 — Stabilise and build the safety net (S–M)

**Goal:** the project builds, and current behaviour is captured before anything changes.

Tasks
- Restore the real `SectographWidgetProvider.kt` (from the owner's machine). Confirm the Android release build compiles. If the file is unavailable, stop and ask the owner.
- Create `docs/BUG_LEDGER.md` seeded from section 2.
- Add a **Dial Lab** debug screen (debug builds only): pick fake `now`, zone, P/N, 12/24h, and a fixture day. Show app dial, widget-frame render and the model signature side by side.
- Add golden-test harness `test/golden/dial/` with 8 characterization goldens of the **current** app dial (so regressions in later phases are visible and intentional).
- Add `Clock` abstraction (`Clock.now()`); replace direct `DateTime.now()` in dial, widget and repo code paths with the injected clock.

Acceptance: release build green; Dial Lab opens; 8 goldens committed; no `DateTime.now()` remains in `lib/core/geometry` or `lib/domain`.

### Phase 1 — Time foundation (M–L)

**Goal:** correct and portable time (RC7, I9).

Tasks
- Add `timezone` + `flutter_timezone`. Implement `ZoneClock`, `ZoneClockSnapshot`, `TimeSpec`, `DayProjector` (pure Dart).
- Data migration: offset-less ISO strings → `InstantTime`/`FloatingTime` with `assumedZone` flag; keep backup table.
- Update `SectorEvent` JSON, `LocalEventRepository`, `CloudSyncService`, MCP parsing per 5.3. Add schema version.
- Android receivers for zone/time/date/locale changes → Flutter stream `systemTimeChanges`.
- Settings: `dialZoneMode`, `travelBehavior` (UI can be minimal in this phase).

Tests
- `DayProjector` matrix: `Asia/Kolkata`, `Asia/Kathmandu`, `America/New_York` (spring-forward & fall-back days), `Europe/London`, `Australia/Lord_Howe`, `Pacific/Auckland`, `UTC`.
- Round-trip: store in IST → read in New York → floating routines stay at the same wall-clock, instant events stay at the same instant.
- Migration test with 200 legacy events, including one crossing midnight.

Acceptance: all matrix tests green; changing device zone in emulator updates the projected day without app restart.

### Phase 2 — Domain rules: budget, validator, unique data (M)

**Goal:** make invalid states unrepresentable (I1, I3, RC2, RC3).

Tasks
- Implement `BlockBudget` and delete `maxDialVisibleBlocks` and scattered limit uses.
- Implement `EditValidator` (`overlap`, `budgetFull`, `subtaskOutsideBlock`) with suggestions.
- Wire into: `event_edit_modal.dart`, `subtask_edit_sheet.dart`, `mcp_tools.dart`, cloud-sync import (quarantine invalid remote events into a "needs attention" list instead of dropping).
- Editor UX for the 3 overlap resolutions (4.2).
- One-off data cleanup: dedupe by (title, start, end) and report overlaps to the user once.
- Subtask time is constrained to its parent block; moving/resizing a block moves/clamps its subtasks.

Tests: validator unit tests (≥ 30 cases), MCP conflict responses, editor widget tests.

Acceptance: the stored data set can no longer contain overlapping main blocks or an over-budget window; removing the display-time deconflict in the old path changes nothing visible for valid data.

### Phase 3 — Engine core: horizon + warp (L)

**Goal:** pure `DialModelBuilder` up to blocks and warp; no painting yet (I2, I3, I6, I7, RC1, RC3, RC4).

Tasks
- Create `lib/engine/` (no Flutter imports): `dial_input.dart`, `horizon_selector.dart`, `angular_occupancy.dart`, `warp_solver.dart`, `warp_map.dart`, `ring_assigner.dart`, `dial_model.dart`, `dial_model_builder.dart`.
- Port rules from `focused_block_layout_resolver.dart` into `HorizonSelector` with the new priority order and true `P = 0` behaviour. Keep the old class until P9, delegating nothing to it.
- Implement `WarpSolver` per 4.4, including the degrade ladder and `HiddenSummary`.
- Implement `signature` (stable, order-independent hash).

Tests (property-based, ≥ 1,000 random days per property, seeded)
- `visible ≤ 1+P+N`; P = 0 ⇒ no previous; no overlapping visible arcs; independent of input order.
- Warp: monotonic, Σ sweeps = 360°, anchor holds, `inverse(forward(x)) ≈ x`, Tier A sweep ≥ its `min`.
- Needle inside active arc iff now ∈ [start,end).
- 12h aliasing: 11 PM with tomorrow-6 AM next block and yesterday-6 PM previous block never collide.

Acceptance: 100 % of property tests green; a CLI (`dart run tool/dial_model.dart fixture.json`) prints a model JSON.

### Phase 4 — Content planner + subtask placer (L)

**Goal:** no overlaps inside a block (I4, I5, RC8).

Tasks
- Text measurement service with a `TextPainter` cache keyed by (text, font, size, locale).
- Implement `ContentPlanner` (content-mode ladder) and `SubtaskPlacer` (4.5) with reserved zones.
- Feed `min_i` estimates back into the warp solver (this is the loop that makes Tier A "stretch for its subtasks").
- Remove the 12° midpoint heuristic from the painter path.

Tests: fixtures with 0, 1, 3, 6, 10 subtasks; long Odia/Hindi/Arabic/CJK titles; two subtasks at identical times; subtask at exactly block start/end. Assertions: capsule rectangles never intersect each other or reserved zones; Tier A never folds to `+N` for ≤ 6 subtasks.

Acceptance: goldens for the 12 fixtures approved by the owner in Dial Lab.

### Phase 5 — Painter refactor and interaction (L)

**Goal:** the app dial draws `DialModel`; nothing else (I8).

Tasks
- New `DialPainter(model, theme)`. No geometry decisions inside. `shouldRepaint` compares `model.signature` and theme.
- Replace the 1,364-line `sectograph_dial.dart` build-time logic with `dialModelProvider` + a thin widget. Split gesture handling into `DialGestureController` using `warp.inverse()`.
- Cap-drag handler (`dial_time_cap_drag_handler.dart`) and scrub use the new map.
- Animate warp breakpoints and needle. Respect "reduce motion".
- Semantics tree generated from `DialModel` ("Now: Sleep, until 6:00 AM. Next: Yoga and Sadhana, 6:00 to 7:15").
- Flip `newEngine` default to ON at the end of the phase after owner sign-off in Dial Lab.

Acceptance: goldens match the approved P4 set; timeline list and dial show consistent blocks for the same day (test comparing `visible ∪ hidden` to the list); dial frame time p95 < 8 ms on a mid-range device profile run.

### Phase 6 — Widget Frame Strip (L)

**Goal:** widget always equals the app (I8; RC5, RC6, RC10).

Tasks: implement section 6 in full: `WidgetFramePlanner`, atomic frame store, Kotlin `WidgetFrameStore`, needle interpolation, alarms + WorkManager, headless refresh entrypoint, `WidgetSyncCoordinator`, freshness dot.
- Shared JSON test vectors for the warp interpolation (Dart ↔ Kotlin).
- Remove the per-minute Flutter re-render and the triple file copy.
- Fix `Sept`/`Sep` and theme-change refresh.

Tests: planner boundary tests (incl. midnight, 12h flip, DST day); instrumentation test on an emulator that advances the clock and asserts the frame changes exactly at the boundary; parity test `appModel.signature == widgetFrame.signature` for the same instant.

Acceptance: the two original screenshots' scenario (rename a block, change its icon, change theme, wait for the next block) leaves the widget matching the app within one minute, with the app closed.

### Phase 7 — Internationalisation and accessibility (M)

Tasks: section 5.4 in full (DateLabels, digits, Noto fallbacks, RTL); TalkBack labels and focus order; text scale up to 200 % (content ladder degrades instead of overflowing); minimum contrast check for text on block colours (auto black/white by luminance, warn in the colour picker); colour-blind-safe pattern option for block fills.

Acceptance: goldens for `hi`, `bn`, `or`, `ta`, `ar`, `ja`; automated contrast test on all built-in themes.

### Phase 8 — Smart features (choose per section 9) (M each)

Implement only those the owner selects. Each goes through the same validator, engine and parity tests.

### Phase 9 — Hardening and release (M)

Tasks: delete the old pipeline (`FocusedBlockLayoutResolver` old copy, `DialSectorLayoutStretcher`, `FisheyeTimeLens` if unused, `ConcentricSolver` if unused, in-widget projection code); rename remaining `sectograph_*` identifiers where safe (keep the Android application id); performance profile; migration rehearsal on a copy of real data; battery test (24 h widget on, app closed); release notes.

Acceptance: `flutter analyze` clean; no dead engine code; battery drain from Radian < 1 %/24h in the background test; all parity and property suites green in CI.

---

## 8. Test strategy (applies to every phase)

- **Scenario matrix** for goldens: {12h, 24h} × {P,N ∈ (0,0), (1,1), (1,3), (3,3)} × zones {Asia/Kolkata, Asia/Kathmandu, America/New_York on DST day, Pacific/Auckland, UTC} × states {active with subtasks, needle in a gap, midnight-crossing block, max-budget day, empty day}.
- **Property tests** for engine invariants (Phase 3).
- **Parity test:** for 200 random inputs, `signature(app)` == `signature(widget frame)`.
- **Debug overlay:** small corner text in debug builds showing `model.signature[0:8]`, zone, P/N. Screenshots of app and widget can then be compared at a glance.
- **Time travel:** every test injects `Clock`; no test sleeps.

---

## 9. Smart feature ideas (owner picks)

1. **Hidden-blocks indicator (I10).** A small "+2" notch on the bezel at the hidden blocks' angle. Tap = peek sheet. Cheap and prevents "where did my block go?".
2. **True-time reference ring.** A thin uniform outer tick ring beside the stretched labels, so users learn that the stretch is intentional and can still read real time.
3. **Second time zone marker** for international users: a tiny bezel marker or a second needle for family or a client abroad (New York, London). Strong for India/Asia diaspora users.
4. **Travel prompt:** when the device zone changes, one gentle sheet: "Keep routines at home time or shift with you?" with per-block override later.
5. **Sunrise/sunset arc** on the bezel, computed offline from coarse location or a manual city (no API). Fits the circadian idea and yoga/sadhana routines.
6. **Subtask pace ring:** a soft arc inside the active block showing subtasks done vs time elapsed. Neutral colours only (I11), no red.
7. **Auto-fit suggestions:** when a block is crowded (more than 6 subtasks or tiny sweep), suggest splitting into two blocks or moving the subtask into the timeline list.
8. **Dial contexts (Work / Study / Life):** filter by tag so a user can keep fewer blocks per view and still stay under the cap.
9. **Widget family:** small (dial only), medium (dial + next block text), plus Wear OS tile and lock-screen surface, all from the same `DialModel` (`surface` parameter).
10. **MCP planning "dry run":** the AI assistant proposes a day, the validator reports conflicts and budget use, and the user approves once. It stays inside I1–I3 automatically.
11. **Export/import JSON** with schema version, for backup and device switching.
12. **Dial Lab as a user-facing "Preview settings" screen:** shows how P/N and lens settings look on the user's own day before applying.

---

## 10. Open decisions (defaults chosen so the agent is not blocked)

| Decision | Default the agent uses | Owner may change |
|----------|-----------------------|------------------|
| Priority when the horizon is crowded | `active, next1, prev1, next2, prev2, next3, prev3` | swap prev1 ahead of next1 |
| Subtasks on previous blocks | best-effort (Tier B/C), never guaranteed | always off / always on |
| Block cap semantics | per dial window (AM half, PM half, 24h day) | per whole day |
| Live 12h window | rolling `[now−12h, now+12h)` | fixed AM/PM halves |
| Widget theme variants | light + dark frames | system theme only, one set |
| Time-zone mode default | routines follow device zone | fixed home zone |

---

## 11. Definition of Done (whole project)

- I1–I11 each have at least one automated test that fails if the invariant breaks.
- The same day, settings and instant produce the same `DialModel.signature` in the app and in the widget.
- Changing the device time zone, theme, or a block's name/icon updates both surfaces without opening the app (widget within one minute).
- A user in IST, Nepal, New York (across a DST change) and Auckland sees correct blocks and a correct needle.
- No overlapping main blocks exist in storage. No block is silently missing from the dial: it is either visible or counted in the hidden indicator.
