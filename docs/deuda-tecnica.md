# Deuda técnica y pendientes — NotificacionesESM

Revisiones: **2026-09-21** (inicial y tras el pase a producción) y **2026-09-22** (incidente de aviso perdido en release) con **Flutter 3.47.0 stable / Dart 3.13.0** (Windows).

## Estado actual (verificado)

| Comprobación | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | 0 issues |
| Tests | `flutter test` | 25/25 en verde (17 unitarios + 8 de widget) |
| Build Android debug | `flutter build apk --debug` | OK |
| Build Android release | `flutter build apk --release` | OK (firma debug de respaldo; ver P0-1) |
| Dependencias directas | `flutter pub outdated` | Todas al día |

## Incidente 2026-09-22: aviso olvidado en un cumpleaños (release)

Un aviso programado el día anterior no sonó a las 7:00 AM en un teléfono Android 11. Revisión del APK release: permisos (`POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `ACCESS_NOTIFICATION_POLICY`, `RECEIVE_BOOT_COMPLETED`), receivers, recurso de sonido e iconos presentes; R8 no eliminó campos ni clases que el plugin (`flutter_local_notifications` + Gson) necesita en `ScheduledNotificationReceiver`/`ScheduledNotificationBootReceiver`. El cálculo de fecha programada era correcto.

Causas corregidas en la app:

- **Carrera en `_requestPermissions`**: podía llamar a `rescheduleAll` con `_birthdays` aún vacío. Ahora espera `_initialLoad` (`home_screen.dart`).
- **`cancelAllPendingNotifications()` al arrancar**: abría una ventana en la que un fallo (o la lista vacía) dejaba la app sin ningún recordatorio. Se eliminó: al programar con el mismo id, el plugin reemplaza el aviso anterior (`notification_service.dart`).
- **Errores de programación silenciosos**: ahora se registran y se muestran en un SnackBar (`_schedule` en `home_screen.dart`, `try/catch` en `app_bootstrap.dart`).
- **Banner de alarmas exactas (Android 12+)**: si el usuario no concede "Alarmas y recordatorios", el aviso cae a `inexactAllowWhileIdle` y Doze puede retrasarlo; el banner lo avisa y al concederlo se reprograman los avisos para que pasen a exactos.

Si el fallo se repite, revisar en el teléfono (no es verificable desde el repo):

```powershell
adb shell getprop ro.build.version.release        # versión de Android
adb shell cmd appops get com.esm.notificaciones_esm SCHEDULE_EXACT_ALARM
adb shell dumpsys deviceidle whitelist | findstr notificaciones
adb shell dumpsys alarm | findstr /i notificaciones   # alarmas pendientes
```

Un `force-stop`, el "ahorro de batería agresivo" de algunos fabricantes o abrir la app después de las 7:00 AM (reprograma al año siguiente) cancelan el aviso pendiente y explican un aviso que nunca aparece.

## Arranque y UX (2026-09-22)

La app mostraba la pantalla en negro entre 10 y 25 s al abrir. Causa: `main()` hacía todo el trabajo (locale, notificaciones, BD, `rescheduleAll`) antes de `runApp`, y en modo oscuro el tema nativo usaba `?android:colorBackground` (negro) mientras tanto. Correcciones:

- **`main.dart` ya solo hace `ensureInitialized()` + `runApp()`**; el trabajo pesado se movió a `lib/screens/app_bootstrap.dart`, que muestra un splash de marca (`SplashScreen`) y pasa a `HomeScreen` cuando todo está listo (con pantalla de error y reintento si algo falla).
- **Splash nativo en color de marca**: `@color/splash_background` (#C8145A) en `launch_background.xml` (drawable y drawable-v21) y en `NormalTheme` de `values`/`values-night`; ya no se ve negro en modo oscuro. El hex debe coincidir con `kSplashColor`.
- `HomeScreen` recibe `initialBirthdays` para no volver a mostrar spinner al terminar el bootstrap.

Nota: los APK **debug** (JIT, sin AOT) tardan mucho más en mostrar el primer frame que los release; el splash de marca ahora cubre ese tiempo.

## Pulido UX y robustez (2026-09-22, segunda tanda)

- **Aviso de recuperación**: si se abre la app el día de un cumpleaños después de las 7:00 AM y la notificación no está visible (`getActiveNotifications()`), `HomeScreen` muestra un banner de celebración descartable (por sesión). La lógica pura vive en `birthdaysNeedingRecovery()` (`lib/utils/birthday_dates.dart`) y tiene tests.
- **Guía de ahorro de batería**: icono en la AppBar cuando Android todavía puede congelar la app (`PowerManager.isIgnoringBatteryOptimizations` vía el canal `notificaciones_esm/battery` en `MainActivity.kt`). Abre un diálogo con la explicación (Xiaomi/Samsung/Huawei/Oppo/Vivo, dontkillmyapp.com) y un botón a los ajustes del sistema. Sin dependencias nuevas.
- **Cambio de huso horario**: al reanudar la app (`AppLifecycleState.resumed`) se compara `FlutterTimezone.getLocalTimezone()` con el último huso detectado; si cambió, se actualiza `tz.local` y se reprograman los avisos (`refreshLocalTimeZone()` + `rescheduleAll()`).


## Cambios aplicados en el pase a producción (2026-09-21)

- **Sonido festivo**: `birthday_chime.wav` es ahora la melodía completa de *Feliz cumpleaños* (dominio público) estilo caja de música con acorde final; alternativa suave: `gentle_chime.wav`. Generados a 44,1 kHz/16 bits.
- **Canal Android v3**: `birthday_alarm_channel_v3` (Importance.max, Priority.high, `AudioAttributesUsage.alarm`).
- **Omisión de No Molestar (Android)**: permiso `ACCESS_NOTIFICATION_POLICY`, `bypassDnd` en el canal cuando el usuario concede acceso, y `refreshDndChannel()` que recrea el canal (es inmutable) al detectar el cambio de permiso. La app muestra un banner con acción "Permitir".
- **iOS**: `interruptionLevel: InterruptionLevel.timeSensitive` en los detalles de la notificación.
- **Nombre visible**: "Cumpleaños" en `AndroidManifest.xml` e `Info.plist`.
- **Iconos**: generados con `flutter_launcher_icons` (adaptive en Android) a partir de `assets/icon/`.
- **Firma release**: `android/app/build.gradle.kts` lee `key.properties` (ignorado en git) y cae a firma debug si no existe. Plantilla en `android/key.properties.example`.
- **Tests de widget** (`test/widget_test.dart`): validación del formulario, selección de fecha, modo edición, renderizado de lista y estado vacío.
- **Edición de cumpleaños**: toque en la fila o icono de lápiz abre el formulario precargado; al guardar actualiza SQLite y reprograma la notificación con el mismo id.
- **Detección de canal desactivado**: `isChannelEnabled()` consulta `getNotificationChannels()` (Android) y el HomeScreen muestra un banner con acceso a Ajustes si el usuario desactivó el canal (Android descarta esas notificaciones sin avisar a la app).

## Cómo repetir la revisión

```powershell
flutter --version
flutter pub outdated
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
flutter run -d <device_id>   # validación manual de notificaciones (botón campana, solo debug)
```

---

## 1. Pendientes bloqueantes antes de publicar (P0)

| # | Pendiente | Estado / detalle |
|---|---|---|
| 1 | **Keystore de release** | ⏳ Configuración lista, falta crear el keystore: copiar `android/key.properties.example` a `android/key.properties`, generar el `.jks` con `keytool` (ver [Build and release an Android app](https://docs.flutter.dev/deployment/android)) y compilar `--release`. |
| 2 | **Nombre visible** | ✅ "Cumpleaños" en Android e iOS. |
| 3 | **Iconos** | ✅ Generados (Android adaptativo + iOS). Rehacer con `dart run flutter_launcher_icons` si cambia `assets/icon/`. |
| 4 | **Validación en iOS** | ⏳ Manual en un Mac: compilar, arrastrar `birthday_chime.wav` y `gentle_chime.wav` a *Runner → Copy Bundle Resources*, añadir la capability **Time Sensitive Notifications** y probar sonido + No Molestar. |
| 5 | **Política Google Play** | ⏳ Al publicar, justificar `SCHEDULE_EXACT_ALARM` en la ficha. No usar `USE_EXACT_ALARM` (reservado a reloj/alarma). |

## 2. Sonido y No Molestar: qué se puede y qué no

| Plataforma | Mecanismo implementado | Límite real |
|---|---|---|
| Android | Canal con `Importance.max`, `Priority.high`, sonido de alarma y `AudioAttributesUsage.alarm` (usa el volumen de alarmas, independiente del de notificaciones en la mayoría de dispositivos) | El modo "No molestar" solo se omite si el usuario concede **Acceso a No molestar** (`ACCESS_NOTIFICATION_POLICY`). El switch de silencio/vibración no impide el stream de alarmas. |
| iOS | `InterruptionLevel.timeSensitive` | Requiere activar la capability **Time Sensitive Notifications** en Xcode. Para ignorar el switch físico de silencio hacen falta **alertas críticas**, que necesitan entitlement aprobado por Apple ([solicitud](https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/)); no se implementa por defecto. |

Notas:

- Si el usuario concede el acceso a No Molestar **después** de crear el canal, `refreshDndChannel()` lo borra y recrea para aplicar `bypassDnd` (el canal es inmutable; se pierde la personalización de ese canal).
- El canal v3 aparece nuevo en Ajustes; el usuario puede cambiar el sonido manualmente en cualquier momento (Ajustes → Apps → Cumpleaños → Notificaciones → canal).
- En iOS el nivel `timeSensitive` solo surte efecto si el usuario permite "Notificaciones con prioridad" en los modos de concentración.

## 3. Deuda externa (dependencias y toolchain)

### 3.1 Advertencia de Kotlin Gradle Plugin (KGP) — `flutter_timezone`

El build emite:

> Your app uses the following plugins that apply Kotlin Gradle Plugin (KGP): flutter_timezone. Future versions of Flutter will fail to build…

Contexto (ver [migración a built-in Kotlin para apps](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers) y [guía para autores de plugins](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)):

- Con AGP 9 la aplicación de KGP dejó de ser válida; Flutter la tolera **temporalmente** y lo eliminará en una versión futura.
- El proyecto tiene los flags temporalmente: `android.builtInKotlin=false` y `android.newDsl=false` en `android/gradle.properties` (los añadió el migrador de Flutter).
- Nuestro *app module* ya está listo (AGP 9.1.0 + bloque `kotlin { compilerOptions { … } }`); el problema es del plugin.

Acciones pendientes:

1. Vigilar el changelog de `flutter_timezone` (hoy 5.1.0 es la última y sigue aplicando KGP).
2. Reportar el issue al repo del plugin con la plantilla oficial ("Migrate plugin to built-in Kotlin").
3. Cuando exista versión migrada: actualizar, activar `android.builtInKotlin=true` en `gradle.properties`, y volver a validar `flutter build apk --debug` (Flutter 3.47+ ya soporta built-in Kotlin).

### 3.2 Dependencias transitivas desactualizadas (no accionable)

`flutter pub outdated` marca `dbus`, `equatable`, `meta`, `vector_math` y `test_api` como antiguas, pero están **bloqueadas por los constraints** de Flutter y de `flutter_local_notifications`; se resuelven solas al subir Flutter. No tocar `pubspec.lock` a mano.

### 3.3 Advertencias del entorno (no del proyecto)

- `Warning: SDK processing. This version only understands SDK XML versions up to 3…`: desajuste entre Android Studio y las command-line tools. Se corrige actualizando `cmdline-tools`/Android Studio.
- `WARNING: A restricted method in java.lang.System has been called…`: JDK moderno + Gradle. Ruido inofensivo del wrapper.

## 4. Limitaciones de plataforma conocidas (documentadas, no bugs)

- **Canales Android inmutables**: sonido, importancia, vibración y `bypassDnd` quedan fijados al crear el canal. Cualquier cambio exige subir `_channelId` (hoy `birthday_alarm_channel_v3`) o recrear el canal. El canal antiguo sigue listado en Ajustes hasta desinstalar.
- **iOS: límite de 64 notificaciones pendientes**. Si se registran más de 64 cumpleaños, iOS conserva las últimas 64. Mitigación futura: programar solo la próxima ocurrencia de cada cumpleaños y reprogramar, o paginar por meses.
- **Samsung**: máximo operativo de ~500 alarmas del `AlarmManager`.
- **Fabricantes agresivos (Realme/Xiaomi/Huawei…)**: pueden congelar la app y no disparar avisos. El `BOOT_COMPLETED` solo reprograma tras reinicio, no evita *task killers*. Requiere ajustes de batería del usuario ([dontkillmyapp.com](https://dontkillmyapp.com/)).
- **29 de febrero**: en años no bisiestos `DateTime(año, 2, 29)` rueda al 1 de marzo; comportamiento asumido (cubierto por tests).
- **Horario de verano (DST)**: `zonedSchedule` + `timezone` respetan el huso; en días de cambio horario la hora puede ajustarse ±1 h (comportamiento documentado del plugin).
- **Texto con la edad**: se recalcula al abrir la app (`rescheduleAll` en `main.dart`). Si no se abre en un año, el aviso suena igual pero el texto puede quedar con la edad anterior.
- **Zona horaria**: si `FlutterTimezone.getLocalTimezone()` falla, `tz.local` queda en UTC. Solo relevante en plataformas no móviles; en Android/iOS se detecta bien.

### Escenarios en los que un aviso puede no llegar

| # | Escenario | Qué pasa | Cobertura en la app |
|---|---|---|---|
| 1 | Notificaciones de la app desactivadas (Android 13+) | El sistema descarta el aviso | Banner + botón a Ajustes (`_notificationsDisabled`) |
| 2 | Canal "Cumpleaños" desactivado o silenciado por el usuario | Android descarta/silencia sin avisar a la app | `isChannelEnabled()` + banner |
| 3 | "Alarmas y recordatorios" denegado (Android 12+) | Aviso inexacto: Doze puede retrasarlo horas | Banner nuevo + reprogramación al concederlo |
| 4 | No Molestar sin acceso concedido | El aviso queda silencioso (o oculto según ajuste) | Banner DND + `refreshDndChannel()` |
| 5 | Force-stop (usuario, task killer o ROM agresiva) | Android cancela todas las alarmas hasta la próxima apertura | No detectable; se reprograma al abrir la app |
| 6 | Ahorro de batería/hibernación del fabricante | La app no despierta a las 7:00 | Guía in-app (icono AppBar) + ajustes del sistema; dontkillmyapp.com |
| 7 | Reinicio del equipo | Android borra las alarmas; `BOOT_COMPLETED` las reprograma desde la caché del plugin | Manifest + receiver del plugin |
| 8 | Actualización/reinstalación de la app | Igual que el reinicio, vía `MY_PACKAGE_REPLACED` | Receiver del plugin; además `rescheduleAll` al abrir |
| 9 | Abrir la app después de las 7:00 del cumpleaños | El aviso pendiente se reprograma al año siguiente | Banner de recuperación si la notificación no está visible |
| 10 | Cambio de zona horaria/DST o de la hora del equipo | La alarma conserva el instante: puede sonar ±1 h | `refreshLocalTimeZone()` + `rescheduleAll()` al reanudar |
| 11 | Teléfono apagado a las 7:00 | Al encender, la caché del plugin dispara la alarma vencida (tarde) | Receiver del plugin |
| 12 | Límites del sistema: 64 avisos en iOS, ~500 alarmas en Samsung | Se descartan los excedentes | Documentado; pendiente estrategia iOS |
| 13 | Errores al programar (PlatformException) | Antes: silenciosos | Ahora: log + SnackBar |
| 14 | Datos borrados o app desinstalada | Se pierden cumpleaños y avisos | Esperado (sin backend) |

## 5. Deuda de código y mejoras recomendadas

### P1

- [x] **Tests de widget** para `BirthdayForm` (validación, selección de fecha, modo edición) y renderizado de la lista/estado vacío (`test/widget_test.dart`).
- [x] **Editar cumpleaños** con reprogramación de la notificación (mismo id en SQLite).
- [x] **Detección de canal desactivado** (`isChannelEnabled()` + banner en `home_screen.dart`, con test unitario en `test/notification_service_test.dart`).
- [x] **Sin cancelación masiva al reprogramar** y espera de la carga inicial antes de reprogramar (incidente 2026-09-22).
- [x] **Banner de alarmas exactas** (Android 12+) con reprogramación al conceder el permiso.
- [ ] **Fallback de zona horaria**: usar el offset de `DateTime.now()` o avisar al usuario si no se pudo fijar `tz.local`.
- [ ] **Estrategia iOS >64 avisos** (ver sección 4).
- [ ] **Validar en dispositivo Android 12+** el flujo de "Alarmas y recordatorios" (banner, concesión y reprogramación exacta).

### P2

- [ ] i18n formal (hoy textos fijos en español; aceptable para app local).
- [ ] Export/Import de cumpleaños (backup). Android ya respalda la DB con `allowBackup`.
- [ ] CI que ejecute `flutter analyze` + `flutter test`.
- [ ] Adoptar `dart format` como paso previo a cada commit.
- [ ] Revisar `flutter_local_notifications` en cada subida de Flutter (API v22 ya usa parámetros con nombre).

## 6. Referencias

- [Built-in Kotlin migration for app developers](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers)
- [Built-in Kotlin migration for plugin authors](https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-plugin-authors)
- [Build and release an Android app](https://docs.flutter.dev/deployment/android)
- [Build and release an iOS app](https://docs.flutter.dev/deployment/ios)
- [flutter_local_notifications (readme: canales inmutables, límites, DND)](https://pub.dev/packages/flutter_local_notifications)
- [Alertas críticas en iOS (entitlement)](https://developer.apple.com/contact/request/notifications-critical-alerts-entitlement/)
- [dontkillmyapp.com](https://dontkillmyapp.com/)
