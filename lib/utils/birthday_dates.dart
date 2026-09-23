import 'package:intl/intl.dart';

import '../models/birthday.dart';

/// Hora del día (7:00 AM) a la que se programan los recordatorios.
const int kBirthdayHour = 7;
const int kBirthdayMinute = 0;

/// Próxima ocurrencia del cumpleaños de [birthDate] a las [hour]:[minute].
///
/// Si la fecha ya pasó (o es hoy pero la hora ya pasó), devuelve la del
/// año siguiente.
DateTime nextBirthdayOccurrence(
  DateTime birthDate, {
  DateTime? from,
  int hour = kBirthdayHour,
  int minute = kBirthdayMinute,
}) {
  final now = from ?? DateTime.now();
  var candidate = DateTime(
    now.year,
    birthDate.month,
    birthDate.day,
    hour,
    minute,
  );
  if (!candidate.isAfter(now)) {
    candidate = DateTime(
      now.year + 1,
      birthDate.month,
      birthDate.day,
      hour,
      minute,
    );
  }
  return candidate;
}

/// Edad que cumple (o cumplió) la persona nacida en [birthDate] en [date].
int ageOnDate(DateTime birthDate, DateTime date) {
  var age = date.year - birthDate.year;
  final alreadyHadBirthday =
      date.month > birthDate.month ||
      (date.month == birthDate.month && date.day >= birthDate.day);
  if (!alreadyHadBirthday) {
    age--;
  }
  return age < 0 ? 0 : age;
}

/// Días naturales que faltan para [date].
int daysUntil(DateTime date, {DateTime? from}) {
  final now = from ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(date.year, date.month, date.day);
  return target.difference(today).inDays;
}

/// Indica si [birthDate] (mes y día) coincide con [date].
bool isBirthdayOn(DateTime birthDate, DateTime date) =>
    birthDate.month == date.month && birthDate.day == date.day;

/// Cumpleaños que hoy ya debieron avisarse pero cuya notificación no está
/// visible: se usan para el aviso de recuperación de la pantalla principal.
///
/// Un cumpleaños entra en la lista si es hoy, ya pasó la hora del recordatorio
/// (7:00 AM), su notificación no está activa en el sistema y el usuario no lo
/// descartó antes en esta sesión.
List<Birthday> birthdaysNeedingRecovery(
  List<Birthday> birthdays, {
  required DateTime now,
  required Set<int> activeNotificationIds,
  required Set<int> dismissedIds,
}) {
  final reminderTime = DateTime(
    now.year,
    now.month,
    now.day,
    kBirthdayHour,
    kBirthdayMinute,
  );
  if (now.isBefore(reminderTime)) {
    return const [];
  }
  return birthdays.where((birthday) {
    final id = birthday.id;
    return id != null &&
        isBirthdayOn(birthday.birthDate, now) &&
        !activeNotificationIds.contains(id) &&
        !dismissedIds.contains(id);
  }).toList();
}

/// Ej.: "15 de marzo de 1990".
String formatBirthDate(DateTime date) => DateFormat.yMMMMd('es').format(date);

/// Ej.: "15 de marzo".
String formatDayAndMonth(DateTime date) =>
    DateFormat("d 'de' MMMM", 'es').format(date);
