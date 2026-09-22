# Deuda técnica y pendientes — NotificacionesESM

Revisiones: **2026-09-21** (inicial y tras el pase a producción) con **Flutter 3.47.0 stable / Dart 3.13.0** (Windows).

## Estado actual (verificado)

| Comprobación | Comando | Resultado |
|---|---|---|
| Análisis estático | `flutter analyze` | 0 issues |
| Tests | `flutter test` | 13/13 en verde (7 unitarios + 6 de widget) |
| Build Android debug | `flutter build apk --debug` | OK |
| Build Android release | `flutter build apk --release` | OK (firma debug de respaldo; ver P0-1) |
| Dependencias directas | `flutter pub outdated` | Todas al día |

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

## 5. Deuda de código y mejoras recomendadas

### P1

- [x] **Tests de widget** para `BirthdayForm` (validación, selección de fecha, modo edición) y renderizado de la lista/estado vacío (`test/widget_test.dart`).
- [x] **Editar cumpleaños** con reprogramación de la notificación (mismo id en SQLite).
- [x] **Detección de canal desactivado** (`isChannelEnabled()` + banner en `home_screen.dart`, con test unitario en `test/notification_service_test.dart`).
- [ ] **Fallback de zona horaria**: usar el offset de `DateTime.now()` o avisar al usuario si no se pudo fijar `tz.local`.
- [ ] **Estrategia iOS >64 avisos** (ver sección 4).

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
