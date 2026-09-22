import 'package:intl/intl.dart';

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

/// Ej.: "15 de marzo de 1990".
String formatBirthDate(DateTime date) => DateFormat.yMMMMd('es').format(date);

/// Ej.: "15 de marzo".
String formatDayAndMonth(DateTime date) =>
    DateFormat("d 'de' MMMM", 'es').format(date);
