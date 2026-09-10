# Radian — 360° AI-Native Circular Time Blocking & Schedule Planner

> **A modern, expressive Flutter & Android application that maps your daily routine into a 360° circular clock dial, featuring Material 3 Expressive theming, Nothing OS / Pixel Monet adaptive monochrome icons, and an embedded Model Context Protocol (MCP) server for autonomous AI schedule planning with Claude, Grok, ChatGPT, Cursor, and Antigravity.**

---

## 🌟 Highlights

1. **360° Polar Routine Dial**:
   - **12-Hour & 24-Hour Modes**: 12h ($0.5^\circ/\text{min}$) and 24h ($0.25^\circ/\text{min}$) visual sector sweeping.
   - **Concentric Overlap Solver**: Partitions radial depth ($0\dots 1000$) into concentric tracks when multiple events overlap, keeping every time block distinct and visible without clipping.
   - **Interactive Scrub Needle**: Touch and scrub the dial needle with dynamic polar hit-testing to inspect active, upcoming, and past time blocks.
   - **Glanceable Android Widget**: Minute-tick live routine clock right on your home screen.

2. **Material 3 Expressive Design System**:
   - **Living Theme Seeds**: Full palette customization (Indigo, Emerald, Purple, Amber, Red, Cyan, Pink) with Light, Dark, and System modes.
   - **Adaptive & Monochrome Icons**: Custom vector foreground with Nothing OS and Android 13+ dynamic Monet theming support.
   - **Android Launcher Shortcuts**: Long-press app icon to instantly add a "New Block" or view "Today's Schedule".
   - **Tactile Haptics & Undoable Actions**: Natural mechanical feedback on selections, swipe-to-delete with floating SnackBar undo, and category filter chips.

3. **Embedded Multi-AI Model Context Protocol (MCP) Server**:
   - Built with pure Dart (`shelf`, `shelf_router`, `shelf_cors_headers`) running locally inside the app on port `8080`.
   - **Claude Desktop & Cursor**: Standard JSON-RPC 2.0 endpoint (`/mcp`) and Server-Sent Events (`/sse`).
   - **xAI Grok & Grok Bot**: Native Remote MCP over streaming HTTP (`/sse` & `/messages`).
   - **ChatGPT Mobile App**: Live auto-generated OpenAPI 3.0 specification (`/api/openapi.json`) for zero-friction Custom Actions.
   - **Direct REST API**: Endpoints (`/api/state`, `/api/bulk_plan`, `/api/settings`) for webhooks, automation bots, and personal scripts.

---

## 🤖 Autonomous AI Planning & Tool Catalog

The embedded MCP server provides AI models complete agency to inspect, plan, and optimize your schedule:

| Tool Name | Purpose | Description |
|---|---|---|
| `get_clock_state` | Situational Awareness | Returns current local time, active event, elapsed/remaining time, upcoming events, and dial mode. |
| `list_sectors` | Calendar Readout | Lists all scheduled circular sectors for any date with start/end angles, colors, and notes. |
| `find_free_gaps` | Free Time Discovery | Returns all unoccupied intervals on the circular dial ($\ge 15$ min) to find optimal scheduling windows. |
| `bulk_schedule_sectors` | Bulk Planning | Schedules multiple time blocks in one tool call (e.g. *"Plan my entire morning routine and afternoon deep work"*). |
| `replace_day_schedule` | Complete Day Reset | Atomically clears and installs a freshly generated daily plan. |
| `smart_auto_plan` | Algorithmic Slotting | Automatically slots tasks into free gaps without time conflicts. |
| `schedule_sector` | Granular Creation | Creates a single event block on the dial. |
| `update_sector` | Modification | Adjusts start/end time, title, category, or color of an existing block. |
| `delete_sector` | Removal | Deletes an event by ID. |
| `clear_sectors` | Wipe Day | Clears all sectors for a given date. |
| `get_dial_settings` | Customization Read | Returns current dial mode (12h/24h), theme, accent color, tick style, and hand style. |
| `update_dial_settings` | Customization Write | Remotely customizes dial appearance (e.g. *"Switch to 24h military mode and set an emerald dark theme"*). |
| `analyze_day_balance` | Productivity Insights | Calculates hours per category (Work, Rest, Fitness, etc.) and free time balance. |

---

## 🔌 Connecting Your AI Assistants

### 1. Claude Desktop
Add to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "radian": {
      "url": "http://127.0.0.1:8080/sse"
    }
  }
}
```

### 2. xAI Grok / Grok Bot (Remote MCP)
Configure in `grok.com/connectors` or pass in your xAI API payload:
```json
{
  "tools": [
    {
      "type": "mcp",
      "server_url": "http://<YOUR_LAN_IP>:8080/sse"
    }
  ]
}
```

### 3. ChatGPT Mobile App (Custom GPT Action)
In your Custom GPT configuration, import the live OpenAPI specification:
```
http://<YOUR_LAN_IP>:8080/api/openapi.json
```
Now ask ChatGPT on your phone:
> *"ChatGPT, plan my Tuesday: 3 hours of deep focus at 9 AM, lunch at 12:30, workout at 5 PM, and reading at 8 PM."*

---

## 🛠️ Verification & Test Suite

Run the automated test suite verifying geometry math, concentric overlap partitioning, widget rendering, and MCP protocol handling:

```bash
flutter test
```
*(118/118 tests passing)*

Run static analysis:
```bash
flutter analyze
```
*(No issues found)*

---

## 📐 Project Structure

```
sectograph_mcp/
├── android/                # Native Android configuration, home widget, shortcuts & adaptive icons
├── lib/
│   ├── core/
│   │   ├── constants/      # AppStrings (Radian v1.0.0), AppPresets, AppColors
│   │   ├── geometry/       # SectorMath, ConcentricSolver, PolarHitTest
│   │   ├── services/       # AndroidWidgetService, DeviceSettingsService
│   │   └── theme/          # ExpressiveTheme, ExpressiveShapes
│   ├── domain/             # SectorEvent, DialSettings, FreeGap, EventRepository
│   ├── data/               # LocalEventRepository (reactive + disk persistence)
│   ├── mcp/                # McpServer (shelf JSON-RPC + SSE), McpTools
│   ├── presentation/
│   │   ├── controllers/    # ClockController, McpServerController
│   │   ├── screens/        # SplashScreen, OnboardingScreen, HomeScreen
│   │   └── widgets/
│   │       ├── dial/       # SectographDial, SectographPainter, CenterSummary
│   │       ├── timeline/   # ExpressiveTimeline (with Category Filter Chips & Undo)
│   │       ├── editor/     # EventEditModal, DialSettingsModal
│   │       └── dialogs/    # AboutRadianDialog
│   └── main.dart
├── test/                   # 118 automated unit and widget tests
└── pubspec.yaml
```

---

## 📄 License & Attribution

Built with ❤️ by **KSM × Tech Studio** (Founder: **PrasaD**).  
Licensed under the [MIT License](LICENSE).
