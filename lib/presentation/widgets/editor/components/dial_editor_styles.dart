import 'package:flutter/material.dart';

/// Common visual styles for Dial Settings editor components.
class DialEditorStyles {
  DialEditorStyles._();

  static ButtonStyle segmentedButtonStyle(ColorScheme colorScheme) {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.primaryContainer;
        }
        return colorScheme.surfaceContainerLow;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return colorScheme.onPrimaryContainer;
        }
        return colorScheme.onSurfaceVariant;
      }),
      side: WidgetStateProperty.all(
        BorderSide(color: colorScheme.outlineVariant, width: 1.2),
      ),
    );
  }

  static BoxDecoration cardDecoration(ColorScheme colorScheme) {
    return BoxDecoration(
      color: colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: colorScheme.outlineVariant, width: 1.2),
    );
  }
}
