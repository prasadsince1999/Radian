import 'package:flutter/material.dart';

enum DialFaceStyle { classicTicks, minimal, numbered, radialSegments }

enum SectorVisualTheme { solid, outline, softGradient, roundedCaps }

enum HandStyle { sleekNeedle, glowingArrow, minimalDot }

enum CenterClockDisplay { digital, analog, both }

enum DialShape { circle, waveRounded }

enum PastHoursStyle { focusedBlock }

/// Dial and aesthetic preferences that can be customized via UI or AI/MCP.
@immutable
class DialSettings {
  final bool is24HourMode;
  final ThemeMode themeMode;
  final String seedColorHex;
  final DialFaceStyle faceStyle;
  final SectorVisualTheme sectorStyle;
  final HandStyle handStyle;
  final CenterClockDisplay centerClockDisplay;
  final DialShape dialShape;
  final PastHoursStyle pastHoursStyle;
  final bool showAllDayEvents;
  final int startHour;
  final bool isFocusLensEnabled;
  final double lensMagnification;

  const DialSettings({
    this.is24HourMode = false,
    this.themeMode = ThemeMode.system,
    this.seedColorHex = '#6366F1', // Expressive Indigo
    this.faceStyle = DialFaceStyle.classicTicks,
    this.sectorStyle = SectorVisualTheme.roundedCaps,
    this.handStyle = HandStyle.sleekNeedle,
    this.centerClockDisplay = CenterClockDisplay.both,
    this.dialShape = DialShape.circle,
    this.pastHoursStyle = PastHoursStyle.focusedBlock,
    this.showAllDayEvents = true,
    this.startHour = 0,
    this.isFocusLensEnabled = true,
    this.lensMagnification = 1.75,
  });

  Color get seedColor {
    try {
      var hex = seedColorHex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF6366F1);
    }
  }

  DialSettings copyWith({
    bool? is24HourMode,
    ThemeMode? themeMode,
    String? seedColorHex,
    DialFaceStyle? faceStyle,
    SectorVisualTheme? sectorStyle,
    HandStyle? handStyle,
    CenterClockDisplay? centerClockDisplay,
    DialShape? dialShape,
    PastHoursStyle? pastHoursStyle,
    bool? showAllDayEvents,
    int? startHour,
    bool? isFocusLensEnabled,
    double? lensMagnification,
  }) {
    return DialSettings(
      is24HourMode: is24HourMode ?? this.is24HourMode,
      themeMode: themeMode ?? this.themeMode,
      seedColorHex: seedColorHex ?? this.seedColorHex,
      faceStyle: faceStyle ?? this.faceStyle,
      sectorStyle: sectorStyle ?? this.sectorStyle,
      handStyle: handStyle ?? this.handStyle,
      centerClockDisplay: centerClockDisplay ?? this.centerClockDisplay,
      dialShape: dialShape ?? this.dialShape,
      pastHoursStyle: pastHoursStyle ?? this.pastHoursStyle,
      showAllDayEvents: showAllDayEvents ?? this.showAllDayEvents,
      startHour: startHour ?? this.startHour,
      isFocusLensEnabled: isFocusLensEnabled ?? this.isFocusLensEnabled,
      lensMagnification: lensMagnification ?? this.lensMagnification,
    );
  }

  Map<String, dynamic> toJson() => {
    'is24HourMode': is24HourMode,
    'themeMode': themeMode.name,
    'seedColorHex': seedColorHex,
    'faceStyle': faceStyle.name,
    'sectorStyle': sectorStyle.name,
    'handStyle': handStyle.name,
    'centerClockDisplay': centerClockDisplay.name,
    'dialShape': dialShape.name,
    'pastHoursStyle': pastHoursStyle.name,
    'showAllDayEvents': showAllDayEvents,
    'startHour': startHour,
    'isFocusLensEnabled': isFocusLensEnabled,
    'lensMagnification': lensMagnification,
  };

  factory DialSettings.fromJson(Map<String, dynamic> json) {
    return DialSettings(
      is24HourMode: json['is24HourMode'] as bool? ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (e) => e.name == json['themeMode'],
        orElse: () => ThemeMode.system,
      ),
      seedColorHex: json['seedColorHex'] as String? ?? '#6366F1',
      faceStyle: DialFaceStyle.values.firstWhere(
        (e) => e.name == json['faceStyle'],
        orElse: () => DialFaceStyle.classicTicks,
      ),
      sectorStyle: SectorVisualTheme.values.firstWhere(
        (e) => e.name == json['sectorStyle'],
        orElse: () => SectorVisualTheme.roundedCaps,
      ),
      handStyle: HandStyle.values.firstWhere(
        (e) => e.name == json['handStyle'],
        orElse: () => HandStyle.sleekNeedle,
      ),
      centerClockDisplay: CenterClockDisplay.values.firstWhere(
        (e) => e.name == json['centerClockDisplay'],
        orElse: () => CenterClockDisplay.both,
      ),
      dialShape: DialShape.values.firstWhere(
        (e) => e.name == json['dialShape'],
        orElse: () => DialShape.circle,
      ),
      pastHoursStyle: PastHoursStyle.values.firstWhere(
        (e) => e.name == json['pastHoursStyle'],
        orElse: () => PastHoursStyle.focusedBlock,
      ),
      showAllDayEvents: json['showAllDayEvents'] as bool? ?? true,
      startHour: json['startHour'] as int? ?? 0,
      isFocusLensEnabled: json['isFocusLensEnabled'] as bool? ?? true,
      lensMagnification:
          (json['lensMagnification'] as num?)?.toDouble() ?? 1.75,
    );
  }
}
