import 'package:flutter/material.dart';

import '../models/birthday.dart';
import '../utils/birthday_dates.dart';

/// Fila del listado con la próxima edad y los días restantes.
class BirthdayTile extends StatelessWidget {
  const BirthdayTile({
    super.key,
    required this.birthday,
    required this.onDelete,
    this.onEdit,
    this.today,
  });

  final Birthday birthday;
  final VoidCallback onDelete;

  /// Si se indica, la fila es editable (icono y toque).
  final VoidCallback? onEdit;

  /// Fecha de referencia para calcular edad/días; inyectable en tests.
  final DateTime? today;

  String get _initials {
    final parts = birthday.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return '$first$last'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = today ?? DateTime.now();
    final isToday = isBirthdayOn(birthday.birthDate, now);
    final next = nextBirthdayOccurrence(birthday.birthDate, from: now);
    final days = daysUntil(next, from: now);
    final age = isToday
        ? ageOnDate(birthday.birthDate, now)
        : ageOnDate(birthday.birthDate, next);

    final String schedule;
    if (isToday) {
      schedule = 'Hoy cumple $age años · ¡No olvides felicitarle!';
    } else {
      final dayLabel = days == 1 ? 'día' : 'días';
      schedule =
          'Cumple $age años el ${formatDayAndMonth(next)} · faltan $days $dayLabel';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onEdit,
        leading: CircleAvatar(
          backgroundColor: isToday
              ? theme.colorScheme.primary
              : theme.colorScheme.primaryContainer,
          foregroundColor: isToday
              ? theme.colorScheme.onPrimary
              : theme.colorScheme.onPrimaryContainer,
          child: Text(_initials),
        ),
        title: Text(
          birthday.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Nació el ${formatBirthDate(birthday.birthDate)}\n$schedule',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                tooltip: 'Editar cumpleaños',
                icon: const Icon(Icons.edit_outlined),
                onPressed: onEdit,
              ),
            IconButton(
              tooltip: 'Eliminar cumpleaños',
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
