import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/expressive_shapes.dart';

/// Represents an individual option within an [ElasticPushSegmentRow].
class SegmentOption {
  const SegmentOption({required this.label, this.icon});

  final String label;
  final IconData? icon;
}

/// Material 3 Expressive Segmented Control Row with Layout Weight Push Physics.
///
/// Tapping a segment item expands its layout weight (1.30f) while compressing
/// adjacent items (0.70f), creating an elastic "dhakka/push" physics effect
/// while morphing corners between Pill and G2 Squircle.
class ElasticPushSegmentRow extends StatefulWidget {
  const ElasticPushSegmentRow({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onOptionSelected,
    this.height = 44.0,
    this.activeColor,
    this.inactiveColor,
    this.activeTextColor,
    this.inactiveTextColor,
  });

  final List<SegmentOption> options;
  final int selectedIndex;
  final ValueChanged<int> onOptionSelected;
  final double height;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? activeTextColor;
  final Color? inactiveTextColor;

  @override
  State<ElasticPushSegmentRow> createState() => _ElasticPushSegmentRowState();
}

class _ElasticPushSegmentRowState extends State<ElasticPushSegmentRow>
    with SingleTickerProviderStateMixin {
  int? _lastClickedIndex;
  late AnimationController _pushController;

  @override
  void initState() {
    super.initState();
    _pushController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 320),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            if (mounted) {
              setState(() {
                _lastClickedIndex = null;
              });
            }
          }
        });
  }

  @override
  void dispose() {
    _pushController.dispose();
    super.dispose();
  }

  void _handleTap(int index) {
    HapticFeedback.lightImpact();
    setState(() {
      _lastClickedIndex = index;
    });
    _pushController.forward(from: 0.0);
    widget.onOptionSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeBg = widget.activeColor ?? colorScheme.primary;
    final inactiveBg =
        widget.inactiveColor ??
        colorScheme.outlineVariant.withValues(alpha: 0.3);
    final activeText = widget.activeTextColor ?? colorScheme.onPrimary;
    final inactiveText =
        widget.inactiveTextColor ?? colorScheme.onSurfaceVariant;

    return Container(
      height: widget.height,
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        shape: ExpressiveShapes.full,
        color: colorScheme.surfaceContainer,
      ),
      child: AnimatedBuilder(
        animation: _pushController,
        builder: (context, child) {
          final t = _pushController.value;
          final pushCurve = CurvedAnimation(
            parent: _pushController,
            curve: Curves.easeOutBack,
          ).value;

          return Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              for (int i = 0; i < widget.options.length; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  flex: _calculateFlex(i, pushCurve, t),
                  child: _buildItem(
                    index: i,
                    option: widget.options[i],
                    isSelected: i == widget.selectedIndex,
                    isPushed: _lastClickedIndex == i,
                    activeBg: activeBg,
                    inactiveBg: inactiveBg,
                    activeText: activeText,
                    inactiveText: inactiveText,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  int _calculateFlex(int index, double pushCurve, double t) {
    if (_lastClickedIndex == null) {
      // Settled state: selected item slightly wider
      return index == widget.selectedIndex ? 120 : 90;
    }

    if (_lastClickedIndex == index) {
      // Expanding pressed button (100 -> 145 -> 120)
      final val = 100 + (45 * (1.0 - t) * pushCurve);
      return val.round().clamp(70, 160);
    } else {
      // Compressing adjacent buttons ("dhakka/push" effect)
      final val = 100 - (35 * (1.0 - t) * pushCurve);
      return val.round().clamp(60, 100);
    }
  }

  Widget _buildItem({
    required int index,
    required SegmentOption option,
    required bool isSelected,
    required bool isPushed,
    required Color activeBg,
    required Color inactiveBg,
    required Color activeText,
    required Color inactiveText,
  }) {
    final cornerRadius = isSelected ? 14.0 : 24.0;

    return GestureDetector(
      onTap: () => _handleTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: ShapeDecoration(
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(cornerRadius)),
          ),
          color: isSelected ? activeBg : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (option.icon != null) ...[
              Icon(
                option.icon,
                size: 16,
                color: isSelected ? activeText : inactiveText,
              ),
              const SizedBox(width: 4),
            ],
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeText : inactiveText,
                letterSpacing: 0.3,
              ),
              child: Text(option.label, maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}
