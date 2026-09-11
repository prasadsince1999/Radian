---
name: radian-adaptive-layout
description: Guidelines and architectural rules for designing and testing adaptive layouts in Radian following the official Android Adaptive Apps and Material 3 Window Size Class specifications.
---

# Radian Adaptive Layout Skill

Use this skill when designing, implementing, modifying, or testing UI layouts across different form factors (phones, foldables, tablets, desktop/ChromeOS).

## Core Principles

1. **Window Size Classes (Width-Driven)**:
   - **Compact** (`width < 600dp`):
     - Optimized for single-hand phone use in portrait mode.
     - Single-column vertical stacked layout with bottom navigation or contextual action header.
     - Sectograph dial occupies `flex: 7` to maximize screen width; timeline takes `flex: 5` with vertical scrolling.
   - **Medium** (`600dp <= width < 840dp`):
     - Targets foldables (unfolded), small tablets, and phone landscape.
     - 2-pane side-by-side layout: left pane hosts the circular dial; right pane hosts the interactive agenda timeline.
     - Navigation switches to a compact `NavigationRail` or leading edge actions.
   - **Expanded** (`width >= 840dp`):
     - Targets large tablets, Samsung DeX, ChromeOS, and desktop windowing.
     - 3-pane layout: Navigation Rail + Dial Pane + Interactive Agenda Timeline + Supporting Details Pane (Health Activity Heatmap and MCP 24/7 Server Diagnostics).

2. **Window Size Classes (Height-Driven)**:
   - In landscape mode (`height < 480dp`), ensure the dial does not clip vertically. The dial adapts its radius to fit available vertical headroom.

3. **Touch Targets & Ergonomics**:
   - Minimum interactive touch target is 48x48dp.
   - Polar hit testing for dial sectors must dynamically map to the active track's inner/outer radii.

4. **Multi-Window & Dynamic Resizing**:
   - Apps must never assume static screen dimensions. Always rely on `LayoutBuilder` and `WindowSizeClass.fromBoxConstraints(constraints)` to handle real-time window resizing, split-screen mode, and foldable open/close events.
