# ⭕ Radian — 360° AI-Native Circular Routine & Life Dial

> **“Your day is a circle, not a checklist.”**  
> Radian is **not another to-do list** or habit tracker. It is a single, beautiful 360° circular widget that visualizes your entire day, your sub-tasks, and your real-time biological rhythm at a single effortless glance.  
> 
> **No guilt. No shrill nagging notifications. No manual clicking.**  
> Plan days, months, or years simply by chatting with AI via the **Model Context Protocol (MCP)**. Glance at your dial: if you feel it, do it. If not, skip it.

---

## 🧭 The Anti-Todo Manifesto: Why Radian Exists

Modern productivity apps are broken. They turn your day into an endless vertical list of shame—nagging you with shrill, anxiety-inducing notifications, forcing you to manually check boxes, snooze overdue tasks, and manage the manager. You spend more time maintaining your to-do app than actually living your life.

**Time isn’t a vertical list. Time is a circle.** It rises with the sun, follows your circadian rhythm, and resets with the night.

| ❌ The Old Way (To-Do & Habit Apps) | ⭕ The Radian Way |
|---|---|
| **Lists of Shame**: Overdue red badges and task debt that induce anxiety. | **Situational Awareness**: One 360° dial shows your entire day in context. |
| **Shrill Nagging**: Constant buzzes and interruptions ordering you around. | **Guilt-Free Freedom**: No nagging alarms. Visualize it. Do it or skip it. |
| **Manual Micromanagement**: Typing, dragging, clicking checkboxes endlessly. | **Conversational AI Planning**: Just talk to AI. It arranges the geometry. |
| **Blind to Your Body**: Treats humans like robotic task-execution machines. | **Health-Integrated**: Aligns your schedule with sleep debt, recovery, and energy. |
| **Fragmented Widgets**: Cluttered text widgets that take up entire screens. | **Glanceable Dial Widget**: A clean, live-ticking circular clock on your home screen. |

---

## 🌐 Website & App Marketing Identity Playbook

Below is the copy, structure, and positioning designed for our official app website, landing page, and marketing campaigns:

### 1. Hero Section
* **Headline**: *Your Day is a Circle. Stop Living in a Checklist.*
* **Subhead**: *Meet Radian — the 360° visual dial widget that maps your time, sub-tasks, and biological energy into a single glance. Powered by autonomous AI via MCP. Zero nagging alarms. Zero task guilt.*
* **Primary CTA**: `[ Download Radian Widget ]`
* **Secondary CTA**: `[ Connect Your AI (MCP) ]`
* **Badge**: `⭐ 100% Free & Open Source · Privacy-First · Powered by Model Context Protocol`

### 2. The Four Pillars of the Radian Experience

#### 🎯 1. Glance, Don't Scroll
See your past hours fade, your current moment pinned by the sleek needle, and your upcoming sectors unfolding naturally around a 12h or 24h dial. Concentric rings handle simultaneous tasks without visual clutter.

#### 💬 2. Plan by Chatting, Not Dragging
Forget manual calendar math. With native Model Context Protocol (MCP) built in, connect Claude, ChatGPT, Grok, Cursor, or Gemini:
> *“Hey, I only got 5 hours of sleep last night. Clear my 8 AM deep focus, give me 45 minutes of light catch-up at 11 AM, schedule my team sync at 2 PM, and block off 8 PM for winding down.”*  
Done in 2 seconds. The AI sets the exact polar angles and colors directly on your device.

#### 🫀 3. Synchronized with Your Biology
Your productivity depends on your physiology. Radian pulls sleep stages, resting heart rate, recovery deficit, and active calories directly into the dial view so you never schedule high-intensity focus when your body needs replenishment.

#### 🕊️ 4. The "Do It or Skip It" Philosophy
Life happens. When a scheduled time block arrives, Radian doesn't bombard you with three notifications and an angry red counter. Look at your phone: if you're in the zone, dive in. If your energy shifted, let the dial sweep forward. No overdue debt, no guilt, no pressure.

---

## 🌟 Core Features & Highlights

### ⭕ 360° Polar Routine Dial
* **12-Hour & 24-Hour Dial Modes**: $0.5^\circ/\text{min}$ (12h) or $0.25^\circ/\text{min}$ (24h) sector sweeping.
* **Concentric Overlap Solver**: Automatically segments overlapping tasks into concentric tracks so every subtask is visible.
* **Touch-Scrub Needle**: Scrub smoothly through your day with polar hit-testing to inspect active, upcoming, and past blocks.
* **Glanceable Android Home Widget**: A live minute-ticking dial right on your launcher.

### 🎨 Material 3 Expressive & Adaptive Theming
* **Nothing OS & Pixel Monet Icons**: Native monochrome vector icons adapting to your wallpaper and OS palette.
* **Vibrant Theme Seeds**: OLED Midnight, Electric Indigo, Cyber Cyan, Emerald Forest, Sunset Amber, and Ruby.
* **Silky 120Hz Transitions**: Smooth sheet expansions, spring physics, and fluid dial collapses.

### 🤖 Remote & Local Model Context Protocol (MCP) Server
Radian provides an official, AI-native MCP server deployed on Cloudflare Workers with D1 persistence as well as an embedded local server:
* **Remote MCP Endpoint**: `https://sectograph-mcp.kpr25121999.workers.dev/mcp`
* **App Logo & Asset Endpoints**: `/icon.png` (512x512), `/favicon.ico`, `/logo.svg`
* **Local In-App Server**: Port `8080` with JSON-RPC 2.0 and Server-Sent Events (`/sse`).

---

## 🤖 AI Tool Catalog (What Your AI Can Do)

When connected via MCP, your AI assistant has complete situational awareness and scheduling agency:

| Tool | Capability | Description |
|---|---|---|
| `get_clock_state` | Real-time Awareness | Inspects active event, remaining time, upcoming blocks, and dial mode. |
| `list_sectors` | Visual Calendar | Reads scheduled time blocks for any target date with polar angles and colors. |
| `find_free_gaps` | Intelligent Gap Finding | Identifies unoccupied intervals on the dial ($\ge 15$ min) for optimal focus windows. |
| `bulk_schedule_sectors` | Multi-block Planning | Schedules multiple time blocks in one prompt (e.g. whole morning or week routine). |
| `replace_day_schedule` | Atomic Day Reset | Atomically wipes and replaces a day's schedule with a freshly optimized plan. |
| `schedule_sector` | Single Block Creation | Slots an event with title, start/end, category, hex color, and subtasks. |
| `get_health_metrics` | Biometric Telemetry | Retrieves sleep debt, resting heart rate, active calories, and recovery scores. |
| `correlate_health_with_schedule` | Energy Optimization | Analyzes task density against sleep deficit to suggest rest or focus pivots. |
| `generate_circadian_schedule` | Circadian Alignment | Auto-generates an optimal daily schedule aligned with circadian alertness peaks. |
| `get_dial_settings` / `update_dial_settings` | Remote Customization | Remotely switches 12h/24h mode, theme palettes, and tick styles via voice/chat. |

---

## 🔌 Connecting Your AI in 30 Seconds

### 1. Claude Desktop
Add to your `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "radian": {
      "url": "https://sectograph-mcp.kpr25121999.workers.dev/mcp"
    }
  }
}
```

### 2. Cursor IDE / Grok / Antigravity
Add as a Remote MCP endpoint:
```
https://sectograph-mcp.kpr25121999.workers.dev/mcp
```

### 3. Local In-App MCP (When phone is on the same Wi-Fi)
```
http://<PHONE_IP>:8080/sse
```

---

## 💡 User Feedback Matters: Built With You

We don't build Radian behind closed doors. Every dial style, tick face, haptic pattern, and biometric integration is shaped by real community feedback.

* **Share Your Thoughts**: Have an idea for a dial face, a smartwatch integration, or a new MCP tool? Open an [Issue](https://github.com/KSM-Tech/sectograph_mcp/issues) or start a [Discussion](https://github.com/KSM-Tech/sectograph_mcp/discussions).
* **Vote on Features**: Community polls decide our upcoming roadmap (Apple Watch complication, Wear OS tile, Google Calendar two-way sync).
* **Community Driven**: We listen, iterate, and release continuous updates based on how you experience time.

---

## 🛠️ Verification & Test Suite

Run the automated test suite verifying geometry math, concentric overlap partitioning, widget rendering, and MCP protocol handling:

```bash
flutter test
```
*(All 196 unit and widget tests passing)*

Run static analysis:
```bash
flutter analyze
```
*(0 issues found across all Dart layers)*

---

## 📐 Architecture & Project Structure

```
sectograph_mcp/
├── cloudflare/             # Cloudflare Workers Remote MCP Server with D1 persistence
│   ├── src/assets.ts       # Embedded binary 512x512 icon, favicon, and SVG logo
│   ├── src/index.ts        # Static assets, MCP discovery (/mcp), and JSON-RPC router
│   ├── src/mcp_handler.ts  # Autonomous MCP tool execution engine
│   └── src/d1_repository.ts# Cloudflare D1 SQL repository (events, health, dial settings)
├── android/                # Native Android configuration, home widget, shortcuts & adaptive icons
├── lib/
│   ├── core/               # Geometry (SectorMath, ConcentricSolver, PolarHitTest), Theme, Services
│   ├── domain/             # SectorEvent, DialSettings, HealthSummary, FreeGap, EventRepository
│   ├── data/               # LocalEventRepository (reactive + disk persistence)
│   ├── mcp/                # In-app McpServer (shelf JSON-RPC + SSE), McpTools
│   ├── presentation/
│   │   ├── controllers/    # ClockController, McpServerController, HealthController
│   │   ├── widgets/
│   │   │   ├── dial/       # SectographDial, SectographPainter, CenterSummary
│   │   │   ├── timeline/   # ExpressiveTimeline, Category Filter Chips, Undoable SnackBar
│   │   │   ├── editor/     # EventEditModal (Midnight-boundary safe), DialSettingsModal
│   │   │   └── common/     # RadianLogo (Custom Vector Emblem + Radian Typography)
│   └── main.dart
└── test/                   # 196 automated unit and widget tests
```

---

## 📄 License & Attribution

Built with passion and intention by **KSM × Tech Studio** (Founder: **PrasaD**).  
Licensed under the [MIT License](LICENSE).
