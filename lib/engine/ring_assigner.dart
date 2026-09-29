import 'angular_occupancy.dart';
import 'horizon_selector.dart';
import 'warp_map.dart';

enum RingLevel {
  /// Outer main ring (Tier A focus blocks and unconflicted secondary blocks).
  outer,

  /// Inner concentric ring (secondary blocks that would otherwise collide on outer ring).
  inner,
}

class RingAssignedSegment {
  final OccurrenceSegment segment;
  final double displayStartDeg;
  final double displaySweepDeg;
  final RingLevel ring;

  const RingAssignedSegment({
    required this.segment,
    required this.displayStartDeg,
    required this.displaySweepDeg,
    required this.ring,
  });

  String get eventId => segment.eventId;
  String get title => segment.title;
  BlockTier get tier => segment.tier;
  BlockRole get role => segment.role;

  Map<String, dynamic> toJson() => {
        'segment': segment.toJson(),
        'displayStartDeg': displayStartDeg,
        'displaySweepDeg': displaySweepDeg,
        'ring': ring.name,
      };

  @override
  String toString() =>
      'RingAssignedSegment(${segment.title}, ${ring.name}, ${displayStartDeg.toStringAsFixed(1)}°+${displaySweepDeg.toStringAsFixed(1)}°)';
}

/// Pure ring assigner unifying in-app dial and widget concentric tracks (§4.6).
///
/// Rules:
/// 1. Tier A (active, next1) always goes to RingLevel.outer.
/// 2. Tier B & C go to outer ring if no angular conflict with any block already on it,
///    otherwise assigned to RingLevel.inner.
class RingAssigner {
  const RingAssigner._();

  static List<RingAssignedSegment> assign({
    required List<OccurrenceSegment> segments,
    required WarpMap warp,
  }) {
    final outerOccupancy = AngularOccupancy(guardGapDeg: 2.0);
    final results = <RingAssignedSegment>[];

    // Compute display angles for all segments using warp
    final displaySegments = segments.map((seg) {
      final dispStart = warp.forward(seg.naturalStartDeg);
      final dispEnd = warp.forward(seg.naturalStartDeg + seg.naturalSweepDeg);
      var dispSweep = (dispEnd - dispStart + 360.0) % 360.0;
      if (dispSweep <= 1e-4 && seg.naturalSweepDeg > 0.1) {
        dispSweep = 360.0;
      }
      return _CalculatedDisplaySegment(
        segment: seg,
        displayStartDeg: dispStart,
        displaySweepDeg: dispSweep,
      );
    }).toList();

    // 1. Pass 1: Assign Tier A blocks to Outer Ring
    for (final ds in displaySegments) {
      if (ds.segment.tier == BlockTier.A) {
        outerOccupancy.admit(ds.displayStartDeg, ds.displaySweepDeg, ds.segment.eventId);
        results.add(
          RingAssignedSegment(
            segment: ds.segment,
            displayStartDeg: ds.displayStartDeg,
            displaySweepDeg: ds.displaySweepDeg,
            ring: RingLevel.outer,
          ),
        );
      }
    }

    // 2. Pass 2: Assign Tier B and C blocks (in priority order)
    for (final ds in displaySegments) {
      if (ds.segment.tier != BlockTier.A) {
        final canFitOuter =
            outerOccupancy.canAdmit(ds.displayStartDeg, ds.displaySweepDeg);

        if (canFitOuter) {
          outerOccupancy.admit(
            ds.displayStartDeg,
            ds.displaySweepDeg,
            ds.segment.eventId,
          );
          results.add(
            RingAssignedSegment(
              segment: ds.segment,
              displayStartDeg: ds.displayStartDeg,
              displaySweepDeg: ds.displaySweepDeg,
              ring: RingLevel.outer,
            ),
          );
        } else {
          // Send to concentric inner track
          results.add(
            RingAssignedSegment(
              segment: ds.segment,
              displayStartDeg: ds.displayStartDeg,
              displaySweepDeg: ds.displaySweepDeg,
              ring: RingLevel.inner,
            ),
          );
        }
      }
    }

    return results;
  }
}

class _CalculatedDisplaySegment {
  final OccurrenceSegment segment;
  final double displayStartDeg;
  final double displaySweepDeg;

  const _CalculatedDisplaySegment({
    required this.segment,
    required this.displayStartDeg,
    required this.displaySweepDeg,
  });
}
