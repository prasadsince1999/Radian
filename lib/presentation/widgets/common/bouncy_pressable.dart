import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/tactile_motion_tokens.dart';

/// A tactile interactive wrapper that provides physics-based spring compression
/// and overshoot bounce on press, paired with subtle haptic feedback.
class BouncyPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDownFactor;
  final Duration pressDownDuration;
  final Duration springBackDuration;
  final Curve springBackCurve;
  final bool enableHaptic;
  final HitTestBehavior behavior;

  const BouncyPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDownFactor = TactileMotionTokens.pressScaleStandard,
    this.pressDownDuration = TactileMotionTokens.pressDownDuration,
    this.springBackDuration = TactileMotionTokens.springBackDuration,
    this.springBackCurve = TactileMotionTokens.bouncySpringCurve,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  /// Pronounced spring squash (0.88) for Floating Action Buttons.
  const BouncyPressable.fab({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDownFactor = TactileMotionTokens.pressScaleFab,
    this.pressDownDuration = TactileMotionTokens.pressDownDuration,
    this.springBackDuration = TactileMotionTokens.springBackDuration,
    this.springBackCurve = TactileMotionTokens.bouncySpringCurve,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  /// Standard tactile spring (0.92) for buttons, filter chips, and pill switches.
  const BouncyPressable.standard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDownFactor = TactileMotionTokens.pressScaleStandard,
    this.pressDownDuration = TactileMotionTokens.pressDownDuration,
    this.springBackDuration = TactileMotionTokens.springBackDuration,
    this.springBackCurve = TactileMotionTokens.bouncySpringCurve,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  /// Subtle tactile spring (0.96) for event list cards and interactive tiles.
  const BouncyPressable.card({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDownFactor = TactileMotionTokens.pressScaleCard,
    this.pressDownDuration = TactileMotionTokens.pressDownDuration,
    this.springBackDuration = TactileMotionTokens.springBackDuration,
    this.springBackCurve = TactileMotionTokens.bouncySpringCurve,
    this.enableHaptic = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<BouncyPressable> createState() => _BouncyPressableState();
}

class _BouncyPressableState extends State<BouncyPressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.pressDownDuration,
      reverseDuration: widget.springBackDuration,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDownFactor)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: Curves.easeOutQuad,
            reverseCurve: widget.springBackCurve,
          ),
        );
  }

  @override
  void didUpdateWidget(covariant BouncyPressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scaleDownFactor != widget.scaleDownFactor ||
        oldWidget.springBackCurve != widget.springBackCurve) {
      _scaleAnimation = Tween<double>(begin: 1.0, end: widget.scaleDownFactor)
          .animate(
            CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutQuad,
              reverseCurve: widget.springBackCurve,
            ),
          );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTap == null && widget.onLongPress == null) {
      return widget.child;
    }

    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress != null
          ? () {
              if (widget.enableHaptic) {
                HapticFeedback.mediumImpact();
              }
              widget.onLongPress?.call();
            }
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) =>
            Transform.scale(scale: _scaleAnimation.value, child: child),
        child: widget.child,
      ),
    );
  }
}
