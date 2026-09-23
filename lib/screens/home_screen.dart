import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../data/birthday_database.dart';
import '../models/birthday.dart';
import '../services/battery_optimization_service.dart';
import '../services/notification_service.dart';
import '../utils/birthday_dates.dart';
import '../widgets/birthday_form.dart';
import '../widgets/birthday_list.dart';

/// Pantalla principal: formulario para agregar/editar y listado de cumpleaños.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialBirthdays});

  /// Cumpleaños ya cargados por [AppBootstrap]; si se indican, no se muestra
  /// el spinner inicial.
  final List<Birthday>? initialBirthdays;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Birthday> _birthdays = const [];
  bool _loading = true;
  bool _notificationsDisabled = false;
  bool _channelDisabled = false;
  bool _exactAlarmsMissing = false;
  bool _dndAccessMissing = false;
  bool _batteryOptimized = false;

  /// Cumpleaños de hoy cuyo aviso no está visible en el sistema.
  List<Birthday> _recoveryBirthdays = const [];

  /// Ids descartados por el usuario en esta sesión (no volver a mostrarlos).
  final Set<int> _dismissedRecoveryIds = <int>{};

  /// Carga inicial de la base de datos, para no reprogramar con la lista vacía.
  late final Future<void> _initialLoad;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final initial = widget.initialBirthdays;
    if (initial != null) {
      _birthdays = initial;
      _loading = false;
      _initialLoad = Future.value();
    } else {
      _initialLoad = _load();
    }
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
      _handleResume();
    }
  }

  /// Al volver a la app: huso horario, permisos, aviso de recuperación y
  /// ahorro de batería pueden haber cambiado mientras estaba en segundo plano.
  Future<void> _handleResume() async {
    final timeZoneChanged = await NotificationService.instance
        .refreshLocalTimeZone();
    if (!mounted) {
      return;
    }
    if (timeZoneChanged) {
      // El huso se guarda al programar: hay que reprogramar con el nuevo.
      await NotificationService.instance.rescheduleAll(_birthdays);
    }
    await _refreshPermissionState();
    await _checkBirthdayRecovery();
    await _refreshBatteryState();
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
    await _checkBirthdayRecovery();
  }

  Future<void> _requestPermissions() async {
    final granted = await NotificationService.instance.requestPermissions();
    if (!mounted) {
      return;
    }
    // Espera la carga inicial: reprogramar con una lista todavía vacía
    // dejaría los recordatorios anteriores cancelados.
    await _initialLoad;
    if (!mounted) {
      return;
    }
    if (granted) {
      // Ya con los permisos definitivos, se reprograman los avisos.
      await NotificationService.instance.rescheduleAll(_birthdays);
    }
    await _refreshPermissionState();
    await _checkBirthdayRecovery();
    await _refreshBatteryState();
  }

  /// Revisa notificaciones de la app, canal de avisos, alarmas exactas y
  /// acceso a No Molestar.
  ///
  /// El canal se consulta aparte porque Android descarta las notificaciones si
  /// el usuario lo desactiva a mano y la app no se entera de otra forma.
  Future<void> _refreshPermissionState() async {
    final enabled = await NotificationService.instance
        .areNotificationsEnabled();
    final channelEnabled = await NotificationService.instance
        .isChannelEnabled();
    final exactAlarmsGranted = await NotificationService.instance
        .canScheduleExactAlarms();
    final dndGranted = await NotificationService.instance.hasDndAccess();
    if (!mounted) {
      return;
    }
    final shouldRecreateChannel = dndGranted && _dndAccessMissing;
    // Si el permiso de alarmas exactas se concedió después de programar, los
    // avisos pendientes quedaron en modo inexacto: hay que reprogramarlos.
    final shouldUpgradeToExact = exactAlarmsGranted && _exactAlarmsMissing;
    setState(() {
      _notificationsDisabled = !enabled;
      _channelDisabled = enabled && !channelEnabled;
      _exactAlarmsMissing = enabled && channelEnabled && !exactAlarmsGranted;
      _dndAccessMissing = enabled && channelEnabled && !dndGranted;
    });
    if (shouldRecreateChannel) {
      // El canal es inmutable: se recrea para aplicar la omisión de No Molestar.
      await NotificationService.instance.refreshDndChannel();
    }
    if (shouldUpgradeToExact) {
      await NotificationService.instance.rescheduleAll(_birthdays);
    }
  }

  Future<void> _grantDndAccess() async {
    await NotificationService.instance.requestDndAccess();
  }

  Future<void> _grantExactAlarms() async {
    await NotificationService.instance.requestExactAlarmsPermission();
  }

  /// Muestra el aviso de recuperación si hoy es el cumpleaños, ya pasaron las
  /// 7:00 AM y la notificación no está visible en el sistema (no sonó, se
  /// retrasó o el usuario la descartó).
  Future<void> _checkBirthdayRecovery() async {
    final now = DateTime.now();
    final candidates = birthdaysNeedingRecovery(
      _birthdays,
      now: now,
      activeNotificationIds: const {},
      dismissedIds: _dismissedRecoveryIds,
    );
    if (candidates.isEmpty) {
      if (mounted) {
        setState(() => _recoveryBirthdays = const []);
      }
      return;
    }

    final activeIds = await NotificationService.instance
        .activeNotificationIds();
    if (!mounted) {
      return;
    }
    setState(() {
      _recoveryBirthdays = candidates
          .where((birthday) => !activeIds.contains(birthday.id))
          .toList();
    });
  }

  void _dismissRecovery(Birthday birthday) {
    final id = birthday.id;
    if (id != null) {
      _dismissedRecoveryIds.add(id);
    }
    setState(() {
      _recoveryBirthdays = _recoveryBirthdays
          .where((item) => item.id != id)
          .toList();
    });
  }

  Future<void> _refreshBatteryState() async {
    final optimized = await BatteryOptimizationService.instance.isOptimized();
    if (!mounted) {
      return;
    }
    setState(() => _batteryOptimized = optimized);
  }

  /// Explica cómo excluir la app del ahorro de batería del fabricante.
  Future<void> _openBatteryGuide() async {
    final openSettings = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Evita que Android retrase tus avisos'),
        content: const Text(
          'Algunos fabricantes (Xiaomi, Samsung, Huawei, Oppo, Vivo…) congelan '
          'las apps en segundo plano y el recordatorio de las 7:00 AM puede no '
          'sonar.\n\nExcluye "Cumpleaños" del ahorro de batería; en algunos '
          'modelos también hay que activar el "inicio automático".\n\n'
          'Más información: dontkillmyapp.com',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
    if (openSettings == true) {
      await BatteryOptimizationService.instance.openSettings();
    }
  }

  /// Guarda el aviso y devuelve `false` si no se pudo programar.
  Future<bool> _schedule(Birthday birthday) async {
    try {
      await NotificationService.instance.scheduleBirthday(birthday);
      return true;
    } catch (error) {
      debugPrint('No se pudo programar el aviso de ${birthday.name}: $error');
      return false;
    }
  }

  Future<void> _addBirthday(String name, DateTime birthDate) async {
    final saved = await BirthdayDatabase.instance.insert(
      Birthday(name: name, birthDate: birthDate),
    );
    final scheduled = await _schedule(saved);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Aviso de ${saved.name} programado a las 7:00 AM del '
                    '${formatDayAndMonth(nextBirthdayOccurrence(saved.birthDate))}'
              : 'Se guardó a ${saved.name}, pero no se pudo programar el aviso. '
                    'Revisa los permisos de notificaciones.',
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
    final scheduled = await _schedule(updated);
    await _load();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Aviso de ${updated.name} actualizado a las 7:00 AM del '
                    '${formatDayAndMonth(nextBirthdayOccurrence(updated.birthDate))}'
              : 'Se guardó a ${updated.name}, pero no se pudo reprogramar el '
                    'aviso. Revisa los permisos de notificaciones.',
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
          if (_batteryOptimized)
            IconButton(
              tooltip: 'Ahorro de batería',
              icon: const Icon(Icons.battery_alert_outlined),
              onPressed: _openBatteryGuide,
            ),
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
                  for (final birthday in _recoveryBirthdays)
                    SliverToBoxAdapter(
                      child: _buildRecoveryBanner(context, birthday),
                    ),
                  if (_notificationsDisabled)
                    SliverToBoxAdapter(child: _buildPermissionBanner(context))
                  else if (_channelDisabled)
                    SliverToBoxAdapter(child: _buildChannelBanner(context))
                  else if (_exactAlarmsMissing)
                    SliverToBoxAdapter(child: _buildExactAlarmsBanner(context))
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

  /// Celebración del día: la notificación de las 7:00 AM no está visible.
  Widget _buildRecoveryBanner(BuildContext context, Birthday birthday) {
    final colors = Theme.of(context).colorScheme;
    final age = ageOnDate(birthday.birthDate, DateTime.now());
    return MaterialBanner(
      backgroundColor: colors.primaryContainer,
      leading: Icon(
        Icons.celebration_outlined,
        color: colors.onPrimaryContainer,
      ),
      content: Text(
        '¡Hoy cumple años ${birthday.name}! Está cumpliendo $age años. '
        '¡No olvides felicitarle!',
        style: TextStyle(color: colors.onPrimaryContainer),
      ),
      actions: [
        TextButton(
          onPressed: () => _dismissRecovery(birthday),
          child: Text(
            'Entendido',
            style: TextStyle(color: colors.onPrimaryContainer),
          ),
        ),
      ],
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

  /// Android 12+: sin este permiso el aviso puede retrasarse (Doze).
  Widget _buildExactAlarmsBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return MaterialBanner(
      backgroundColor: colors.tertiaryContainer,
      content: Text(
        'Android puede retrasar el aviso de las 7:00 AM. Concede "Alarmas y '
        'recordatorios" para que suene a la hora exacta.',
        style: TextStyle(color: colors.onTertiaryContainer),
      ),
      actions: [
        TextButton(
          onPressed: _grantExactAlarms,
          child: Text(
            'Permitir',
            style: TextStyle(color: colors.onTertiaryContainer),
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
