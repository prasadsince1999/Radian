import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dial_engine_flags.dart';
import '../../../core/services/text_measurement_service.dart';
import '../../../core/time/zone_clock.dart';
import '../../../domain/models/sector_event.dart';
import '../../../domain/schedule/occurrence_adapter.dart';
import '../../../domain/schedule/zone_day_projector.dart';
import '../../../engine/dial_input.dart' as engine;
import '../../../engine/dial_model.dart';
import '../../../engine/dial_model_builder.dart';
import '../../controllers/clock_controller.dart';
import '../../widgets/dial/dial_painter.dart';

/// Interactive Dial Lab for inspecting the Dial Engine (§7, Phase 0 & Phase 5).
///
/// Features:
/// - Side-by-side DialModel inspection and live visual rendering.
/// - Adjustable fake `now`, timezones, P/N horizon limits, and 12H/24H mode.
/// - Live telemetry: 64-bit signature, warp key, visible/hidden counts, needle angle.
/// - Switch to toggle [DialEngineFlags.newEngine] live in the UI.
class DialLabScreen extends ConsumerStatefulWidget {
  const DialLabScreen({super.key});

  @override
  ConsumerState<DialLabScreen> createState() => _DialLabScreenState();
}

class _DialLabScreenState extends ConsumerState<DialLabScreen> {
  late DateTime _simulatedNow;
  String _selectedTz = 'Asia/Kolkata';
  bool _is24Hour = false;
  int _prevBlocks = 1;
  int _nextBlocks = 3;
  bool _lensEnabled = true;
  double _lensMag = 1.8;
  bool _useNewEngine = DialEngineFlags.newEngine;

  final List<String> _zones = [
    'Asia/Kolkata',
    'Asia/Kathmandu',
    'America/New_York',
    'Europe/London',
    'Australia/Lord_Howe',
    'Pacific/Auckland',
    'UTC',
  ];

  @override
  void initState() {
    super.initState();
    _simulatedNow = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allEventsAsync = ref.watch(allEventsProvider);
    final settings = ref.watch(dialSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dial Lab',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Row(
            children: [
              Text(
                'Engine V2',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _useNewEngine ? colorScheme.primary : Colors.grey,
                ),
              ),
              Switch(
                value: _useNewEngine,
                onChanged: (val) {
                  setState(() {
                    _useNewEngine = val;
                    DialEngineFlags.newEngine = val;
                  });
                },
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: allEventsAsync.when(
        data: (events) {
          final model = _buildModel(events);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dial Visual Canvas
                Center(
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CustomPaint(
                      size: const Size(320, 320),
                      painter: DialPainter(
                        model: model,
                        settings: settings.copyWith(is24HourMode: _is24Hour),
                        theme: theme,
                        colorScheme: colorScheme,
                        showCenterClock: true,
                        showNeedle: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Telemetry Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.analytics_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Dial Model Telemetry',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${model.schemaVersion}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        _telemetryRow('Signature', model.signature),
                        _telemetryRow('Visible Blocks', '${model.blocks.length}'),
                        _telemetryRow('Hidden Blocks', '${model.hidden.hiddenCount}'),
                        _telemetryRow(
                          'Needle Display',
                          '${model.needle.displayDeg.toStringAsFixed(1)}° (Natural: ${model.needle.naturalDeg.toStringAsFixed(1)}°)',
                        ),
                        _telemetryRow(
                          'Active Block',
                          model.center.activeTitle.isNotEmpty
                              ? model.center.activeTitle
                              : 'None (Free Time)',
                        ),
                        _telemetryRow('Warp Key', model.warpKey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Controls Card
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Engine Controls',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Timezone Selector
                        DropdownButtonFormField<String>(
                          initialValue: _selectedTz,
                          decoration: const InputDecoration(
                            labelText: 'IANA Timezone',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items: _zones
                              .map(
                                (z) => DropdownMenuItem(
                                  value: z,
                                  child: Text(z),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedTz = val);
                          },
                        ),
                        const SizedBox(height: 12),

                        // Time Scrubber (00:00 - 23:59)
                        Row(
                          children: [
                            const Text('Simulated Time: '),
                            Text(
                              '${_simulatedNow.hour.toString().padLeft(2, '0')}:${_simulatedNow.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            TextButton.icon(
                              onPressed: () {
                                setState(() => _simulatedNow = DateTime.now());
                              },
                              icon: const Icon(Icons.restore_rounded, size: 16),
                              label: const Text('Reset Now'),
                            ),
                          ],
                        ),
                        Slider(
                          min: 0,
                          max: 1439,
                          value: (_simulatedNow.hour * 60 + _simulatedNow.minute)
                              .toDouble(),
                          onChanged: (val) {
                            final totalMin = val.round();
                            final h = totalMin ~/ 60;
                            final m = totalMin % 60;
                            setState(() {
                              _simulatedNow = DateTime(
                                _simulatedNow.year,
                                _simulatedNow.month,
                                _simulatedNow.day,
                                h,
                                m,
                              );
                            });
                          },
                        ),

                        // Mode & Horizon Sliders
                        SwitchListTile(
                          title: const Text('24-Hour Dial Mode'),
                          value: _is24Hour,
                          onChanged: (val) => setState(() => _is24Hour = val),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Focus Lens Enabled'),
                          value: _lensEnabled,
                          onChanged: (val) => setState(() => _lensEnabled = val),
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        if (_lensEnabled)
                          Row(
                            children: [
                              Text('Lens Magnification: ${_lensMag.toStringAsFixed(1)}x'),
                              Expanded(
                                child: Slider(
                                  min: 1.0,
                                  max: 3.0,
                                  divisions: 20,
                                  value: _lensMag,
                                  onChanged: (val) =>
                                      setState(() => _lensMag = val),
                                ),
                              ),
                            ],
                          ),

                        Row(
                          children: [
                            Text('Previous Blocks (P = $_prevBlocks):'),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: 3,
                                divisions: 3,
                                value: _prevBlocks.toDouble(),
                                onChanged: (val) =>
                                    setState(() => _prevBlocks = val.round()),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Text('Future Blocks (N = $_nextBlocks):'),
                            Expanded(
                              child: Slider(
                                min: 0,
                                max: 3,
                                divisions: 3,
                                value: _nextBlocks.toDouble(),
                                onChanged: (val) =>
                                    setState(() => _nextBlocks = val.round()),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading events: $err')),
      ),
    );
  }

  Widget _telemetryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  DialModel _buildModel(List<SectorEvent> events) {
    final snapshot = ZoneClockSnapshot.fromDateTime(
      _simulatedNow,
      tzid: _selectedTz,
    );

    final projected = ZoneDayProjector.projectAllOccurrences(
      events: events,
      targetDay: _simulatedNow,
      displayZone: snapshot.localNow.location,
      is24HourMode: _is24Hour,
    );

    final occurrences = projected.map((o) {
      return OccurrenceAdapter.fromSectorEvent(
        o.toSectorEvent(is24HourMode: _is24Hour),
      );
    }).toList();

    final input = engine.DialInput.raw(
      clock: snapshot,
      occurrences: occurrences,
      prefs: engine.DialPrefs(
        is24HourMode: _is24Hour,
        previousBlocksCount: _prevBlocks,
        futureBlocksCount: _nextBlocks,
        isFocusLensEnabled: _lensEnabled,
        lensMagnification: _lensMag,
      ),
      window: _is24Hour
          ? engine.DialWindowMode.fullDay24
          : engine.DialWindowMode.rolling,
      surface: const engine.DialSurface(size: 320.0),
    );

    return DialModelBuilder.build(
      input,
      textMeasurer: TextMeasurementService.instance,
    );
  }
}
