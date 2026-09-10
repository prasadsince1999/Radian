-- Cloudflare D1 SQLite Schema for Sectograph
CREATE TABLE IF NOT EXISTS events (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    start TEXT NOT NULL,
    end TEXT NOT NULL,
    category TEXT DEFAULT 'General',
    color_hex TEXT DEFAULT '#3B82F6',
    notes TEXT DEFAULT '',
    is_all_day INTEGER DEFAULT 0,
    icon_name TEXT,
    reminder_minutes INTEGER,
    repeat_days TEXT, -- JSON array string e.g. '[1,2,3,4,5]'
    recurrence_end_date TEXT,
    subtasks TEXT, -- JSON array string e.g. '["subtask 1","subtask 2"]'
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    deleted_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_events_start ON events(start);
CREATE INDEX IF NOT EXISTS idx_events_updated_at ON events(updated_at);
CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);

-- Dial settings table for remote customization
CREATE TABLE IF NOT EXISTS dial_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    is_24_hour_mode INTEGER DEFAULT 0,
    theme_mode TEXT DEFAULT 'dark',
    seed_color_hex TEXT DEFAULT '#6366F1',
    face_style TEXT DEFAULT 'classicTicks',
    sector_style TEXT DEFAULT 'softGradient',
    hand_style TEXT DEFAULT 'sleekNeedle',
    past_hours_style TEXT DEFAULT 'shadowDim',
    center_clock_display TEXT DEFAULT 'digitalTimeOnly',
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- Health Connect & Biometric Summaries for AI Scheduling
CREATE TABLE IF NOT EXISTS health_summaries (
    date TEXT PRIMARY KEY,
    steps INTEGER DEFAULT 0,
    active_calories REAL DEFAULT 0,
    total_calories REAL DEFAULT 0,
    sleep_minutes INTEGER DEFAULT 0,
    sleep_start TEXT,
    sleep_end TEXT,
    hydration_ml REAL DEFAULT 0,
    resting_heart_rate INTEGER,
    raw_json TEXT,
    updated_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

