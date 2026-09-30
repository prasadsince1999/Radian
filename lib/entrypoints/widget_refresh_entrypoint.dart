import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/widget_frame_service.dart';
import '../core/time/zone_clock.dart';
import '../data/repositories/local_event_repository.dart';
import '../domain/models/dial_settings.dart';
import '../domain/schedule/occurrence_adapter.dart';
import '../engine/dial_input.dart';
import '../engine/widget_frame_planner.dart';

/// Headless background entrypoint for Android WorkManager / Alarms (§6.2).
///
/// Precomputes and writes the daily widget frame strip even when the main Flutter UI is terminated.
@pragma('vm:entry-point')
Future<void> widgetRefreshMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  ensureTimeZonesInitialized();

  try {
    final prefs = await SharedPreferences.getInstance();
    final repo = LocalEventRepository(prefs: prefs);
    final events = await repo.getAllEvents();

    final is24 = prefs.getBool('setting_is24h') ?? false;
    final seedHex = prefs.getString('setting_seed_color') ?? '#6366F1';
    final prevBlocks = prefs.getInt('setting_previous_blocks_count') ?? 1;
    final futureBlocks = prefs.getInt('setting_future_blocks_count') ?? 3;
    final lensEnabled = prefs.getBool('setting_lens_enabled') ?? true;
    final lensMag = prefs.getDouble('setting_lens_magnification') ?? 1.75;
    final zoneId = prefs.getString('setting_fixed_zone_id') ?? 'UTC';

    final settings = DialSettings(
      is24HourMode: is24,
      seedColorHex: seedHex,
      previousBlocksCount: prevBlocks,
      futureBlocksCount: futureBlocks,
      isFocusLensEnabled: lensEnabled,
      lensMagnification: lensMag,
    );

    final zoneClock = ZoneClock(zoneIdProvider: () => zoneId);
    final snapshot = zoneClock.snapshot();

    final occurrences = OccurrenceAdapter.projectOccurrencesForHorizon(
      events: events,
      clock: snapshot,
      is24HourMode: is24,
    );

    final enginePrefs = DialPrefs(
      is24HourMode: is24,
      previousBlocksCount: prevBlocks,
      futureBlocksCount: futureBlocks,
      isFocusLensEnabled: lensEnabled,
      lensMagnification: lensMag,
    );

    final plan = WidgetFramePlanner.plan(
      clock: snapshot,
      occurrences: occurrences,
      prefs: enginePrefs,
    );

    await WidgetFrameService.deployFrameStrip(
      plan: plan,
      settings: settings,
    );
  } catch (e, st) {
    debugPrint('widgetRefreshMain error: $e\n$st');
  }
}
