import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/birthday_database.dart';
import '../models/birthday.dart';
import '../services/notification_service.dart';
import '../utils/birthday_dates.dart';
import '../widgets/birthday_form.dart';
import '../widgets/birthday_list.dart';

/// Pantalla principal: formulario para agregar/editar y listado de cumpleaños.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Birthday> _birthdays = const [];
  bool _loading = true;
  bool _notificationsDisabled = false;
  bool _channelDisabled = false;
  bool _dndAccessMissing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _requestPermissions());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPermissionState();
    }
  }

  Future<void> _load() async {
    final birthdays = await BirthdayDatabase.instance.getAll();
    if (!mounted) {
      return;
    }
    setState(() {
      _birthdays = birthdays;
      _loading = false;
    });
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (!mounted) {
      return;
    }
    if (granted) {
      // Ya con los permisos definitivos, se reprograman los avisos.
      await NotificationService.instance.rescheduleAll(_birthdays);
    }
    await _refreshPermissionState();
  }

  /// Revisa notificaciones de la app, canal de avisos y acceso a No Molestar.
  ///
  /// El canal se consulta aparte porque Android descarta las notificaciones si
  /// el usuario lo desactiva a mano y la app no se entera de otra forma.
  Future<void> _refreshPermissionState() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    final channelEnabled = await NotificationService.instance
        .isChannelEnabled();
    final dndGranted = await NotificationService.instance.hasDndAccess();
    if (!mounted) {
      return;
    }
    final shouldRecreateChannel = dndGranted && _dndAccessMissing;
    setState(() {
      _notificationsDisabled = !enabled;
      _channelDisabled = enabled && !channelEnabled;
      _dndAccessMissing = enabled && channelEnabled && !dndGranted;
    });
    if (shouldRecreateChannel) {
      // El canal es inmutable: se recrea para aplicar la omisión de No Molestar.
      await NotificationService.instance.refreshDndChannel();
    }
  }

  Future<void> _grantDndAccess() async {
    await NotificationService.instance.requestDndAccess();
  }

  Future<void> _addBirthday(String name, DateTime birthDate) async {
    final saved = await BirthdayDatabase.instance.insert(
      Birthday(name: name, birthDate: birthDate),
    );
    await NotificationService.instance.scheduleBirthday(saved);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aviso de ${saved.name} programado a las 7:00 AM del '
          '${formatDayAndMonth(nextBirthdayOccurrence(saved.birthDate))}',
        ),
      ),
    );
  }

  Future<void> _editBirthday(Birthday birthday) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: BirthdayForm(
          initialBirthday: birthday,
          onSubmit: (name, birthDate) async {
            await _updateBirthday(birthday, name, birthDate);
            if (sheetContext.mounted) {
              Navigator.pop(sheetContext);
            }
          },
        ),
      ),
    );
  }

  Future<void> _updateBirthday(
    Birthday birthday,
    String name,
    DateTime birthDate,
  ) async {
    final updated = birthday.copyWith(name: name, birthDate: birthDate);
    await BirthdayDatabase.instance.update(updated);
    // Reprograma con el mismo id: reemplaza el aviso anterior.
    await NotificationService.instance.scheduleBirthday(updated);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Aviso de ${updated.name} actualizado a las 7:00 AM del '
          '${formatDayAndMonth(nextBirthdayOccurrence(updated.birthDate))}',
        ),
      ),
    );
  }

  Future<void> _deleteBirthday(Birthday birthday) async {
    final id = birthday.id;
    if (id == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar cumpleaños'),
        content: Text(
          '¿Quieres eliminar a ${birthday.name} y su recordatorio anual?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await BirthdayDatabase.instance.delete(id);
    await NotificationService.instance.cancelBirthday(id);
    await _load();
  }

  /// Botón de desarrollo: muestra cómo se ve y suena el recordatorio real.
  Future<void> _testNotification() async {
    final message = await NotificationService.instance
        .scheduleTestNotification();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

    final pending = await NotificationService.instance.pendingRequests();
    debugPrint('Avisos pendientes: ${pending.length}');
    for (final request in pending) {
      debugPrint('  id=${request.id} | ${request.title} | ${request.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumpleaños'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Probar notificación',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: _testNotification,
            ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                // Todo scrollea junto (formulario incluido) para que el teclado
                // no desborde el layout en pantallas pequeñas.
                slivers: [
                  if (_notificationsDisabled)
                    SliverToBoxAdapter(child: _buildPermissionBanner(context))
                  else if (_channelDisabled)
                    SliverToBoxAdapter(child: _buildChannelBanner(context))
                  else if (_dndAccessMissing)
                    SliverToBoxAdapter(child: _buildDndBanner(context)),
                  SliverToBoxAdapter(
                    child: BirthdayForm(onSubmit: _addBirthday),
                  ),
                  if (_birthdays.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyBirthdayList(),
                    )
                  else
                    BirthdaySliverList(
                      birthdays: _birthdays,
                      onDelete: _deleteBirthday,
                      onEdit: _editBirthday,
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildPermissionBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      content: Text(
        'Las notificaciones están desactivadas. Actívalas para recibir los '
        'avisos de cumpleaños.',
        style: TextStyle(color: colors.onErrorContainer),
      ),
      actions: [
        TextButton(
          onPressed: NotificationService.instance.openNotificationSettings,
          child: Text(
            'Abrir ajustes',
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ],
    );
  }

  /// Android: el usuario desactivó el canal "Cumpleaños" en Ajustes.
  Widget _buildChannelBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: colors.errorContainer,
      content: Text(
        'El canal de avisos de cumpleaños está desactivado. Actívalo para '
        'volver a recibir los recordatorios.',
        style: TextStyle(color: colors.onErrorContainer),
      ),
      actions: [
        TextButton(
          onPressed: NotificationService.instance.openNotificationSettings,
          child: Text(
            'Abrir ajustes',
            style: TextStyle(color: colors.onErrorContainer),
          ),
        ),
      ],
    );
  }

  /// Android: para sonar con No Molestar activo hace falta este permiso.
  Widget _buildDndBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: colors.tertiaryContainer,
      content: Text(
        'Para que el aviso suene aunque el teléfono esté en No Molestar, '
        'concede el acceso a "No molestar".',
        style: TextStyle(color: colors.onTertiaryContainer),
      ),
      actions: [
        TextButton(
          onPressed: _grantDndAccess,
          child: Text(
            'Permitir',
            style: TextStyle(color: colors.onTertiaryContainer),
          ),
        ),
      ],
    );
  }
}
