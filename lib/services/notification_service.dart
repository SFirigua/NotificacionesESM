import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/birthday.dart';
import '../utils/birthday_dates.dart';

/// Servicio central de notificaciones locales.
///
/// Programa un aviso recurrente cada año en el día y mes del cumpleaños a las
/// 7:00 AM, usando un canal de máxima prioridad con sonido de alarma.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  /// OJO: en Android 8+ el sonido, la importancia y el bypass de No Molestar
  /// de un canal quedan bloqueados tras su creación. Al cambiar cualquiera se
  /// sube la versión del id para que Android cree un canal nuevo sin reinstalar.
  /// Historial:
  ///   v1 tono de alarma fuerte → v2 chime de cumpleaños →
  ///   v3 chime festivo + soporte de omisión de No Molestar.
  static const String _channelId = 'birthday_alarm_channel_v3';
  static const String _channelName = 'Cumpleaños';
  static const String _channelDescription =
      'Recordatorios anuales de cumpleaños a las 7:00 AM';

  /// Sonido en `android/app/src/main/res/raw/birthday_chime.wav`.
  /// Alternativa incluida: `gentle_chime` (arpegio suave).
  static const String _androidSound = 'birthday_chime';

  /// Sonido incluido en el bundle de iOS (arrástralo al target en Xcode).
  /// Alternativa incluida: `gentle_chime.wav`.
  static const String _iosSound = 'birthday_chime.wav';

  /// Id reservado para la notificación de prueba (solo desarrollo).
  static const int _testNotificationId = 999999;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool? _iosPermissionsGranted;
  bool _channelBypassesDnd = false;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  /// Inicializa el plugin, la base de zonas horarias y el canal de Android.
  Future<void> init() async {
    if (_initialized) {
      return;
    }

    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // Los permisos se piden desde la pantalla principal, no al iniciar.
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);

    await _createChannel();
    _initialized = true;
  }

  /// El plugin trabaja con `TZDateTime`: hay que fijar la zona horaria real.
  Future<void> _configureLocalTimeZone() async {
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (error) {
      debugPrint('No se pudo detectar la zona horaria del dispositivo: $error');
    }
  }

  /// Canal de máxima prioridad con uso de audio tipo alarma.
  ///
  /// `bypassDnd` solo se aplica si el usuario concedió el acceso a No Molestar;
  /// si no, Android lo ignora y el canal queda sin omisión (por eso existe
  /// [refreshDndChannel], que lo recrea cuando cambia el permiso).
  Future<void> _createChannel() async {
    final bypassDnd = await hasDndAccess();
    final channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound(_androidSound),
      enableVibration: true,
      bypassDnd: bypassDnd,
      audioAttributesUsage: AudioAttributesUsage.alarm,
    );
    await _android?.createNotificationChannel(channel);
    _channelBypassesDnd = bypassDnd;
  }

  /// Pide permisos de notificaciones (Android 13+) y de alarmas exactas
  /// (Android 12+). Devuelve `true` si se pueden mostrar notificaciones.
  Future<bool> requestPermissions() async {
    var granted = true;

    final android = _android;
    if (android != null) {
      granted = await android.requestNotificationsPermission() ?? true;
      final canScheduleExact =
          await android.canScheduleExactNotifications() ?? true;
      if (!canScheduleExact) {
        await android.requestExactAlarmsPermission();
      }
    }

    final ios = _ios;
    if (ios != null) {
      final result = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      _iosPermissionsGranted = result;
      granted = result ?? granted;
    }

    return granted;
  }

  /// Indica si la app puede publicar notificaciones ahora mismo.
  Future<bool> areNotificationsEnabled() async {
    final android = _android;
    if (android != null) {
      return await android.areNotificationsEnabled() ?? true;
    }
    return _iosPermissionsGranted ?? true;
  }

  /// Indica si el canal de avisos está activo (Android).
  ///
  /// Si el usuario lo desactiva a mano en Ajustes, Android le pone
  /// `Importance.none` y descarta las notificaciones **sin avisar a la app**.
  /// Si el canal no existe todavía se considera activo (se crea al arrancar).
  Future<bool> isChannelEnabled() async {
    final channels =
        await _android?.getNotificationChannels() ??
        const <AndroidNotificationChannel>[];
    return isChannelEnabledIn(channels, _channelId);
  }

  /// Lógica pura de [isChannelEnabled], expuesta para los tests.
  @visibleForTesting
  static bool isChannelEnabledIn(
    List<AndroidNotificationChannel> channels,
    String channelId,
  ) {
    for (final channel in channels) {
      if (channel.id == channelId) {
        return channel.importance != Importance.none;
      }
    }
    return true;
  }

  /// Abre los ajustes de notificaciones del sistema para esta app.
  Future<void> openNotificationSettings() async {
    await _plugin.openAppNotificationSettings();
  }

  /// Indica si la app puede saltarse el modo No Molestar.
  ///
  /// En Android depende del permiso "Acceso a No molestar"; en iOS siempre es
  /// `true` (allí el control es el nivel de interrupción de la notificación).
  Future<bool> hasDndAccess() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return true;
    }
    return await _android?.hasNotificationPolicyAccess() ?? true;
  }

  /// Abre los ajustes del sistema para conceder acceso a No Molestar.
  Future<void> requestDndAccess() async {
    await _android?.requestNotificationPolicyAccess();
  }

  /// Recrea el canal si el acceso a No Molestar cambió.
  ///
  /// El canal es inmutable, así que para aplicar `bypassDnd` hay que borrarlo y
  /// volver a crearlo (el usuario pierde la personalización de ese canal).
  Future<void> refreshDndChannel() async {
    final bypassDnd = await hasDndAccess();
    if (bypassDnd == _channelBypassesDnd) {
      return;
    }
    await _android?.deleteNotificationChannel(channelId: _channelId);
    await _createChannel();
  }

  /// Programa (o reprograma) el aviso anual de [birthday].
  ///
  /// El id de la notificación es el id del registro en SQLite, así que
  /// reprogramar o cancelar es directo.
  Future<void> scheduleBirthday(Birthday birthday) async {
    final id = birthday.id;
    if (id == null) {
      return;
    }

    final next = nextBirthdayOccurrence(birthday.birthDate);
    final age = ageOnDate(birthday.birthDate, next);

    var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    final canScheduleExact = await _canScheduleExact();
    if (!canScheduleExact) {
      // Sin permiso de alarmas exactas el aviso igualmente llega, con un
      // pequeño margen que decide el sistema (Doze).
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await _plugin.zonedSchedule(
      id: id,
      title: '¡Hoy cumple años ${birthday.name}!',
      body:
          'Hoy ${birthday.name} está cumpliendo $age años. ¡No olvides felicitarle!',
      scheduledDate: tz.TZDateTime.from(next, tz.local),
      notificationDetails: _details(),
      androidScheduleMode: scheduleMode,
      // Recurrencia anual: vuelve a coincidir mes + día + hora cada año.
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
      payload: 'birthday:$id',
    );
  }

  /// Cancela los avisos pendientes y los reprograma con la edad actualizada.
  ///
  /// Llámalo al abrir la app (el texto con la edad cambia cada año) y después
  /// de conceder permisos.
  Future<void> rescheduleAll(Iterable<Birthday> birthdays) async {
    await _plugin.cancelAllPendingNotifications();
    for (final birthday in birthdays) {
      await scheduleBirthday(birthday);
    }
  }

  /// Cancela el aviso anual de un cumpleaños.
  Future<void> cancelBirthday(int id) => _plugin.cancel(id: id);

  /// (Desarrollo) Programa una notificación de prueba en [seconds] segundos
  /// con el mismo canal, sonido y formato que los recordatorios reales.
  ///
  /// Devuelve un mensaje listo para mostrar en pantalla.
  Future<String> scheduleTestNotification({int seconds = 5}) async {
    if (!await _canScheduleExact()) {
      await showTestNotification();
      return 'Sin permiso de alarmas exactas: se mostró la notificación ahora mismo.';
    }
    await _plugin.zonedSchedule(
      id: _testNotificationId,
      title: '¡Hoy cumple años Ana!',
      body: 'Hoy Ana está cumpliendo 30 años. ¡No olvides felicitarle!',
      scheduledDate: tz.TZDateTime.now(tz.local)
          .add(Duration(seconds: seconds)),
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'test',
    );
    return 'Aviso de prueba en $seconds segundos. Bloquea el teléfono para verlo como un recordatorio real.';
  }

  /// (Desarrollo) Muestra la notificación de prueba inmediatamente.
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: _testNotificationId,
      title: '¡Hoy cumple años Ana!',
      body: 'Hoy Ana está cumpliendo 30 años. ¡No olvides felicitarle!',
      notificationDetails: _details(),
    );
  }

  /// Avisos pendientes de disparo (útil para verificar en desarrollo).
  Future<List<PendingNotificationRequest>> pendingRequests() =>
      _plugin.pendingNotificationRequests();

  Future<bool> _canScheduleExact() async =>
      await _android?.canScheduleExactNotifications() ?? true;

  NotificationDetails _details() {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,
        ticker: 'Recordatorio de cumpleaños',
        playSound: true,
        sound: const RawResourceAndroidNotificationSound(_androidSound),
        enableVibration: true,
        visibility: NotificationVisibility.public,
        audioAttributesUsage: AudioAttributesUsage.alarm,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: _iosSound,
        // Puede atravesar los modos de concentración si el usuario lo permite
        // (requiere la capability "Time Sensitive Notifications" en Xcode).
        // Las alertas críticas (que ignoran el switch de silencio) necesitan
        // aprobación de Apple y no se usan.
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }
}
