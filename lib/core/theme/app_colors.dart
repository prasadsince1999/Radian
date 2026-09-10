import 'package:flutter/material.dart';

/// Central design tokens for the Sectograph dark espresso palette.
abstract final class AppColors {
  // --- Chassis & Canvas ---
  static const Color espressoChassisBg = Color(0xFF1E1A16);
  static const Color dialChassisBg = espressoChassisBg;
  static const Color mcpActive = Color(0xFF6366F1);

  // --- Cards & Surfaces ---
  static const Color cardBg = Color(0xFF28221D);
  static const Color cardSelectedBg = Color(0xFF342B23);
  static const Color cardBorder = Color(0xFF3D352E);
  static const Color cardBorderSubtle = Color(0xFF3A322A);
  static const Color codeBlockBg = Color(0xFF191613);
  static const Color cellBg = Color(0xFF241F1A);
  static const Color handleBar = Color(0xFF5E544B);

  // --- Typography ---
  static const Color primaryText = Color(0xFFEDE7DF);
  static const Color secondaryText = Color(0xFF9E968D);
  static const Color mutedText = Color(0xFF888177);
  static const Color tertiaryText = Color(0xFF7D756C);

  // --- 4 Core Action Squircle Identities ---
  // 1. Calendar
  static const Color calendarBg = Color(0xFF24422D);
  static const Color calendarBorder = Color(0xFF3E6D4B);
  static const Color calendarAccent = Color(0xFF8DE3A6);

  // 2. MCP Hub
  static const Color mcpBg = Color(0xFF2A2D5C);
  static const Color mcpBorder = Color(0xFF4A4F9E);
  static const Color mcpAccent = Color(0xFFB8BEFF);

  // 3. Custom / Settings
  static const Color customBg = Color(0xFF4A3319);
  static const Color customBorder = Color(0xFF7E562A);
  static const Color customAccent = Color(0xFFF5C578);

  // 4. Add Block
  static const Color addBlockBg = Color(0xFFEAA036);
  static const Color addBlockBorder = Color(0xFFFFB854);
  static const Color addBlockText = Color(0xFF1E1A16);
  static const Color orangeAccent = Color(0xFFEAA036);

  // 5. Health & Circadian AI (Coral Crimson / Rose)
  static const Color healthBg = Color(0xFF4A202A);
  static const Color healthBorder = Color(0xFF8C384D);
  static const Color healthAccent = Color(0xFFFF8DA1);
  static const Color healthSleep = Color(0xFF3949AB);
  static const Color healthWorkout = Color(0xFFE65100);

  // --- Dial & Painter Elements ---
  static const Color dialTicks = Color(0xFF7D756C);
  static const Color dialTicksSubtle = Color(0xFF4A433B);
  static const Color dialNumeralMajor = Color(0xFFEDE7DF);
  static const Color dialNumeralMinor = Color(0xFFA8A096);
  static const Color sunAccent = Color(0xFFF7C752);
  static const Color hourHand = Color(0xFF7E8B58);
  static const Color minuteHand = Color(0xFFD7D2EF);
  static const Color pivotCap = Color(0xFFF3D798);
  static const Color pivotDot = Color(0xFF221E1A);
  static const Color centerAmPm = Color(0xFFA7B1ED);
  static const Color closeCircleBg = Color(0xFF3A322A);

  // --- Footer & Mode Pills ---
  static const Color footerBtnBg = Color(0xFF2E2721);
  static const Color footerActivePill = Color(0xFF383A52);
  static const Color footerActiveText = Color(0xFFC5C8EE);

  // --- Semantic & Status Tokens ---
  static const Color statusSuccess = Color(0xFF22C55E);
  static const Color statusSuccessLight = Color(0xFF16A34A);
  static const Color statusError = Color(0xFFEF4444);
  static const Color statusErrorLight = Color(0xFFDC2626);
  static const Color statusWarning = Color(0xFFF59E0B);

  // --- Feature Branding Tokens ---
  static const Color mcpViolet = Color(0xFF7C4DFF);
  static const Color mcpVioletContainer = Color(0xFF5E35B1);
  static const Color healthCoral = Color(0xFFFF8DA1);

  // --- Quick Action Presets ---
  static const Color quickFocus = Color(0xFF6366F1);
  static const Color quickNap = Color(0xFF4338CA);
  static const Color quickWorkout = Color(0xFFF59E0B);
}
