import 'package:flutter/material.dart';

import '../constants/app_layout_constants.dart';

/// Official Material 3 / Android Adaptive Apps width size classes.
enum WindowWidthSizeClass {
  /// Phones in portrait mode (< 600dp).
  compact,

  /// Foldables (unfolded), small tablets, landscape phones (600dp - 840dp).
  medium,

  /// Large tablets, desktop mode, Samsung DeX, ChromeOS (>= 840dp).
  expanded,
}

/// Official Material 3 / Android Adaptive Apps height size classes.
enum WindowHeightSizeClass {
  /// Landscape phones, small windows (< 480dp).
  compact,

  /// Standard portrait phones and tablets (480dp - 900dp).
  medium,

  /// Large tablets, tall external monitors (>= 900dp).
  expanded,
}

/// Immutable representation of the current window's size classes.
@immutable
class WindowSizeClass {
  final WindowWidthSizeClass widthClass;
  final WindowHeightSizeClass heightClass;
  final Size size;

  const WindowSizeClass({
    required this.widthClass,
    required this.heightClass,
    required this.size,
  });

  /// Computes the [WindowSizeClass] for the given [size].
  factory WindowSizeClass.calculate(Size size) {
    final WindowWidthSizeClass widthClass;
    if (size.width < AppLayoutConstants.compactWidthBreakpoint) {
      widthClass = WindowWidthSizeClass.compact;
    } else if (size.width < AppLayoutConstants.mediumWidthBreakpoint) {
      widthClass = WindowWidthSizeClass.medium;
    } else {
      widthClass = WindowWidthSizeClass.expanded;
    }

    final WindowHeightSizeClass heightClass;
    if (size.height < 480.0) {
      heightClass = WindowHeightSizeClass.compact;
    } else if (size.height < 900.0) {
      heightClass = WindowHeightSizeClass.medium;
    } else {
      heightClass = WindowHeightSizeClass.expanded;
    }

    return WindowSizeClass(
      widthClass: widthClass,
      heightClass: heightClass,
      size: size,
    );
  }

  /// Derives the [WindowSizeClass] from layout [constraints].
  factory WindowSizeClass.fromBoxConstraints(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : 400.0;
    final height = constraints.hasBoundedHeight ? constraints.maxHeight : 800.0;
    return WindowSizeClass.calculate(Size(width, height));
  }

  /// Convenience accessor to obtain the current [WindowSizeClass] via [MediaQuery].
  factory WindowSizeClass.of(BuildContext context) {
    return WindowSizeClass.calculate(MediaQuery.sizeOf(context));
  }

  // --- Convenience Helpers ---

  bool get isCompactWidth => widthClass == WindowWidthSizeClass.compact;
  bool get isMediumWidth => widthClass == WindowWidthSizeClass.medium;
  bool get isExpandedWidth => widthClass == WindowWidthSizeClass.expanded;

  bool get isCompactHeight => heightClass == WindowHeightSizeClass.compact;

  /// True when the display has sufficient width for at least 2 panes side-by-side.
  bool get isTwoPane => widthClass != WindowWidthSizeClass.compact;

  /// True when the display has sufficient width for 3 panes (Nav Rail, Dial, Agenda, Details).
  bool get isThreePane => widthClass == WindowWidthSizeClass.expanded;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WindowSizeClass &&
          runtimeType == other.runtimeType &&
          widthClass == other.widthClass &&
          heightClass == other.heightClass &&
          size == other.size;

  @override
  int get hashCode => Object.hash(widthClass, heightClass, size);

  @override
  String toString() =>
      'WindowSizeClass(width: $widthClass, height: $heightClass, size: ${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)})';
}
