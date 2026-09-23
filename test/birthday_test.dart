import 'package:flutter_test/flutter_test.dart';
import 'package:notificaciones_esm/models/birthday.dart';
import 'package:notificaciones_esm/utils/birthday_dates.dart';

void main() {
  group('ageOnDate', () {
    final birth = DateTime(1990, 3, 15);

    test('resta un año si el cumpleaños aún no llega', () {
      expect(ageOnDate(birth, DateTime(2026, 3, 14)), 35);
      expect(ageOnDate(birth, DateTime(2026, 1, 1)), 35);
    });

    test('cuenta el año nuevo el mismo día del cumpleaños', () {
      expect(ageOnDate(birth, DateTime(2026, 3, 15)), 36);
      expect(ageOnDate(birth, DateTime(2026, 12, 31)), 36);
    });
  });

  group('nextBirthdayOccurrence', () {
    test('usa el mismo día a las 7:00 AM si todavía no pasó', () {
      final next = nextBirthdayOccurrence(
        DateTime(1990, 9, 25),
        from: DateTime(2026, 9, 20, 6, 0),
      );
      expect(next, DateTime(2026, 9, 25, 7, 0));
    });

    test('pasa al año siguiente si la fecha/hora ya pasó', () {
      final next = nextBirthdayOccurrence(
        DateTime(1990, 9, 25),
        from: DateTime(2026, 9, 25, 8, 30),
      );
      expect(next, DateTime(2027, 9, 25, 7, 0));
    });

    test('el mismo día antes de las 7:00 AM el aviso es hoy', () {
      final next = nextBirthdayOccurrence(
        DateTime(1990, 9, 25),
        from: DateTime(2026, 9, 25, 6, 59),
      );
      expect(next, DateTime(2026, 9, 25, 7, 0));
    });
  });

  test('daysUntil cuenta días naturales', () {
    expect(
      daysUntil(DateTime(2026, 9, 25), from: DateTime(2026, 9, 20, 23, 59)),
      5,
    );
  });

  test('Birthday.toMap/fromMap conservan los datos', () {
    final birthday = Birthday(name: 'Ana', birthDate: DateTime(2000, 1, 2));
    final restored = Birthday.fromMap(birthday.toMap());
    expect(restored.name, 'Ana');
    expect(restored.birthDate, DateTime(2000, 1, 2));
  });

  group('isBirthdayOn', () {
    test('compara solo mes y día', () {
      expect(
        isBirthdayOn(DateTime(1990, 9, 25), DateTime(2026, 9, 25)),
        isTrue,
      );
      expect(
        isBirthdayOn(DateTime(1990, 9, 25), DateTime(2026, 9, 24)),
        isFalse,
      );
      expect(
        isBirthdayOn(DateTime(1990, 9, 25), DateTime(2026, 10, 25)),
        isFalse,
      );
    });
  });

  group('birthdaysNeedingRecovery', () {
    final ana = Birthday(id: 1, name: 'Ana', birthDate: DateTime(1990, 9, 25));
    final luis = Birthday(
      id: 2,
      name: 'Luis',
      birthDate: DateTime(1996, 1, 15),
    );
    final birthdays = [ana, luis];

    test('antes de las 7:00 AM no hay aviso de recuperación', () {
      final result = birthdaysNeedingRecovery(
        birthdays,
        now: DateTime(2026, 9, 25, 6, 59),
        activeNotificationIds: const {},
        dismissedIds: const {},
      );

      expect(result, isEmpty);
    });

    test('incluye el cumpleaños de hoy si la notificación no está visible', () {
      final result = birthdaysNeedingRecovery(
        birthdays,
        now: DateTime(2026, 9, 25, 7, 0),
        activeNotificationIds: const {},
        dismissedIds: const {},
      );

      expect(result.map((birthday) => birthday.name).toList(), ['Ana']);
    });

    test('excluye el cumpleaños si su notificación está activa', () {
      final result = birthdaysNeedingRecovery(
        birthdays,
        now: DateTime(2026, 9, 25, 9, 30),
        activeNotificationIds: const {1},
        dismissedIds: const {},
      );

      expect(result, isEmpty);
    });

    test('excluye el cumpleaños descartado por el usuario', () {
      final result = birthdaysNeedingRecovery(
        birthdays,
        now: DateTime(2026, 9, 25, 9, 30),
        activeNotificationIds: const {},
        dismissedIds: const {1},
      );

      expect(result, isEmpty);
    });

    test('ignora cumpleaños que no son hoy o que no tienen id', () {
      final result = birthdaysNeedingRecovery(
        [luis, Birthday(name: 'Sin id', birthDate: DateTime(1990, 9, 25))],
        now: DateTime(2026, 9, 25, 9, 30),
        activeNotificationIds: const {},
        dismissedIds: const {},
      );

      expect(result, isEmpty);
    });
  });
}
