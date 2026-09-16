import '../../domain/models/sector_event.dart';

/// Isolated data generator for demo/sample schedule routines.
abstract final class SampleEventsData {
  /// Returns standard default schedule (Indian 12H routine).
  static List<SectorEvent> generateDefaultSchedule(DateTime referenceDate) {
    return generateIndian12hSchedule(referenceDate);
  }

  /// Generates authentic Indian daily routine blocks (12-hour perspective)
  /// featuring morning yoga, Deep AI/ML study with subtasks (LinAlg, PyTorch, Transformers),
  /// project sprints, chai recharge, fitness, and late-night coding (LeetCode, Mock Prep).
  static List<SectorEvent> generateIndian12hSchedule(DateTime referenceDate) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    final days = [
      today.subtract(const Duration(days: 1)),
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];

    final events = <SectorEvent>[];

    for (final day in days) {
      final prefix =
          '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

      events.addAll([
        // AM Half (00:00 - 12:00)
        SectorEvent(
          id: '$prefix-in-sleep',
          title: 'Sleep',
          start: day.add(const Duration(hours: 0, minutes: 0)),
          end: day.add(const Duration(hours: 6, minutes: 0)),
          colorHex: '#98A8C8', // Pastel Indigo / Periwinkle
          category: 'Rest',
          iconName: 'sleep',
          notes: '12:00 am - 06:00 am Deep restful sleep',
        ),
        SectorEvent(
          id: '$prefix-in-yoga',
          title: 'Yoga & Sadhana',
          start: day.add(const Duration(hours: 6, minutes: 0)),
          end: day.add(const Duration(hours: 7, minutes: 15)),
          colorHex: '#EC4899', // Pink
          category: 'Fitness',
          iconName: 'flower',
          notes: '06:00 am - 07:15 am Morning Pranayama, Surya Namaskar & Meditation',
          subtasks: const ['Pranayama', 'Asanas', 'Meditation'],
        ),
        SectorEvent(
          id: '$prefix-in-chai',
          title: 'Chai & Reading',
          start: day.add(const Duration(hours: 7, minutes: 15)),
          end: day.add(const Duration(hours: 8, minutes: 45)),
          colorHex: '#9ECE79', // Pistachio Green
          category: 'Reading',
          iconName: 'tea',
          notes: '07:15 am - 08:45 am Morning chai & book reading',
          subtasks: const ['Morning Chai', 'Philosophy', 'News'],
        ),
        SectorEvent(
          id: '$prefix-in-study',
          title: 'Study Time',
          start: day.add(const Duration(hours: 9, minutes: 0)),
          end: day.add(const Duration(hours: 12, minutes: 0)),
          colorHex: '#F7C752', // Sunny Yellow
          category: 'Focus',
          iconName: 'laptop',
          notes: '09:00 am - 12:00 pm Morning AI/ML Deep Study',
          subtasks: const ['LinAlg', 'PyTorch', 'Transformers'],
        ),

        // PM Half (12:00 - 24:00)
        SectorEvent(
          id: '$prefix-in-projects',
          title: 'Projects',
          start: day.add(const Duration(hours: 12, minutes: 0)),
          end: day.add(const Duration(hours: 15, minutes: 0)),
          colorHex: '#F7C752', // Sunny Yellow
          category: 'Focus',
          iconName: 'laptop',
          notes: '12:00 pm - 03:00 pm AI/ML Pipeline & Architecture',
          subtasks: const ['Data Prep', 'LoRA Tune', 'Loss & Eval'],
        ),
        SectorEvent(
          id: '$prefix-in-break',
          title: 'Break',
          start: day.add(const Duration(hours: 15, minutes: 0)),
          end: day.add(const Duration(hours: 15, minutes: 30)),
          colorHex: '#C8B8F4', // Soft Lavender
          category: 'Break',
          iconName: 'coffee',
          notes: '03:00 pm - 03:30 pm Afternoon Chai & Recharge',
          subtasks: const ['Coffee', 'Rest'],
        ),
        SectorEvent(
          id: '$prefix-in-workout',
          title: 'Workout',
          start: day.add(const Duration(hours: 15, minutes: 30)),
          end: day.add(const Duration(hours: 16, minutes: 30)),
          colorHex: '#FF7F62', // Warm Coral
          category: 'Fitness',
          iconName: 'fitness',
          notes: '03:30 pm - 04:30 pm Workout 1h & exercise',
          subtasks: const ['Gym', 'Cardio', 'Stretch'],
        ),
        SectorEvent(
          id: '$prefix-in-read',
          title: 'Read',
          start: day.add(const Duration(hours: 16, minutes: 45)),
          end: day.add(const Duration(hours: 18, minutes: 45)),
          colorHex: '#9ECE79', // Pistachio Green
          category: 'Reading',
          iconName: 'book',
          notes: '04:45 pm - 06:45 pm AI Papers & Literature Review',
          subtasks: const ['ArXiv Papers', 'Math Notes'],
        ),
        SectorEvent(
          id: '$prefix-in-dinner',
          title: 'Cooking Lunch',
          start: day.add(const Duration(hours: 19, minutes: 0)),
          end: day.add(const Duration(hours: 20, minutes: 15)),
          colorHex: '#8EC5FC', // Sky Blue
          category: 'Food',
          iconName: 'restaurant',
          notes: '07:00 pm - 08:15 pm Meal prep & healthy dinner',
          subtasks: const ['Meal Prep', 'Quick Lunch'],
        ),
        SectorEvent(
          id: '$prefix-in-code',
          title: 'Flexible Hours',
          start: day.add(const Duration(hours: 20, minutes: 15)),
          end: day.add(const Duration(hours: 24, minutes: 0)),
          colorHex: '#8EA865', // Olive Green
          category: 'Code',
          iconName: 'code',
          notes: '08:15 pm - 12:00 am LeetCode & Open-source dev',
          subtasks: const ['LeetCode', 'Mock Prep', 'PyTorch'],
        ),
      ]);
    }

    return events;
  }

  /// Generates full 24-hour continuous circadian routine for international users
  /// mapping 00:00 to 24:00 across 360° with circadian recovery, high-cognitive morning sprints,
  /// cross-timezone synchronization, strength training, and nocturnal stillness.
  static List<SectorEvent> generateInternational24hSchedule(DateTime referenceDate) {
    final today = DateTime(
      referenceDate.year,
      referenceDate.month,
      referenceDate.day,
    );

    final days = [
      today.subtract(const Duration(days: 1)),
      today,
      today.add(const Duration(days: 1)),
      today.add(const Duration(days: 2)),
    ];

    final events = <SectorEvent>[];

    for (final day in days) {
      final prefix =
          '${day.year}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';

      events.addAll([
        // 00:00 - 07:00 Circadian Sleep
        SectorEvent(
          id: '$prefix-intl-sleep',
          title: 'Circadian Sleep',
          start: day.add(const Duration(hours: 0, minutes: 0)),
          end: day.add(const Duration(hours: 7, minutes: 0)),
          colorHex: '#98A8C8',
          category: 'Rest',
          iconName: 'sleep',
          notes: 'Circadian recovery, REM stages & biological restoration',
          subtasks: const ['REM Stages', 'Deep Sleep', 'Cellular Repair'],
        ),
        // 07:00 - 08:30 Morning Mobility & Cold Brew
        SectorEvent(
          id: '$prefix-intl-mobility',
          title: 'Morning Mobility',
          start: day.add(const Duration(hours: 7, minutes: 0)),
          end: day.add(const Duration(hours: 8, minutes: 30)),
          colorHex: '#10B981',
          category: 'Health',
          iconName: 'coffee',
          notes: 'Hydration, outdoor sunlight & cold brew',
          subtasks: const ['Hydration', 'Sunlight Walk', 'Cold Brew'],
        ),
        // 09:00 - 12:30 Deep Cognitive Sprint
        SectorEvent(
          id: '$prefix-intl-focus',
          title: 'Cognitive Sprint',
          start: day.add(const Duration(hours: 9, minutes: 0)),
          end: day.add(const Duration(hours: 12, minutes: 30)),
          colorHex: '#F59E0B',
          category: 'Focus',
          iconName: 'laptop',
          notes: 'Peak morning cognitive bandwidth: Distributed Systems & Architecture',
          subtasks: const ['Distributed Systems', 'Core Engine', 'Perf Benchmark'],
        ),
        // 12:30 - 13:30 Midday Nutrition
        SectorEvent(
          id: '$prefix-intl-nutrition',
          title: 'Nutrition & Walk',
          start: day.add(const Duration(hours: 12, minutes: 30)),
          end: day.add(const Duration(hours: 13, minutes: 30)),
          colorHex: '#8EC5FC',
          category: 'Food',
          iconName: 'restaurant',
          notes: 'Whole food nutrition & 15m post-meal stroll',
          subtasks: const ['Nutrient Bowl', 'Sunlight Stroll'],
        ),
        // 14:00 - 17:00 Global Cross-Timezone Sync
        SectorEvent(
          id: '$prefix-intl-sync',
          title: 'Global Sync',
          start: day.add(const Duration(hours: 14, minutes: 0)),
          end: day.add(const Duration(hours: 17, minutes: 0)),
          colorHex: '#6366F1',
          category: 'Meetings',
          iconName: 'chat',
          notes: 'Cross-timezone overlap: SF Standup, Architecture RFCs & PR Reviews',
          subtasks: const ['SF Standup', 'PR Reviews', 'Design RFC'],
        ),
        // 17:30 - 18:45 Athletic Training
        SectorEvent(
          id: '$prefix-intl-training',
          title: 'Athletic Training',
          start: day.add(const Duration(hours: 17, minutes: 30)),
          end: day.add(const Duration(hours: 18, minutes: 45)),
          colorHex: '#EF4444',
          category: 'Fitness',
          iconName: 'fitness',
          notes: 'Strength & high-intensity aerobic training',
          subtasks: const ['Heavy Compounds', 'Kettlebell Flow', 'Cool-down'],
        ),
        // 19:15 - 20:45 Social Dinner
        SectorEvent(
          id: '$prefix-intl-dinner',
          title: 'Dinner & Social',
          start: day.add(const Duration(hours: 19, minutes: 15)),
          end: day.add(const Duration(hours: 20, minutes: 45)),
          colorHex: '#EC4899',
          category: 'Personal',
          iconName: 'restaurant',
          notes: 'Social connection, relaxed dining & screen detachment',
          subtasks: const ['Clean Fuel', 'Family Call'],
        ),
        // 21:30 - 23:00 Circadian Wind Down
        SectorEvent(
          id: '$prefix-intl-winddown',
          title: 'Wind Down',
          start: day.add(const Duration(hours: 21, minutes: 30)),
          end: day.add(const Duration(hours: 23, minutes: 0)),
          colorHex: '#8B5CF6',
          category: 'Reading',
          iconName: 'book',
          notes: 'Low blue-light exposure, paper reading & journal reflection',
          subtasks: const ['Paper Notes', 'Kindle', 'Stillness'],
        ),
        // 23:00 - 24:00 Night Stillness
        SectorEvent(
          id: '$prefix-intl-night',
          title: 'Night Rest',
          start: day.add(const Duration(hours: 23, minutes: 0)),
          end: day.add(const Duration(hours: 24, minutes: 0)),
          colorHex: '#98A8C8',
          category: 'Rest',
          iconName: 'sleep',
          notes: 'Cool room temperature & restorative transition',
        ),
      ]);
    }

    return events;
  }
}
