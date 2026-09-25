import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/models/sector_event.dart';
import 'package:sectograph_mcp/domain/schedule/event_day_projector.dart';

void main() {
  final tuesday = DateTime(2026, 9, 22, 10);
  final wednesday = DateTime(2026, 9, 23, 10);

  SectorEvent onceBlock() => SectorEvent(
    id: 'once-1',
    title: 'Dentist',
    start: DateTime(2026, 9, 22, 15, 0),
    end: DateTime(2026, 9, 22, 16, 0),
  );

  SectorEvent dailyBlock() => SectorEvent(
    id: 'daily-1',
    title: 'Sleep',
    start: DateTime(2026, 9, 11, 23, 0),
    end: DateTime(2026, 9, 12, 6, 0),
    repeatDays: EventDayProjector.dailyWeekdays,
  );

  test('once block appears only on its stored day', () {
    final tue = EventDayProjector.projectAll([onceBlock()], tuesday);
    final wed = EventDayProjector.projectAll([onceBlock()], wednesday);
    expect(tue, hasLength(1));
    expect(tue.single.title, 'Dentist');
    expect(wed, isEmpty);
  });

  test('daily routine appears on later weekdays', () {
    final tue = EventDayProjector.projectAll([dailyBlock()], tuesday);
    final wed = EventDayProjector.projectAll([dailyBlock()], wednesday);
    expect(tue, hasLength(1));
    expect(wed, hasLength(1));
    expect(tue.single.start.day, 22);
    expect(tue.single.start.hour, 23);
  });
}
