import 'package:flutter_test/flutter_test.dart';
import 'package:sectograph_mcp/domain/use_cases/quick_schedule_block_use_case.dart';

import '../../mocks/fake_event_repository.dart';

void main() {
  group('QuickScheduleBlockUseCase Tests', () {
    late FakeEventRepository repository;
    final fixedNow = DateTime(2026, 9, 9, 14, 30);

    setUp(() {
      repository = FakeEventRepository();
    });

    test(
      'successfully schedules a quick block and saves to repository',
      () async {
        final useCase = QuickScheduleBlockUseCase(
          eventRepository: repository,
          nowProvider: () => fixedNow,
        );

        final event = await useCase.execute(
          title: 'Deep Focus',
          duration: const Duration(minutes: 45),
          colorHex: '#3DDC84',
          notes: 'Pomodoro block',
          iconName: 'psychology',
        );

        expect(event.title, equals('Deep Focus'));
        expect(event.start, equals(fixedNow));
        expect(event.end, equals(fixedNow.add(const Duration(minutes: 45))));
        expect(event.colorHex, equals('#3DDC84'));
        expect(event.notes, equals('Pomodoro block'));
        expect(event.iconName, equals('psychology'));

        final allEvents = await repository.getAllEvents();
        expect(allEvents.length, equals(1));
        expect(allEvents.first.id, equals(event.id));
        expect(allEvents.first.title, equals('Deep Focus'));
      },
    );

    test(
      'falls back to DateTime.now when nowProvider is not supplied',
      () async {
        final useCase = QuickScheduleBlockUseCase(eventRepository: repository);

        final before = DateTime.now();
        final event = await useCase.execute(
          title: 'Quick Nap',
          duration: const Duration(minutes: 25),
          colorHex: '#80CBC4',
        );
        final after = DateTime.now();

        expect(
          event.start.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue,
        );
        expect(
          event.start.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
        expect(event.notes, isEmpty);
        expect(event.iconName, isNull);
      },
    );
  });
}
