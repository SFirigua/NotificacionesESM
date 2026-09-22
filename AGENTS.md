# AGENTS.md

Guía para agentes de IA y desarrolladores que editen este repositorio.

## Qué es este proyecto

App Flutter **solo Android/iOS** de recordatorios locales de cumpleaños (sin backend, sin red):

- Persistencia: `sqflite` (tabla `birthdays`, fecha en ISO8601).
- Notificaciones: `flutter_local_notifications` + `timezone` (avisos anuales a las 7:00 AM).
- UI: Material 3, textos en español; identificadores de código en inglés.

## Comandos obligatorios

| Objetivo | Comando |
|---|---|
| Instalar dependencias | `flutter pub get` |
| Análisis estático (debe dar 0 issues) | `flutter analyze` |
| Tests (deben pasar todos) | `flutter test` |
| Formatear | `dart format .` |
| Compilar Android | `flutter build apk --debug` (o `--release`) |
| Ejecutar en dispositivo | `flutter devices` y luego `flutter run -d <device_id>` |
| Revisión de deuda | `flutter pub outdated` (ver `docs/deuda-tecnica.md`) |

## Definición de "terminado"

1. `flutter analyze` sin issues.
2. `flutter test` en verde (si tocas lógica de fechas, añade/ajusta tests).
3. `flutter build apk --debug` compila.
4. Si tocas notificaciones o UI: probar en dispositivo con el botón de campana (solo debug) y el flujo crear/eliminar.
5. Si resuelves o detectas deuda, actualiza `docs/deuda-tecnica.md`.

## Estructura

```
lib/
├── main.dart                  # init de intl + notificaciones + rescheduleAll
├── models/birthday.dart       # entidad + toMap/fromMap
├── data/birthday_database.dart# sqflite (CRUD)
├── services/notification_service.dart
├── utils/birthday_dates.dart  # 7:00 AM, edad, días restantes, formato es
├── screens/home_screen.dart
└── widgets/birthday_form.dart, birthday_tile.dart, birthday_list.dart
assets/icon/                   # fuentes de iconos (flutter_launcher_icons)
android/                       # manifest, gradle, res/raw (sonidos)
ios/                           # AppDelegate.swift, Runner/*.wav
test/birthday_test.dart        # unitarios de fechas
test/widget_test.dart          # formulario, lista y estado vacío
docs/deuda-tecnica.md
```

## Restricciones no negociables

### Plataformas

- Este repo es **solo móvil**: no generar ni restaurar `windows/`, `web/`, `linux/`, `macos/`. Si hay que regenerar el esqueleto: `flutter create . --platforms=android,ios --project-name notificaciones_esm`.
- No editar `ios/Runner.xcodeproj/project.pbxproj` a mano (los archivos nuevos de iOS se agregan desde Xcode).

### Android nativo

- No quitar del `AndroidManifest.xml`: permisos `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `ACCESS_NOTIFICATION_POLICY`, `RECEIVE_BOOT_COMPLETED` ni los receivers `ScheduledNotificationReceiver` / `ScheduledNotificationBootReceiver`.
- Mantener en `android/app/build.gradle.kts`: `isCoreLibraryDesugaringEnabled = true` y `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` (requisito del plugin de notificaciones).
- Java/Kotlin 17. No añadir `USE_EXACT_ALARM` (política de Google Play).
- Sonidos en `android/app/src/main/res/raw/`: nombres en minúsculas `[a-z0-9_]`; se referencian **sin extensión**. Al añadir un sonido, incluirlo en `res/raw/keep.xml`.
- No tocar `android.builtInKotlin` / `android.newDsl` sin leer antes la sección 2.1 de `docs/deuda-tecnica.md`.

### iOS

- Sonidos nuevos: copiar el `.wav` a `ios/Runner/` y **documentar/verificar** que se agrega al target *Runner* en Xcode (Copy Bundle Resources). En código se referencian con extensión (`birthday_chime.wav`).
- `InterruptionLevel.timeSensitive` requiere la capability *Time Sensitive Notifications* en Xcode. Las alertas críticas (ignoran el switch de silencio) necesitan entitlement de Apple: no usarlas.
- No se requieren claves de permisos en `Info.plist` para notificaciones locales.

### Notificaciones (crítico)

- **Canales Android inmutables**: cualquier cambio de sonido, importancia, vibración o `bypassDnd` implica **subir la versión de `_channelId`** (`birthday_alarm_channel_vN` → `vN+1`) y anotarlo en el historial del archivo, o recrear el canal como hace `refreshDndChannel()`. Solo aplica a Android.
- Referencias de sonido: `_androidSound` sin extensión (`birthday_chime`); `_iosSound` con extensión (`birthday_chime.wav`).
- `bypassDnd` solo funciona con el permiso `ACCESS_NOTIFICATION_POLICY` concedido; si el usuario lo concede después, `refreshDndChannel()` recrea el canal. No eliminar ese flujo ni los banners de permiso de `home_screen.dart`.
- Android **no avisa a la app** cuando el usuario desactiva el canal: mantener la comprobación `isChannelEnabled()` (`getNotificationChannels` + `Importance.none`) y su banner en `home_screen.dart`.
- `audioAttributesUsage: AudioAttributesUsage.alarm` es intencional (volumen de alarma matinal). Si se cambia, subir el canal.
- El id de la notificación es el id del registro en SQLite: no cambiarlo.
- Mantener el modo `exactAllowWhileIdle` con **fallback a inexacto** cuando no hay permiso de alarmas exactas.
- Mantener `rescheduleAll()` en el arranque (`main.dart`) y tras conceder permisos (`home_screen.dart`): es lo que actualiza la edad del mensaje cada año.
- El botón de prueba de notificación debe quedar detrás de `kDebugMode`.
- `main.dart` debe inicializar `WidgetsFlutterBinding`, `initializeDateFormatting('es')` y `NotificationService.instance.init()` antes de `runApp`.

### Datos

- No cambiar el esquema de la tabla sin migración (`onUpgrade`) y sin actualizar `Birthday.toMap/fromMap`.
- `birth_date` se guarda en ISO8601; no cambiar el formato sin migrar datos.

### Dependencias

- No agregar paquetes sin justificar; preferir lo existente.
- Al actualizar `flutter_local_notifications`, verificar la API vigente (v22 usa parámetros nombrados: `initialize(settings: …)`, `zonedSchedule(id: …)`) y las reglas de canales.
- No editar `pubspec.lock` a mano.

## Convenciones de código

- Identificadores en inglés; textos de UI y comentarios en español.
- Comentarios solo para explicar el "por qué" (reglas de plataforma/negocio), no el "qué".
- Usar `flutter_lints` (`analysis_options.yaml`); no desactivar reglas sin justificar.
- UI: Material 3, colores desde `ColorScheme.fromSeed`; evitar colores sueltos.
- Errores async: `try/catch` en integraciones de plataforma; logs con `debugPrint` (nunca `print`).
- Para lógica de fechas reutilizar `lib/utils/birthday_dates.dart` (`nextBirthdayOccurrence`, `ageOnDate`, `daysUntil`); no duplicar cálculos.

## Testing

- Tests en `test/`, con **fechas fijas** (nunca depender de `DateTime.now()` real). `BirthdayTile` y `BirthdaySliverList` aceptan `today` para inyectarla.
- Toda regla nueva de edad/programación debe tener test unitario.
- Los widgets de UI (formulario, lista, estado vacío) se prueban en `test/widget_test.dart`; los cambios de layout deben poder verificarse en pantalla pequeña con el teclado abierto (ver bug histórico de overflow en `docs/deuda-tecnica.md`).

## Seguridad y repositorio

- Nunca commitear secretos (keystore, `key.properties`, tokens). Revisar `.gitignore` antes de agregar archivos.
- No ejecutar `git commit`/`git push` ni crear PRs salvo pedido explícito del usuario.
