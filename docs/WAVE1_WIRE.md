# Wave 1 leftover wire (do this after pull)

Projector and tests are already on main.
These two live files still use the old “every block is daily” branch.

## 1. `lib/data/repositories/local_event_repository.dart`

Add import:

```dart
import '../../domain/schedule/event_day_projector.dart';
```

After the v4 cleanup block, stamp existing blocks as daily:

```dart
      final didStampDaily =
          prefs!.getBool('sectograph_stamped_daily_repeat_v1') ?? false;
      if (!didStampDaily) {
        for (int i = 0; i < _events.length; i++) {
          final ev = _events[i];
          if (ev.repeatDays == null || ev.repeatDays!.isEmpty) {
            _events[i] = ev.copyWith(
              repeatDays: EventDayProjector.dailyWeekdays,
            );
            hasEnriched = true;
          }
        }
        unawaited(
          prefs!.setBool('sectograph_stamped_daily_repeat_v1', true),
        );
      }
```

Replace the body of `_filterAndProjectForDay` so it starts with:

```dart
    final uniqueDayEvents = EventDayProjector.projectAll(events, day);
    final deconflictedDayEvents = _deconflictDayEvents(uniqueDayEvents);
```

Delete the old for-loop that says `PERMANENT DAILY ROUTINE BLOCK`.
Keep the ConcentricSolver mapping that follows.

## 2. `lib/presentation/widgets/dial/sectograph_dial.dart`

In the projection loop, replace the `else { // Permanent daily routine block` branch with:

```dart
                      } else if (e.start.year == viewingDay.year &&
                          e.start.month == viewingDay.month &&
                          e.start.day == viewingDay.day) {
                        projectedDayEvents.add(e);
                      }
```

Use the local day variable name if it is not `viewingDay`.

## 3. Check

```bash
flutter test test/domain/event_day_projector_test.dart
flutter analyze lib/data/repositories/local_event_repository.dart \
  lib/presentation/widgets/dial/sectograph_dial.dart
```
