import 'package:flutter/material.dart';

/// Central application presets for event categories, block colors, theme seeds, and solid icons.
abstract final class AppPresets {
  /// Default category labels for sector events.
  static const List<String> defaultCategories = [
    'Work',
    'Deep Focus',
    'Meetings',
    'Rest',
    'Fitness',
    'Learning',
    'Creative',
    'Personal',
  ];

  /// Palette of 10 hex colors used when creating or editing events.
  static const List<String> defaultColorPalette = [
    '#6366F1', // Indigo
    '#3B82F6', // Blue
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#14B8A6', // Teal
    '#F59E0B', // Amber
    '#F97316', // Orange
    '#EF4444', // Red
    '#EC4899', // Pink
    '#8B5CF6', // Purple
  ];

  /// Seed color choices and display names for Material 3 Dynamic Theming.
  static const List<(String hex, String name)> defaultSeedPalette = [
    ('#6366F1', 'Indigo'),
    ('#10B981', 'Emerald'),
    ('#8B5CF6', 'Purple'),
    ('#F59E0B', 'Amber'),
    ('#EF4444', 'Red'),
    ('#06B6D4', 'Cyan'),
    ('#EC4899', 'Pink'),
  ];

  /// Curated solid icon presets for time blocks.
  static const List<(String id, IconData icon, String label)>
  defaultIconPresets = [
    ('smiley', Icons.sentiment_satisfied_alt_rounded, 'Happy'),
    ('coffee', Icons.coffee_rounded, 'Coffee'),
    ('brush', Icons.brush_rounded, 'Beauty'),
    ('mail', Icons.mail_rounded, 'Mail'),
    ('science', Icons.science_rounded, 'Science'),
    ('lab', Icons.biotech_rounded, 'Lab'),
    ('night', Icons.nightlight_round, 'Night'),
    ('video', Icons.videocam_rounded, 'Video'),
    ('heart', Icons.favorite_rounded, 'Health'),
    ('flower', Icons.local_florist_rounded, 'Nature'),
    ('drink', Icons.liquor_rounded, 'Drink'),
    ('football', Icons.sports_football_rounded, 'Sports'),
    ('clipboard', Icons.assignment_rounded, 'Tasks'),
    ('water', Icons.water_drop_rounded, 'Water'),
    ('balance', Icons.balance_rounded, 'Legal'),
    ('tea', Icons.local_cafe_rounded, 'Tea'),
    ('palette', Icons.palette_rounded, 'Art'),
    ('fitness', Icons.fitness_center_rounded, 'Gym'),
    ('swimming', Icons.pool_rounded, 'Swim'),
    ('fruit', Icons.apple_rounded, 'Food'),
    ('sports', Icons.sports_baseball_rounded, 'Sports'),
    ('key', Icons.vpn_key_rounded, 'Key'),
    ('book', Icons.menu_book_rounded, 'Read'),
    ('eye', Icons.visibility_rounded, 'Watch'),
    ('podcast', Icons.podcasts_rounded, 'Podcast'),
    ('restaurant', Icons.restaurant_rounded, 'Meal'),
    ('music', Icons.music_note_rounded, 'Music'),
    ('money', Icons.attach_money_rounded, 'Finance'),
    ('target', Icons.track_changes_rounded, 'Focus'),
    ('planet', Icons.public_rounded, 'Space'),
    ('coin', Icons.monetization_on_rounded, 'Money'),
    ('running', Icons.directions_run_rounded, 'Run'),
    ('helmet', Icons.sports_motorsports_rounded, 'Ride'),
    ('calculator', Icons.calculate_rounded, 'Math'),
    ('pet', Icons.pets_rounded, 'Pet'),
    ('medication', Icons.medication_rounded, 'Meds'),
    ('home', Icons.home_rounded, 'Home'),
    ('laptop', Icons.laptop_chromebook, 'Work'),
    ('code', Icons.terminal_rounded, 'Code'),
    ('chat', Icons.forum_rounded, 'Meeting'),
    ('sleep', Icons.bed_rounded, 'Sleep'),
    ('car', Icons.directions_car_rounded, 'Drive'),
    ('flight', Icons.flight_rounded, 'Travel'),
    ('shopping', Icons.shopping_bag_rounded, 'Shop'),
    ('star', Icons.star_rounded, 'Priority'),
    ('schedule', Icons.schedule_rounded, 'Routine'),
    ('school', Icons.school_rounded, 'Study'),
    ('camera', Icons.camera_alt_rounded, 'Photo'),
    ('bike', Icons.directions_bike_rounded, 'Cycle'),
    ('clean', Icons.cleaning_services_rounded, 'Clean'),
    ('call', Icons.call_rounded, 'Call'),
    ('walk', Icons.nordic_walking_rounded, 'Walk'),
  ];

  /// Returns the corresponding [IconData] for an [id], falling back to [Icons.schedule_rounded].
  static IconData getIconById(String? id) {
    if (id == null || id.isEmpty) return Icons.schedule_rounded;
    for (final preset in defaultIconPresets) {
      if (preset.$1 == id) return preset.$2;
    }
    return Icons.schedule_rounded;
  }

  /// Returns the corresponding preset string ID for an [icon], falling back to 'schedule'.
  static String getIdByIcon(IconData icon) {
    for (final preset in defaultIconPresets) {
      if (preset.$2.codePoint == icon.codePoint) return preset.$1;
    }
    return 'schedule';
  }
}
