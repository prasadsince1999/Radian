import 'dial_input.dart';
import 'dial_model.dart';
import 'horizon_selector.dart';
import 'ring_assigner.dart';
import 'warp_solver.dart';

/// Single, authoritative DialModel builder (§3.2, §3.3).
///
/// Unifies in-app dial rendering and widget precomputation onto one pure Dart pipeline.
class DialModelBuilder {
  const DialModelBuilder._();

  /// Builds a complete immutable DialModel from a DialInput state.
  static DialModel build(DialInput input) {
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
    final nowNaturalDeg =
        HorizonSelector.naturalAngleDeg(input.now, is24HourMode: is24);
    final nowDisplayDeg = warp.forward(nowNaturalDeg);
    final isInsideActive = horizon.activeEvent != null;

    final needle = NeedleModel(
      displayDeg: nowDisplayDeg,
      naturalDeg: nowNaturalDeg,
      isInsideActiveBlock: isInsideActive,
      activeEventId: horizon.activeEvent?.eventId,
    );

    // 5. Dial Blocks with Content Mode, Caps, and Subtask Capsules (§4.5)
    final blocks = <DialBlock>[];
    for (final rs in ringSegments) {
      final seg = rs.segment;
      final occ = seg.occurrence;
      final sweep = rs.displaySweepDeg;

      // Determine ContentMode
      final ContentMode content;
      if (sweep >= (is24 ? 38.0 : 50.0)) {
        content = ContentMode.full;
      } else if (sweep >= (is24 ? 22.0 : 28.0)) {
        content = ContentMode.compact;
      } else if (sweep >= (is24 ? 12.0 : 16.0)) {
        content = ContentMode.iconKeyword;
      } else {
        content = ContentMode.iconOnly;
      }

      // Start / End Cap Labels
      final startLabel = _formatTime(seg.segmentStart);
      final endLabel = _formatTime(seg.segmentEnd);
      final caps = CapLabels(
        startTimeLabel: startLabel,
        endTimeLabel: endLabel,
        startAngleDeg: rs.displayStartDeg,
        endAngleDeg: (rs.displayStartDeg + rs.displaySweepDeg) % 360.0,
        isVisible: sweep >= (is24 ? 16.0 : 20.0),
      );

      // Subtask Capsules
      final capsules = <CapsulePlacement>[];
      final subCount = occ.subtaskItems.length;

      for (int i = 0; i < subCount; i++) {
        final sub = occ.subtaskItems[i];
        final double capsuleAngle;

        if (sub.startMinuteOffset != null) {
          final subDt = seg.segmentStart.add(Duration(minutes: sub.startMinuteOffset!));
          final natAngle = HorizonSelector.naturalAngleDeg(subDt, is24HourMode: is24);
          capsuleAngle = warp.forward(natAngle);
        } else {
          // Spread evenly across block arc
          final frac = (i + 1) / (subCount + 1);
          capsuleAngle = (rs.displayStartDeg + rs.displaySweepDeg * frac) % 360.0;
        }

        capsules.add(
          CapsulePlacement(
            subtaskId: sub.id,
            title: sub.title,
            centerDeg: capsuleAngle,
            isCompleted: sub.isCompleted,
          ),
        );
      }

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
          content: content,
          colorHex: occ.colorHex,
          category: occ.category,
          subtasks: occ.subtasks,
          capsules: capsules,
          caps: caps,
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
        label = h.toString();
        isMajor = h % 6 == 0; // 0, 6, 12, 18
      } else {
        final hour12 = h == 0 ? 12 : h;
        naturalDeg = (hour12 * 30.0) % 360.0;
        label = hour12.toString();
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
      centerRemaining = _formatDurationRemaining(diff);
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

    // 9. Stable 64-bit Signature
    final signature = DialModel.computeSignature(
      blocks: blocks,
      needle: needle,
      hidden: horizon.hidden,
      warp: warp,
      is24HourMode: is24,
    );

    return DialModel(
      signature: signature,
      warpKey: warpKey,
      is24HourMode: is24,
      blocks: blocks,
      hidden: horizon.hidden,
      warp: warp,
      needle: needle,
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

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _formatDurationRemaining(Duration d) {
    if (d.isNegative) return '0m';
    final totalMinutes = d.inMinutes;
    if (totalMinutes < 60) {
      return '${totalMinutes}m';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    return mins > 0 ? '${hours}h ${mins}m' : '${hours}h';
  }
}
