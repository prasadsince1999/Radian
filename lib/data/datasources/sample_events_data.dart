import '../../domain/models/sector_event.dart';

/// Isolated data generator for demo/sample schedule routines.
abstract final class SampleEventsData {
  /// Generates the standard 9 daily routine blocks across 4 days
  /// (yesterday, today, tomorrow, day-after-tomorrow).
  static List<SectorEvent> generateDefaultSchedule(DateTime referenceDate) {
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
          id: '$prefix-sleep-am',
          title: 'Sleep',
          start: day.add(const Duration(hours: 0, minutes: 0)),
          end: day.add(const Duration(hours: 7, minutes: 0)),
          colorHex: '#98A8C8', // Pastel Indigo / Periwinkle
          category: 'Rest',
          iconName: 'sleep',
          notes: '12:00 am - 07:00 am Rest & recharge',
        ),
        SectorEvent(
          id: '$prefix-read-am',
          title: 'Read',
          start: day.add(const Duration(hours: 7, minutes: 0)),
          end: day.add(const Duration(hours: 9, minutes: 0)),
          colorHex: '#9ECE79', // Pistachio Green
          category: 'Reading',
          iconName: 'book',
          notes: '07:00 am - 09:00 am Morning book & learning',
        ),
        SectorEvent(
          id: '$prefix-focus-am',
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
          id: '$prefix-focus-pm',
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
          id: '$prefix-break-pm',
          title: 'Break',
          start: day.add(const Duration(hours: 15, minutes: 0)),
          end: day.add(const Duration(hours: 15, minutes: 30)),
          colorHex: '#C8B8F4', // Soft Lavender
          category: 'Break',
          iconName: 'coffee',
          notes: '03:00 pm - 03:30 pm Break 30m & coffee',
          subtasks: const ['Coffee', 'Rest'],
        ),
        SectorEvent(
          id: '$prefix-workout-pm',
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
          id: '$prefix-read-pm',
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
          id: '$prefix-lunch-pm',
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
          id: '$prefix-code-pm',
          title: 'Flexible Hours',
          start: day.add(const Duration(hours: 20, minutes: 15)),
          end: day.add(const Duration(hours: 24, minutes: 0)),
          colorHex: '#8EA865', // Olive Green
          category: 'Code',
          iconName: 'code',
          notes: '08:15 pm - 12:00 am LeetCode & Open-source dev',
          subtasks: const ['LeetCode', 'Mock Prep'],
        ),
      ]);
    }

    return events;
  }
}
