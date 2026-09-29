import 'dart:convert';

import 'dial_input.dart';
import 'horizon_selector.dart';
import 'ring_assigner.dart';
import 'warp_map.dart';

enum ContentMode {
  /// Full content: title, duration, icon, start/end caps, and subtask capsules.
  full,

  /// Compact content: icon, keyword title, and duration.
  compact,

  /// Icon and keyword title only.
  iconKeyword,

  /// Minimal icon only.
  iconOnly,
}

class CapsulePlacement {
  final String subtaskId;
  final String title;
  final double centerDeg;
  final bool isCompleted;

  const CapsulePlacement({
    required this.subtaskId,
    required this.title,
    required this.centerDeg,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
        'subtaskId': subtaskId,
        'title': title,
        'centerDeg': centerDeg,
        'isCompleted': isCompleted,
      };

  factory CapsulePlacement.fromJson(Map<String, dynamic> json) =>
      CapsulePlacement(
        subtaskId: json['subtaskId'] as String,
        title: json['title'] as String,
        centerDeg: (json['centerDeg'] as num).toDouble(),
        isCompleted: json['isCompleted'] as bool? ?? false,
      );
}

class CapLabels {
  final String startTimeLabel;
  final String endTimeLabel;
  final double startAngleDeg;
  final double endAngleDeg;
  final bool isVisible;

  const CapLabels({
    required this.startTimeLabel,
    required this.endTimeLabel,
    required this.startAngleDeg,
    required this.endAngleDeg,
    this.isVisible = true,
  });

  Map<String, dynamic> toJson() => {
        'startTimeLabel': startTimeLabel,
        'endTimeLabel': endTimeLabel,
        'startAngleDeg': startAngleDeg,
        'endAngleDeg': endAngleDeg,
        'isVisible': isVisible,
      };

  factory CapLabels.fromJson(Map<String, dynamic> json) => CapLabels(
        startTimeLabel: json['startTimeLabel'] as String? ?? '',
        endTimeLabel: json['endTimeLabel'] as String? ?? '',
        startAngleDeg: (json['startAngleDeg'] as num).toDouble(),
        endAngleDeg: (json['endAngleDeg'] as num).toDouble(),
        isVisible: json['isVisible'] as bool? ?? true,
      );
}

class DialBlock {
  final String eventId;
  final int segmentIndex;
  final String title;
  final BlockTier tier;
  final BlockRole role;
  final double startDeg;
  final double sweepDeg;
  final RingLevel ring;
  final ContentMode content;
  final String colorHex;
  final String category;
  final List<String> subtasks;
  final List<CapsulePlacement> capsules;
  final CapLabels caps;
  final Occurrence occurrence;

  const DialBlock({
    required this.eventId,
    required this.segmentIndex,
    required this.title,
    required this.tier,
    required this.role,
    required this.startDeg,
    required this.sweepDeg,
    required this.ring,
    required this.content,
    required this.colorHex,
    required this.category,
    required this.subtasks,
    required this.capsules,
    required this.caps,
    required this.occurrence,
  });

  double get endDeg => (startDeg + sweepDeg) % 360.0;

  Map<String, dynamic> toJson() => {
        'eventId': eventId,
        'segmentIndex': segmentIndex,
        'title': title,
        'tier': tier.name,
        'role': role.name,
        'startDeg': startDeg,
        'sweepDeg': sweepDeg,
        'ring': ring.name,
        'content': content.name,
        'colorHex': colorHex,
        'category': category,
        'subtasks': subtasks,
        'capsules': capsules.map((c) => c.toJson()).toList(),
        'caps': caps.toJson(),
        'occurrence': occurrence.toJson(),
      };

  factory DialBlock.fromJson(Map<String, dynamic> json) {
    return DialBlock(
      eventId: json['eventId'] as String,
      segmentIndex: json['segmentIndex'] as int? ?? 0,
      title: json['title'] as String,
      tier: BlockTier.values.byName(json['tier'] as String),
      role: BlockRole.values.byName(json['role'] as String),
      startDeg: (json['startDeg'] as num).toDouble(),
      sweepDeg: (json['sweepDeg'] as num).toDouble(),
      ring: RingLevel.values.byName(json['ring'] as String),
      content: ContentMode.values.byName(json['content'] as String),
      colorHex: json['colorHex'] as String? ?? '#6366F1',
      category: json['category'] as String? ?? 'General',
      subtasks: (json['subtasks'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      capsules: (json['capsules'] as List<dynamic>?)
              ?.map((c) => CapsulePlacement.fromJson(c as Map<String, dynamic>))
              .toList() ??
          const [],
      caps: CapLabels.fromJson(json['caps'] as Map<String, dynamic>),
      occurrence:
          Occurrence.fromJson(json['occurrence'] as Map<String, dynamic>),
    );
  }

  @override
  String toString() =>
      'DialBlock($title#$segmentIndex, ${ring.name}, ${startDeg.toStringAsFixed(1)}°+${sweepDeg.toStringAsFixed(1)}°)';
}

class NeedleModel {
  final double displayDeg;
  final double naturalDeg;
  final bool isInsideActiveBlock;
  final String? activeEventId;

  const NeedleModel({
    required this.displayDeg,
    required this.naturalDeg,
    required this.isInsideActiveBlock,
    this.activeEventId,
  });

  Map<String, dynamic> toJson() => {
        'displayDeg': displayDeg,
        'naturalDeg': naturalDeg,
        'isInsideActiveBlock': isInsideActiveBlock,
        if (activeEventId != null) 'activeEventId': activeEventId,
      };

  factory NeedleModel.fromJson(Map<String, dynamic> json) => NeedleModel(
        displayDeg: (json['displayDeg'] as num).toDouble(),
        naturalDeg: (json['naturalDeg'] as num).toDouble(),
        isInsideActiveBlock: json['isInsideActiveBlock'] as bool? ?? false,
        activeEventId: json['activeEventId'] as String?,
      );

  @override
  String toString() =>
      'NeedleModel(display: ${displayDeg.toStringAsFixed(1)}°, natural: ${naturalDeg.toStringAsFixed(1)}°)';
}

class TickModel {
  final int hour;
  final double displayDeg;
  final double naturalDeg;
  final String label;
  final bool isMajor;

  const TickModel({
    required this.hour,
    required this.displayDeg,
    required this.naturalDeg,
    required this.label,
    required this.isMajor,
  });

  Map<String, dynamic> toJson() => {
        'hour': hour,
        'displayDeg': displayDeg,
        'naturalDeg': naturalDeg,
        'label': label,
        'isMajor': isMajor,
      };

  factory TickModel.fromJson(Map<String, dynamic> json) => TickModel(
        hour: json['hour'] as int,
        displayDeg: (json['displayDeg'] as num).toDouble(),
        naturalDeg: (json['naturalDeg'] as num).toDouble(),
        label: json['label'] as String,
        isMajor: json['isMajor'] as bool,
      );

  @override
  String toString() =>
      'TickModel($label, display: ${displayDeg.toStringAsFixed(1)}°)';
}

class CenterModel {
  final String activeTitle;
  final String activeCategory;
  final String remainingDurationFormatted;
  final String modeName;

  const CenterModel({
    this.activeTitle = '',
    this.activeCategory = '',
    this.remainingDurationFormatted = '',
    this.modeName = 'digital',
  });

  Map<String, dynamic> toJson() => {
        'activeTitle': activeTitle,
        'activeCategory': activeCategory,
        'remainingDurationFormatted': remainingDurationFormatted,
        'modeName': modeName,
      };

  factory CenterModel.fromJson(Map<String, dynamic> json) => CenterModel(
        activeTitle: json['activeTitle'] as String? ?? '',
        activeCategory: json['activeCategory'] as String? ?? '',
        remainingDurationFormatted:
            json['remainingDurationFormatted'] as String? ?? '',
        modeName: json['modeName'] as String? ?? 'digital',
      );
}

/// The unified, immutable dial state produced by the engine core (§3.3, §4).
///
/// Both in-app Flutter dial and Android home screen widget consume this exact model.
class DialModel {
  static const int currentSchemaVersion = 3;

  final int schemaVersion;
  final String signature;
  final String warpKey;
  final bool is24HourMode;
  final List<DialBlock> blocks;
  final HiddenSummary hidden;
  final WarpMap warp;
  final NeedleModel needle;
  final List<TickModel> ticks;
  final CenterModel center;

  const DialModel({
    this.schemaVersion = currentSchemaVersion,
    required this.signature,
    required this.warpKey,
    required this.is24HourMode,
    required this.blocks,
    required this.hidden,
    required this.warp,
    required this.needle,
    required this.ticks,
    required this.center,
  });

  /// Computes a deterministic 64-bit FNV-1a hex signature over the canonical layout.
  static String computeSignature({
    required List<DialBlock> blocks,
    required NeedleModel needle,
    required HiddenSummary hidden,
    required WarpMap warp,
    required bool is24HourMode,
  }) {
    final sb = StringBuffer();
    sb.write('mode:$is24HourMode;');
    sb.write('needle:${needle.displayDeg.toStringAsFixed(2)};');
    sb.write('hidden:${hidden.hiddenCount};');

    for (final b in blocks) {
      sb.write(
        'b:${b.eventId}#${b.segmentIndex}:${b.startDeg.toStringAsFixed(2)}:${b.sweepDeg.toStringAsFixed(2)}:${b.ring.name};',
      );
    }

    final bytes = utf8.encode(sb.toString());
    // FNV-1a 64-bit algorithm
    BigInt hash = BigInt.parse('cbf29ce484222325', radix: 16);
    final fnvPrime = BigInt.parse('100000001b3', radix: 16);
    final mask64 = BigInt.parse('ffffffffffffffff', radix: 16);

    for (final byte in bytes) {
      hash = hash ^ BigInt.from(byte);
      hash = (hash * fnvPrime) & mask64;
    }

    return hash.toRadixString(16).padLeft(16, '0');
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'signature': signature,
        'warpKey': warpKey,
        'is24HourMode': is24HourMode,
        'blocks': blocks.map((b) => b.toJson()).toList(),
        'hidden': hidden.toJson(),
        'warp': warp.toJson(),
        'needle': needle.toJson(),
        'ticks': ticks.map((t) => t.toJson()).toList(),
        'center': center.toJson(),
      };

  @override
  String toString() =>
      'DialModel(sig: $signature, blocks: ${blocks.length}, hidden: ${hidden.hiddenCount}, needle: ${needle.displayDeg.toStringAsFixed(1)}°)';
}
