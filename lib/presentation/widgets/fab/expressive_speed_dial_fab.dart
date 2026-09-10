import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/expressive_shapes.dart';
import '../common/bouncy_pressable.dart';

/// Data model representing a speed-dial action item.
class SpeedDialAction {
  const SpeedDialAction({
    required this.id,
    required this.icon,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String id;
  final IconData icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;
}

/// Material 3 Expressive Morphing Speed Dial Floating Action Button.
///
/// Features:
/// - Hero FAB morphs its icon 135° smoothly from Add (+) to Close (×).
/// - Container transitions with bouncy spring physics and tactile squash on press.
/// - Secondary speed dial action chips expand vertically with staggered spring animation.
/// - Tactile haptic feedback on toggle and item selection.
class ExpressiveSpeedDialFab extends StatefulWidget {
  const ExpressiveSpeedDialFab({
    super.key,
    required this.actions,
    required this.onActionSelected,
    this.heroIcon = Icons.add_rounded,
    this.heroColor,
    this.heroIconColor,
    this.tooltip,
  });

  final List<SpeedDialAction> actions;
  final ValueChanged<String> onActionSelected;
  final IconData heroIcon;
  final Color? heroColor;
  final Color? heroIconColor;
  final String? tooltip;

  @override
  State<ExpressiveSpeedDialFab> createState() => _ExpressiveSpeedDialFabState();
}

class _ExpressiveSpeedDialFabState extends State<ExpressiveSpeedDialFab>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );

    _rotationAnimation =
        Tween<double>(
          begin: 0.0,
          end: 135.0 * (math.pi / 180.0), // 135 degrees in radians
        ).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutBack,
          ),
        );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _selectAction(String id) {
    HapticFeedback.mediumImpact();
    _toggle();
    widget.onActionSelected(id);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final heroBg = widget.heroColor ?? colorScheme.primaryContainer;
    final heroFg = widget.heroIconColor ?? colorScheme.onPrimaryContainer;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Secondary Speed Dial Action Items
        AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            final value = _expandAnimation.value;
            if (value <= 0.01) return const SizedBox.shrink();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < widget.actions.length; i++) ...[
                  _buildActionRow(widget.actions[i], value, i),
                  const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),

        // Main Hero FAB Button
        Tooltip(
          message: widget.tooltip ?? '',
          child: BouncyPressable.fab(
            onTap: _toggle,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Container(
                  width: 58,
                  height: 58,
                  decoration: ShapeDecoration(
                    shape: ExpressiveShapes.squircle(20),
                    color: Color.lerp(
                      heroBg,
                      colorScheme.outlineVariant,
                      _animationController.value * 0.4,
                    ),
                  ),
                  child: Center(
                    child: Transform.rotate(
                      angle: _rotationAnimation.value,
                      child: Icon(widget.heroIcon, size: 28, color: heroFg),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionRow(
    SpeedDialAction action,
    double animationValue,
    int index,
  ) {
    // Slight stagger per item
    final itemProgress = (animationValue * 1.2 - (index * 0.08)).clamp(
      0.0,
      1.0,
    );
    final scale = itemProgress;
    final opacity = itemProgress.clamp(0.0, 1.0);

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final itemBg = action.backgroundColor ?? colorScheme.surfaceContainerHigh;
    final itemFg = action.foregroundColor ?? colorScheme.onSurface;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Action Label Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: ShapeDecoration(
                shape: ExpressiveShapes.full,
                color: colorScheme.surface.withValues(alpha: 0.88),
              ),
              child: Text(
                action.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Action Circle Button
            BouncyPressable.standard(
              onTap: () => _selectAction(action.id),
              child: Container(
                width: 44,
                height: 44,
                decoration: ShapeDecoration(
                  shape: ExpressiveShapes.squircle(14),
                  color: itemBg,
                ),
                child: Icon(action.icon, size: 20, color: itemFg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
