import 'package:flutter/material.dart';

import '../../../../core/constants/app_presets.dart';
import '../../common/bouncy_pressable.dart';

/// Horizontal category selector chips for the Event Edit Modal.
class EventCategorySelector extends StatelessWidget {
  final String selectedCategory;
  final Color currentColor;
  final ValueChanged<String> onCategorySelected;

  const EventCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.currentColor,
    required this.onCategorySelected,
  });

  static const _categories = AppPresets.defaultCategories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final cat = _categories[i];
              final isSelected = selectedCategory == cat;
              return BouncyPressable(
                scaleDownFactor: 0.94,
                onTap: () => onCategorySelected(cat),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? currentColor
                        : colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? currentColor
                          : colorScheme.outlineVariant,
                      width: 1.0,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? (ThemeData.estimateBrightnessForColor(
                                        currentColor,
                                      ) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87)
                            : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
