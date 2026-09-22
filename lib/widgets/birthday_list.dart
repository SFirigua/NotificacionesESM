import 'package:flutter/material.dart';

import '../models/birthday.dart';
import 'birthday_tile.dart';

/// Lista de cumpleaños como sliver, para incrustar en el `CustomScrollView`
/// del HomeScreen (así todo el contenido scrollea junto, teclado incluido).
class BirthdaySliverList extends StatelessWidget {
  const BirthdaySliverList({
    super.key,
    required this.birthdays,
    required this.onDelete,
    this.onEdit,
    this.today,
  });

  final List<Birthday> birthdays;
  final ValueChanged<Birthday> onDelete;
  final ValueChanged<Birthday>? onEdit;

  /// Fecha inyectable para tests; por defecto la actual.
  final DateTime? today;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(bottom: 24),
      sliver: SliverList.builder(
        itemCount: birthdays.length,
        itemBuilder: (context, index) {
          final birthday = birthdays[index];
          final onEdit = this.onEdit;
          return BirthdayTile(
            birthday: birthday,
            today: today,
            onEdit: onEdit == null ? null : () => onEdit(birthday),
            onDelete: () => onDelete(birthday),
          );
        },
      ),
    );
  }
}

/// Estado vacío del listado de cumpleaños.
class EmptyBirthdayList extends StatelessWidget {
  const EmptyBirthdayList({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cake_outlined, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Todavía no hay cumpleaños guardados',
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega el primero con el formulario de arriba.',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
