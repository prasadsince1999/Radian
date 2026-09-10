/// Represents an item with time bounds that can be assigned concentric radial levels.
abstract class ConcentricItem {
  DateTime get start;
  DateTime get end;

  int get topLevel;
  int get bottomLevel;

  bool overlapsWith(ConcentricItem other) {
    return start.isBefore(other.end) && end.isAfter(other.start);
  }
}

/// Solves concentric ring track allocations for overlapping sectors.
///
/// Ported from Sectograph's `u3/i.java` constraint solver:
/// Distributes concurrent overlapping sectors across concentric radial tracks
/// between 0 (outermost / top) and 1000 (innermost / bottom).
class ConcentricSolver {
  ConcentricSolver._();

  /// Calculates the [topLevel] and [bottomLevel] (from 0 to 1000) for each item in [items].
  ///
  /// Returns a map of item to its (topLevel, bottomLevel) bounds.
  static Map<T, ({int topLevel, int bottomLevel})>
  solve<T extends ConcentricItem>(List<T> items) {
    if (items.isEmpty) return {};

    // Sort items by start time, then by duration descending
    final sorted = List<T>.from(items)
      ..sort((a, b) {
        final cmp = a.start.compareTo(b.start);
        if (cmp != 0) return cmp;
        return b.end.compareTo(a.end);
      });

    // Partition items into overlapping clusters (connected components)
    final clusters = <List<T>>[];
    var currentCluster = <T>[];
    DateTime? clusterEnd;

    for (final item in sorted) {
      if (clusterEnd == null || item.start.isBefore(clusterEnd)) {
        currentCluster.add(item);
        if (clusterEnd == null || item.end.isAfter(clusterEnd)) {
          clusterEnd = item.end;
        }
      } else {
        clusters.add(currentCluster);
        currentCluster = [item];
        clusterEnd = item.end;
      }
    }
    if (currentCluster.isNotEmpty) {
      clusters.add(currentCluster);
    }

    final results = <T, ({int topLevel, int bottomLevel})>{};

    for (final cluster in clusters) {
      if (cluster.length == 1) {
        // Single non-overlapping item uses full radial thickness
        results[cluster.first] = (topLevel: 0, bottomLevel: 1000);
        continue;
      }

      // Assign tracks using interval scheduling (greedy first-fit)
      final trackEndTimes = <DateTime>[];
      final itemTracks = <T, int>{};

      for (final item in cluster) {
        var assignedTrack = -1;
        for (var t = 0; t < trackEndTimes.length; t++) {
          if (!item.start.isBefore(trackEndTimes[t])) {
            assignedTrack = t;
            trackEndTimes[t] = item.end;
            break;
          }
        }
        if (assignedTrack == -1) {
          assignedTrack = trackEndTimes.length;
          trackEndTimes.add(item.end);
        }
        itemTracks[item] = assignedTrack;
      }

      // Limit maximum visible concentric tracks to avoid micro-thin slivers
      const int maxVisibleTracks = 4;
      final effectiveTracks = trackEndTimes.length.clamp(1, maxVisibleTracks);
      final step = 1000 / effectiveTracks;

      for (final item in cluster) {
        final track = itemTracks[item]! % maxVisibleTracks;
        final top = (track * step).round();
        final bottom = ((track + 1) * step).round().clamp(0, 1000);
        results[item] = (topLevel: top, bottomLevel: bottom);
      }
    }

    return results;
  }
}
