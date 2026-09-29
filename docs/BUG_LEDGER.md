# Bug Ledger

Seeded from Dial Engine Architecture Plan §2 (commit `11695c2`).
Each root cause is mapped to the phase that removes it.

| RC | Root cause | Where | Phase | Status |
|----|-----------|-------|-------|--------|
| RC1 | **Two dial pipelines.** In-app dial and widget use different projection, de-dupe, and layout code. Same settings → different subsets. | `sectograph_dial.dart` vs `dial_image_renderer.dart` | P3, P5, P6 | **Core Built** (`lib/engine/dial_model_builder.dart` pure engine with single unified model; ready for painter/widget wiring in P5/P6) |
| RC2 | **Silent dropping.** 12h deconflict keeps first overlapping event, discards rest. Timeline list still shows dropped ones. | `sectograph_dial.dart` (deconflicted loop) | P2, P3 | **Fixed** (`EditValidator` prevents collisions at write time; 1-tap resolution in editor; MCP structured errors; startup dedupe `sectograph_deduped_v1`) |
| RC3 | **Limits contradict each other.** `maxBlocks12H=12`, `maxBlocks24H=18`, `maxDialVisibleBlocks=10`, `previousBlocksCount 0..3`, `futureBlocksCount 0..3`. Painter forces `max(1, previousBlocksCount)` so P=0 still shows a previous block. | `app_layout_constants.dart`, `sectograph_painter.dart`, `dial_settings.dart` | P2, P3 | **Fixed** (`BlockBudget` unified authority, `maxDialVisibleBlocks` deleted, `HorizonSelector` true P=0 implementation) |
| RC4 | **Two-stage warp with hidden coupling.** `FisheyeTimeLens` then `DialSectorLayoutStretcher` (which also reads `currentTime`). Widget receives only `focusAngle` + `magnification`, not stretcher's result. | `dial_image_renderer.dart`, `android_widget_service.dart` | P3, P6 | **Fixed in Engine** (Single monotonic piecewise-linear `WarpSolver` + `WarpMap` with water-filling budget & degrade ladder in `lib/engine/`) |
| RC5 | **Stale widget image.** Sync fires only from `ref.listen` inside `HomeScreen.build`, only while the app screen is alive. | `home_screen.dart` | P6 | Open |
| RC6 | **Sync inputs differ by entry point.** Auto-sync uses today's projected events. "Sync widget" button uses `allEventsProvider ?? []`. | `dial_system_integrations_section.dart` | P6 | Open |
| RC7 | **No time-zone model.** Events stored with `toIso8601String()` on local `DateTime` (no offset). Cloud sync and MCP use the same strings. | `sector_event.dart`, `cloud_sync_service.dart`, `mcp_tools.dart` | P1 | **Fixed** (`ZoneClock`, `TimeSpec`, `ZoneDayProjector`, migration backup) |
| RC8 | **Content collision uses 12° midpoint heuristic**, not real geometry. Titles, pebbles and time caps overlap once the lens stretches a block. | `sectograph_painter.dart` | P4 | Open |
| RC9 | **Build blocker:** `SectographWidgetProvider.kt` was `PLACEHOLDER`. | `SectographWidgetProvider.kt` | P0 | **Fixed** (restored from `e6ce02f`) |
| RC10 | Widget `syncWidget` re-renders a 1080² PNG every minute and copies it to three files. Wastes battery and exposed to torn reads. | `WidgetSyncHelper.kt` | P6 | Open |

## Additional bugs found during implementation

<!-- Add new bugs here as they are discovered. Format:
| BN | Description | Where | Phase | Status |
-->
