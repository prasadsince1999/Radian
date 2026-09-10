export interface Env {
  DB: D1Database;
  AUTH_SECRET?: string;
}

export interface SectorEventRecord {
  id: string;
  title: string;
  start: string; // ISO 8601
  end: string;   // ISO 8601
  category: string;
  color_hex: string;
  notes: string;
  is_all_day: number; // 0 or 1
  icon_name: string | null;
  reminder_minutes: number | null;
  repeat_days: string | null; // JSON array string e.g. '[1,2,3,4,5]'
  recurrence_end_date: string | null;
  updated_at: string;
  deleted_at: string | null;
}

export interface DialSettingsRecord {
  id: string;
  is_24_hour_mode: number;
  theme_mode: string;
  seed_color_hex: string;
  face_style: string;
  sector_style: string;
  hand_style: string;
  past_hours_style: string;
  center_clock_display: string;
  updated_at: string;
}

export interface HealthSummaryRecord {
  date: string; // YYYY-MM-DD
  steps: number;
  active_calories: number;
  total_calories: number;
  sleep_minutes: number;
  sleep_start: string | null;
  sleep_end: string | null;
  hydration_ml: number;
  resting_heart_rate: number | null;
  raw_json: string | null;
  updated_at: string;
}

export interface JsonRpcRequest {
  jsonrpc: '2.0';
  id?: string | number | null;
  method: string;
  params?: any;
}

export interface JsonRpcResponse {
  jsonrpc: '2.0';
  id: string | number | null;
  result?: any;
  error?: {
    code: number;
    message: string;
    data?: any;
  };
}
