import 'package:timezone/timezone.dart' as tz;

import '../core/i18n/numeral_system.dart';
import 'content_planner.dart';
import 'dial_input.dart';
import 'dial_model.dart';
import 'horizon_selector.dart';
import 'ring_assigner.dart';
import 'subtask_placer.dart';
import 'text_measurer.dart';
import 'warp_solver.dart';

/// Single, authoritative DialModel builder (§3.2, §3.3).
///
/// Unifies in-app dial rendering and widget precomputation onto one pure Dart pipeline.
class DialModelBuilder {
  const DialModelBuilder._();

  /// Builds a complete immutable DialModel from a DialInput state.
  static DialModel build(
    DialInput input, {
    TextMeasurer textMeasurer = const FastTextMeasurer(),
  }) {
    final prefs = input.prefs;
    final is24 = prefs.is24HourMode;

    // 1. Horizon Selection (§4.3)
    final horizon = HorizonSelector.select(input);

    // 2. Warp Solving (§4.4)
    final warp = WarpSolver.solve(horizon: horizon, input: input);

    // 3. Ring Assignment (§4.6)
    final ringSegments = RingAssigner.assign(
      segments: horizon.visibleSegments,
      warp: warp,
    );

    // 4. Needle Model (I7: needle is inside active block arc by construction)
    final nowNaturalDeg = HorizonSelector.naturalAngleDeg(
      input.now,
      is24HourMode: is24,
    );
    final nowDisplayDeg = warp.forward(nowNaturalDeg);
    final isInsideActive = horizon.activeEvent != null;

    final needle = NeedleModel(
      displayDeg: nowDisplayDeg,
      naturalDeg: nowNaturalDeg,
      isInsideActiveBlock: isInsideActive,
      activeEventId: horizon.activeEvent?.eventId,
    );

    // 4b. Secondary needle for remote time zone (§9 Feature 3)
    SecondaryNeedleModel? secondaryNeedle;
    if (prefs.secondaryTimeZone != null &&
        prefs.secondaryTimeZone!.isNotEmpty) {
      try {
        final tz.Location secZone;
        if (prefs.secondaryTimeZone!.toUpperCase() == 'UTC' ||
            prefs.secondaryTimeZone!.toUpperCase() == 'GMT') {
          secZone = tz.UTC;
        } else {
          secZone = tz.getLocation(prefs.secondaryTimeZone!);
        }
        final secTime = tz.TZDateTime.from(input.clock.utcNow, secZone);
        final secMinutes =
            secTime.hour * 60.0 + secTime.minute + secTime.second / 60.0;
        final double secNaturalDeg;
        if (is24) {
          secNaturalDeg = (secMinutes * 0.25) % 360.0;
        } else {
          secNaturalDeg = ((secMinutes % 720.0) * 0.5) % 360.0;
        }
        final secDisplayDeg = warp.forward(secNaturalDeg);

        final String tzShort;
        if (prefs.secondaryTimeZone!.contains('/')) {
          tzShort =
              prefs.secondaryTimeZone!.split('/').last.replaceAll('_', ' ');
        } else {
          tzShort = prefs.secondaryTimeZone!;
        }

        final hStr = secTime.hour.toString().padLeft(2, '0');
        final mStr = secTime.minute.toString().padLeft(2, '0');
        final rawTime = '$hStr:$mStr';
        final formattedTime = NumeralConverter.convert(
          rawTime,
          prefs.numeralSystem,
        );

        secondaryNeedle = SecondaryNeedleModel(
          displayDeg: secDisplayDeg,
          naturalDeg: secNaturalDeg,
          timeZoneId: prefs.secondaryTimeZone!,
          label: '$tzShort $formattedTime',
        );
      } catch (_) {
        // Unknown or invalid timezone string ignored gracefully
      }
    }

    // 5. Dial Blocks with Content Mode, Caps, and Subtask Capsules (§4.5)
    final blocks = <DialBlock>[];
    for (final rs in ringSegments) {
      final seg = rs.segment;
      final occ = seg.occurrence;

      // Plan content mode, caps, and reserved zones (§4.5, §5.4, §7 Phase 7)
      final contentPlan = ContentPlanner.planContent(
        segment: seg,
        displayStartDeg: rs.displayStartDeg,
        displaySweepDeg: rs.displaySweepDeg,
        is24HourMode: is24,
        textMeasurer: textMeasurer,
        dialRadius: input.surface.size / 2.0,
        textScale: input.surface.textScale,
        numeralSystem: prefs.numeralSystem,
      );

      // Place subtask capsules avoiding reserved zones and collisions
      final capsules = SubtaskPlacer.place(
        segment: seg,
        displayStartDeg: rs.displayStartDeg,
        displaySweepDeg: rs.displaySweepDeg,
        warp: warp,
        is24HourMode: is24,
        contentPlan: contentPlan,
        textMeasurer: textMeasurer,
        dialRadius: input.surface.size / 2.0,
      );

      blocks.add(
        DialBlock(
          eventId: seg.eventId,
          segmentIndex: seg.segmentIndex,
          title: seg.title,
          tier: seg.tier,
          role: seg.role,
          startDeg: rs.displayStartDeg,
          sweepDeg: rs.displaySweepDeg,
          ring: rs.ring,
          content: contentPlan.mode,
          colorHex: occ.colorHex,
          category: occ.category,
          subtasks: occ.subtasks,
          capsules: capsules,
          caps: contentPlan.caps,
          occurrence: occ,
        ),
      );
    }

    // 6. Hour Ticks
    final ticks = <TickModel>[];
    final totalTicks = is24 ? 24 : 12;
    for (int h = 0; h < totalTicks; h++) {
      final double naturalDeg;
      final String label;
      final bool isMajor;

      if (is24) {
        naturalDeg = (h * 15.0) % 360.0;
        label = NumeralConverter.formatInt(h, prefs.numeralSystem);
        isMajor = h % 6 == 0; // 0, 6, 12, 18
      } else {
        final hour12 = h == 0 ? 12 : h;
        naturalDeg = (hour12 * 30.0) % 360.0;
        label = NumeralConverter.formatInt(hour12, prefs.numeralSystem);
        isMajor = hour12 % 3 == 0; // 12, 3, 6, 9
      }

      final displayDeg = warp.forward(naturalDeg);
      ticks.add(
        TickModel(
          hour: h,
          displayDeg: displayDeg,
          naturalDeg: naturalDeg,
          label: label,
          isMajor: isMajor,
        ),
      );
    }

    // 7. Center Model
    final String centerTitle;
    final String centerCategory;
    final String centerRemaining;

    if (horizon.activeEvent != null) {
      final active = horizon.activeEvent!;
      centerTitle = active.title;
      centerCategory = active.category;
      final diff = active.end.difference(input.now);
      centerRemaining = _formatDurationRemaining(diff, prefs.numeralSystem);
    } else {
      centerTitle = 'Free Time';
      centerCategory = '';
      centerRemaining = '';
    }

    final center = CenterModel(
      activeTitle: centerTitle,
      activeCategory: centerCategory,
      remainingDurationFormatted: centerRemaining,
      modeName: 'digital',
    );

    // 8. WarpKey (Cache Key)
    final warpKey = _computeWarpKey(horizon, prefs);

    // 9. Stable 64-bit Signature (overall, including needle)
    final signature = DialModel.computeSignature(
      blocks: blocks,
      needle: needle,
      hidden: horizon.hidden,
      warp: warp,
      is24HourMode: is24,
      secondaryNeedle: secondaryNeedle,
    );

    // 10. Stable 64-bit Layout Signature (static face layout, excluding needle)
    final layoutSignature = DialModel.computeLayoutSignature(
      blocks: blocks,
      hidden: horizon.hidden,
      warp: warp,
      is24HourMode: is24,
      activeTitle: centerTitle,
      secondaryNeedle: secondaryNeedle,
    );

    return DialModel(
      signature: signature,
      layoutSignature: layoutSignature,
      warpKey: warpKey,
      is24HourMode: is24,
      blocks: blocks,
      hidden: horizon.hidden,
      warp: warp,
      needle: needle,
      secondaryNeedle: secondaryNeedle,
      ticks: ticks,
      center: center,
    );
  }

  static String _computeWarpKey(HorizonResult horizon, DialPrefs prefs) {
    final sb = StringBuffer();
    sb.write('24h:${prefs.is24HourMode};');
    sb.write('lens:${prefs.isFocusLensEnabled};');
    sb.write('mag:${prefs.lensMagnification.toStringAsFixed(2)};');
    sb.write('focus:${horizon.focusEvent?.id};');
    for (final seg in horizon.visibleSegments) {
      sb.write(
        '${seg.eventId}#${seg.segmentIndex}:${seg.naturalStartDeg.toStringAsFixed(1)}:${seg.naturalSweepDeg.toStringAsFixed(1)};',
      );
    }
    return sb.toString();
  }

  static String _formatDurationRemaining(
    Duration d, [
    NumeralSystem numeralSystem = NumeralSystem.latin,
  ]) {
    if (d.isNegative) return NumeralConverter.convert('0m', numeralSystem);
    final totalMinutes = d.inMinutes;
    final String raw;
    if (totalMinutes < 60) {
      raw = '${totalMinutes}m';
    } else {
      final hours = totalMinutes ~/ 60;
      final mins = totalMinutes % 60;
      raw = mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
    }
    return NumeralConverter.convert(raw, numeralSystem);
  }
}
