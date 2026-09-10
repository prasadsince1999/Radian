import 'package:flutter/material.dart';

import '../../../core/constants/app_presets.dart';
import '../common/bouncy_pressable.dart';
import 'color_wheel_dialog.dart';

/// Full-featured Icon & Color Selection Bottom Sheet matching the user's reference design.
/// Allows searching through 50+ icons in a 5-column grid, selecting quick or custom sector colors,
/// and returns the chosen (iconName, colorHex) on "Done".
class IconColorPickerSheet extends StatefulWidget {
  final String initialIconName;
  final String initialColorHex;
  final List<String> initialPalette;

  const IconColorPickerSheet({
    super.key,
    required this.initialIconName,
    required this.initialColorHex,
    this.initialPalette = AppPresets.defaultColorPalette,
  });

  static Future<(String iconName, String colorHex)?> show(
    BuildContext context, {
    required String initialIconName,
    required String initialColorHex,
    List<String> palette = AppPresets.defaultColorPalette,
  }) {
    return showModalBottomSheet<(String, String)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => IconColorPickerSheet(
        initialIconName: initialIconName,
        initialColorHex: initialColorHex,
        initialPalette: palette,
      ),
    );
  }

  @override
  State<IconColorPickerSheet> createState() => _IconColorPickerSheetState();
}

class _IconColorPickerSheetState extends State<IconColorPickerSheet> {
  late String _selectedIconName;
  late String _selectedColorHex;
  late List<String> _palette;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedIconName = widget.initialIconName;
    _selectedColorHex = widget.initialColorHex;
    _palette = List<String>.from(widget.initialPalette);
    if (!_palette.any(
      (h) => h.toUpperCase() == _selectedColorHex.toUpperCase(),
    )) {
      _palette.insert(0, _selectedColorHex);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color get _currentColor {
    try {
      final clean = _selectedColorHex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF3B82F6);
    }
  }

  String _colorToHex(Color c) {
    final argb = c.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${argb.substring(2).toUpperCase()}';
  }

  Future<void> _openCustomColorPicker() async {
    final customColor = await ColorWheelDialog.show(context, _currentColor);
    if (customColor != null) {
      final hex = _colorToHex(customColor);
      setState(() {
        _selectedColorHex = hex;
        if (!_palette.contains(hex)) {
          _palette.add(hex);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final allIcons = AppPresets.defaultIconPresets;
    final filteredIcons = _searchQuery.isEmpty
        ? allIcons
        : allIcons.where((item) {
            final query = _searchQuery.toLowerCase();
            return item.$1.toLowerCase().contains(query) ||
                item.$3.toLowerCase().contains(query);
          }).toList();

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            // Grab handle pill
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Header: "Icon" (left), "Done" (right)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    'Icon',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const Spacer(),
                  BouncyPressable(
                    scaleDownFactor: 0.92,
                    onTap: () {
                      Navigator.of(context)
                          .pop((_selectedIconName, _selectedColorHex));
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                      child: Text(
                        'Done',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _currentColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 12),
                    Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(
                          color: colorScheme.onSurface,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val.trim());
                        },
                      ),
                    ),
                    if (_searchQuery.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 5-Column Grid of Icons
            Expanded(
              child: filteredIcons.isEmpty
                  ? Center(
                      child: Text(
                        'No icons found',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 14,
                        ),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 5,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: 1.0,
                          ),
                      itemCount: filteredIcons.length,
                      itemBuilder: (context, index) {
                        final item = filteredIcons[index];
                        final isSelected = _selectedIconName == item.$1;
                        final onSelectedColor =
                            ThemeData.estimateBrightnessForColor(
                                  _currentColor,
                                ) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black87;
                        return BouncyPressable(
                          scaleDownFactor: 0.90,
                          onTap: () {
                            setState(() {
                              _selectedIconName = isSelected ? '' : item.$1;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _currentColor
                                  : colorScheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: _currentColor.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              item.$2,
                              color: isSelected
                                  ? onSelectedColor
                                  : colorScheme.onSurface,
                              size: 26,
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Bottom Pinned Color Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant,
                    width: 1.2,
                  ),
                ),
              ),
              child: Builder(
                builder: (context) {
                  // Ensure active color is always visible in the top 6 quick swatches
                  final quickList = List<String>.from(_palette);
                  if (!quickList
                      .take(6)
                      .any(
                        (h) =>
                            h.toUpperCase() == _selectedColorHex.toUpperCase(),
                      )) {
                    quickList.removeWhere(
                      (h) => h.toUpperCase() == _selectedColorHex.toUpperCase(),
                    );
                    quickList.insert(0, _selectedColorHex);
                  }
                  final displayColors = quickList.take(6).toList();

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ...displayColors.map((hex) {
                        final c = Color(
                          int.parse('FF${hex.replaceAll('#', '')}', radix: 16),
                        );
                        final isSelected =
                            _selectedColorHex.toUpperCase() ==
                            hex.toUpperCase();
                        return BouncyPressable(
                          scaleDownFactor: 0.88,
                          onTap: () {
                            setState(() => _selectedColorHex = hex);
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : colorScheme.outlineVariant,
                                width: isSelected ? 2.5 : 1.2,
                              ),
                            ),
                            child: isSelected
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        );
                      }),

                      // Overflow / Custom Color Picker Button ('...')
                      GestureDetector(
                        key: const ValueKey('overflow_color_picker_button'),
                        behavior: HitTestBehavior.opaque,
                        onTap: _openCustomColorPicker,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainer,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colorScheme.outlineVariant,
                              width: 1.2,
                            ),
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            size: 22,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
