import { Env, SectorEventRecord, DialSettingsRecord, HealthSummaryRecord } from './types';

export class D1Repository {
  constructor(private db: D1Database) {}

  async getEventsForDay(targetDateStr: string): Promise<SectorEventRecord[]> {
    const startOfDay = `${targetDateStr}T00:00:00.000Z`;
    const endOfDay = `${targetDateStr}T23:59:59.999Z`;

    // Query non-deleted events that either fall in this day or repeat on this day
    const query = `
      SELECT * FROM events 
      WHERE deleted_at IS NULL 
        AND ((start <= ?1 AND end >= ?2) OR repeat_days IS NOT NULL)
      ORDER BY start ASC
    `;

    const { results } = await this.db.prepare(query).bind(endOfDay, startOfDay).all<SectorEventRecord>();
    const targetDate = new Date(targetDateStr);
    const dayOfWeek = targetDate.getUTCDay() === 0 ? 7 : targetDate.getUTCDay(); // 1=Mon .. 7=Sun

    // Filter recurring events
    return (results || []).filter(event => {
      if (event.repeat_days) {
        try {
          const days: number[] = JSON.parse(event.repeat_days);
          if (!days.includes(dayOfWeek)) return false;
          if (event.recurrence_end_date && new Date(event.recurrence_end_date) < targetDate) {
            return false;
          }
          return true;
        } catch {
          return false;
        }
      }
      return true;
    });
  }

  async getDeltaEvents(since?: string): Promise<SectorEventRecord[]> {
    if (!since) {
      const { results } = await this.db
        .prepare('SELECT * FROM events ORDER BY updated_at ASC LIMIT 1000')
        .all<SectorEventRecord>();
      return results || [];
    }

    const { results } = await this.db
      .prepare('SELECT * FROM events WHERE updated_at > ? ORDER BY updated_at ASC LIMIT 1000')
      .bind(since)
      .all<SectorEventRecord>();
    return results || [];
  }

  async upsertEvent(event: Partial<SectorEventRecord> & { id: string; title: string; start: string; end: string }): Promise<void> {
    const query = `
      INSERT INTO events (
        id, title, start, end, category, color_hex, notes, 
        is_all_day, icon_name, reminder_minutes, repeat_days, 
        recurrence_end_date, subtasks, updated_at, deleted_at
      ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, ?14, NULL)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        start = excluded.start,
        end = excluded.end,
        category = excluded.category,
        color_hex = excluded.color_hex,
        notes = excluded.notes,
        is_all_day = excluded.is_all_day,
        icon_name = excluded.icon_name,
        reminder_minutes = excluded.reminder_minutes,
        repeat_days = excluded.repeat_days,
        recurrence_end_date = excluded.recurrence_end_date,
        subtasks = excluded.subtasks,
        updated_at = excluded.updated_at,
        deleted_at = NULL
    `;

    const now = new Date().toISOString();
    await this.db.prepare(query).bind(
      event.id,
      event.title,
      event.start,
      event.end,
      event.category || 'General',
      event.color_hex || '#3B82F6',
      event.notes || '',
      event.is_all_day ? 1 : 0,
      event.icon_name || null,
      event.reminder_minutes ?? null,
      event.repeat_days || null,
      event.recurrence_end_date || null,
      event.subtasks || null,
      now
    ).run();
  }

  async softDeleteEvent(id: string): Promise<void> {
    const now = new Date().toISOString();
    await this.db
      .prepare('UPDATE events SET deleted_at = ?1, updated_at = ?1 WHERE id = ?2')
      .bind(now, id)
      .run();
  }

  async bulkUpsertEvents(events: Array<Partial<SectorEventRecord> & { id: string; title: string; start: string; end: string }>): Promise<void> {
    const statements = events.map(event => {
      const now = new Date().toISOString();
      return this.db.prepare(`
        INSERT INTO events (
          id, title, start, end, category, color_hex, notes, 
          is_all_day, icon_name, reminder_minutes, repeat_days, 
          recurrence_end_date, updated_at, deleted_at
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, NULL)
        ON CONFLICT(id) DO UPDATE SET
          title = excluded.title,
          start = excluded.start,
          end = excluded.end,
          category = excluded.category,
          color_hex = excluded.color_hex,
          notes = excluded.notes,
          is_all_day = excluded.is_all_day,
          icon_name = excluded.icon_name,
          reminder_minutes = excluded.reminder_minutes,
          repeat_days = excluded.repeat_days,
          recurrence_end_date = excluded.recurrence_end_date,
          updated_at = excluded.updated_at,
          deleted_at = NULL
      `).bind(
        event.id,
        event.title,
        event.start,
        event.end,
        event.category || 'General',
        event.color_hex || '#3B82F6',
        event.notes || '',
        event.is_all_day ? 1 : 0,
        event.icon_name || null,
        event.reminder_minutes ?? null,
        event.repeat_days || null,
        event.recurrence_end_date || null,
        now
      );
    });

    if (statements.length > 0) {
      await this.db.batch(statements);
    }
  }

  async replaceDaySchedule(dateStr: string, newEvents: Array<Partial<SectorEventRecord> & { id: string; title: string; start: string; end: string }>): Promise<void> {
    const startOfDay = `${dateStr}T00:00:00.000Z`;
    const endOfDay = `${dateStr}T23:59:59.999Z`;
    const now = new Date().toISOString();

    const deleteStmt = this.db.prepare(`
      UPDATE events 
      SET deleted_at = ?1, updated_at = ?1 
      WHERE deleted_at IS NULL AND start >= ?2 AND start <= ?3
    `).bind(now, startOfDay, endOfDay);

    const upsertStmts = newEvents.map(event => {
      return this.db.prepare(`
        INSERT INTO events (
          id, title, start, end, category, color_hex, notes, 
          is_all_day, icon_name, reminder_minutes, repeat_days, 
          recurrence_end_date, updated_at, deleted_at
        ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12, ?13, NULL)
      `).bind(
        event.id,
        event.title,
        event.start,
        event.end,
        event.category || 'General',
        event.color_hex || '#3B82F6',
        event.notes || '',
        event.is_all_day ? 1 : 0,
        event.icon_name || null,
        event.reminder_minutes ?? null,
        event.repeat_days || null,
        event.recurrence_end_date || null,
        now
      );
    });

    await this.db.batch([deleteStmt, ...upsertStmts]);
  }

  async getDialSettings(): Promise<DialSettingsRecord> {
    const result = await this.db
      .prepare('SELECT * FROM dial_settings WHERE id = "default"')
      .first<DialSettingsRecord>();

    if (result) return result;

    return {
      id: 'default',
      is_24_hour_mode: 0,
      theme_mode: 'dark',
      seed_color_hex: '#6366F1',
      face_style: 'classicTicks',
      sector_style: 'softGradient',
      hand_style: 'sleekNeedle',
      past_hours_style: 'shadowDim',
      center_clock_display: 'digitalTimeOnly',
      updated_at: new Date().toISOString(),
    };
  }

  async updateDialSettings(settings: Partial<DialSettingsRecord>): Promise<void> {
    const current = await this.getDialSettings();
    const now = new Date().toISOString();

    await this.db.prepare(`
      INSERT INTO dial_settings (
        id, is_24_hour_mode, theme_mode, seed_color_hex, 
        face_style, sector_style, hand_style, past_hours_style, 
        center_clock_display, updated_at
      ) VALUES ('default', ?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9)
      ON CONFLICT(id) DO UPDATE SET
        is_24_hour_mode = excluded.is_24_hour_mode,
        theme_mode = excluded.theme_mode,
        seed_color_hex = excluded.seed_color_hex,
        face_style = excluded.face_style,
        sector_style = excluded.sector_style,
        hand_style = excluded.hand_style,
        past_hours_style = excluded.past_hours_style,
        center_clock_display = excluded.center_clock_display,
        updated_at = excluded.updated_at
    `).bind(
      settings.is_24_hour_mode ?? current.is_24_hour_mode,
      settings.theme_mode ?? current.theme_mode,
      settings.seed_color_hex ?? current.seed_color_hex,
      settings.face_style ?? current.face_style,
      settings.sector_style ?? current.sector_style,
      settings.hand_style ?? current.hand_style,
      settings.past_hours_style ?? current.past_hours_style,
      settings.center_clock_display ?? current.center_clock_display,
      now
    ).run();
  }

  async getHealthSummary(date: string): Promise<HealthSummaryRecord | null> {
    const result = await this.db.prepare(`
      SELECT * FROM health_summaries WHERE date = ?1
    `).bind(date).first<HealthSummaryRecord>();
    return result || null;
  }

  async upsertHealthSummary(summary: Partial<HealthSummaryRecord> & { date: string }): Promise<void> {
    const now = new Date().toISOString();
    await this.db.prepare(`
      INSERT INTO health_summaries (
        date, steps, active_calories, total_calories, sleep_minutes, 
        sleep_start, sleep_end, hydration_ml, resting_heart_rate, raw_json, updated_at
      ) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)
      ON CONFLICT(date) DO UPDATE SET
        steps = excluded.steps,
        active_calories = excluded.active_calories,
        total_calories = excluded.total_calories,
        sleep_minutes = excluded.sleep_minutes,
        sleep_start = excluded.sleep_start,
        sleep_end = excluded.sleep_end,
        hydration_ml = excluded.hydration_ml,
        resting_heart_rate = excluded.resting_heart_rate,
        raw_json = excluded.raw_json,
        updated_at = excluded.updated_at
    `).bind(
      summary.date,
      summary.steps ?? 0,
      summary.active_calories ?? 0,
      summary.total_calories ?? 0,
      summary.sleep_minutes ?? 0,
      summary.sleep_start ?? null,
      summary.sleep_end ?? null,
      summary.hydration_ml ?? 0,
      summary.resting_heart_rate ?? null,
      summary.raw_json ?? null,
      now
    ).run();
  }
}
