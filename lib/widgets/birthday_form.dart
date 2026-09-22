import 'package:flutter/material.dart';

import '../models/birthday.dart';
import '../utils/birthday_dates.dart';

/// Formulario para registrar o editar un cumpleaños (nombre + fecha).
class BirthdayForm extends StatefulWidget {
  const BirthdayForm({
    super.key,
    required this.onSubmit,
    this.initialBirthday,
    this.submitLabel,
  });

  /// Se llama con los datos validados al pulsar "Guardar".
  final Future<void> Function(String name, DateTime birthDate) onSubmit;

  /// Si se indica, el formulario arranca precargado en modo edición.
  final Birthday? initialBirthday;

  /// Texto del botón; por defecto depende del modo (alta o edición).
  final String? submitLabel;

  @override
  State<BirthdayForm> createState() => _BirthdayFormState();
}

class _BirthdayFormState extends State<BirthdayForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;

  DateTime? _birthDate;
  bool _saving = false;

  bool get _isEditing => widget.initialBirthday != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.initialBirthday?.name ?? '',
    );
    _birthDate = widget.initialBirthday?.birthDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      locale: const Locale('es'),
      helpText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      return;
    }
    if (_birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona la fecha de nacimiento')),
      );
      return;
    }

    setState(() => _saving = true);
    await widget.onSubmit(_nameController.text.trim(), _birthDate!);
    if (!mounted) {
      return;
    }
    setState(() {
      _saving = false;
      if (!_isEditing) {
        _birthDate = null;
      }
    });
    if (!_isEditing) {
      _nameController.clear();
    }
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final defaultLabel = _isEditing
        ? 'Guardar cambios'
        : 'Guardar y programar aviso';
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Editar cumpleaños' : 'Nuevo cumpleaños',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  hintText: 'Ej.: María Fernanda Gómez',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Escribe el nombre de la persona';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickBirthDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Fecha de nacimiento',
                    prefixIcon: Icon(Icons.cake_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Selecciona una fecha'
                        : formatBirthDate(_birthDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: const Icon(Icons.alarm_add_outlined),
                label: Text(
                  _saving ? 'Guardando...' : widget.submitLabel ?? defaultLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
