# Cumpleaños — Recordatorios anuales

<p align="center">
  <img src="assets/icon/app_icon.png" alt="Icono de la app Cumpleaños" width="120">
</p>

Aplicación Flutter (**Android e iOS**) para no olvidar los cumpleaños. Guarda nombre y fecha de nacimiento y programa un aviso local todos los años a las **7:00 AM** con la edad que cumple la persona.

Sin backend, sin cuentas y sin red: los datos viven únicamente en el dispositivo.

## Características

- Alta, edición y eliminación de cumpleaños con SQLite (`sqflite`).
- Recordatorio anual a las 7:00 AM, reprogramado con la edad actualizada al abrir la app.
- Canal de Android de importancia máxima, con sonido propio y opción de sonar incluso en No Molestar.
- Aviso de recuperación: si abres la app el día del cumpleaños y la notificación no está visible, se muestra un banner de celebración.
- Avisos y guías dentro de la app cuando falta un permiso (notificaciones, canal, alarmas exactas, No Molestar, ahorro de batería).
- Detecta cambios de huso horario al volver a la app y reprograma los avisos.
- Interfaz Material 3 en español; identificadores de código en inglés.

## Requisitos

- Flutter **3.47** (stable) y Dart 3.13 o superior.
- Android 7.0+ (API 24). iOS: ver notas de iOS más abajo.

## Cómo ejecutar

```bash
flutter pub get
flutter devices                 # elige tu dispositivo
flutter run -d <device_id>
```

## Compilar APK

```bash
flutter build apk --debug       # incluye el botón de prueba (campana) en la barra superior
flutter build apk --release     # recomendado para probar sin PC
```

Salida: `build/app/outputs/flutter-apk/app-release.apk`.

Para firmar en release, copia `android/key.properties.example` a `android/key.properties`, genera el keystore con `keytool` y compila de nuevo. Sin ese archivo, el release se firma con la clave de depuración para no romper el build (no apto para publicar).

## Permisos y fiabilidad de los avisos (Android)

La app pide y explica sus permisos con banners en la pantalla principal:

| Permiso / ajuste | Para qué |
|---|---|
| `POST_NOTIFICATIONS` (Android 13+) | Poder mostrar el aviso |
| Canal "Cumpleaños" | El usuario puede desactivarlo; la app lo detecta y avisa |
| Alarmas exactas (`SCHEDULE_EXACT_ALARM`, Android 12+) | Que el aviso suene a las 7:00 AM y no lo retrase Doze |
| Acceso a No Molestar (`ACCESS_NOTIFICATION_POLICY`) | Sonar aunque el teléfono esté en No Molestar |
| Ahorro de batería del fabricante | Xiaomi, Samsung, Huawei, Oppo, Vivo, etc. pueden congelar la app; hay una guía in-app que abre los ajustes del sistema |
| `RECEIVE_BOOT_COMPLETED` | Reprogramar los avisos tras reiniciar el teléfono |

Si un fabricante fuerza la detención de la app, Android cancela las alarmas; al volver a abrir la app se reprograman. Más detalle en [docs/deuda-tecnica.md](docs/deuda-tecnica.md).

## iOS

- Los sonidos (`birthday_chime.wav`, `gentle_chime.wav`) deben estar en `ios/Runner/` y añadidos al target *Runner* en Xcode (Copy Bundle Resources).
- `InterruptionLevel.timeSensitive` requiere la capability **Time Sensitive Notifications** en Xcode.

## Estructura del proyecto

```
lib/
├── main.dart                        # ensureInitialized + runApp
├── models/birthday.dart
├── data/birthday_database.dart      # SQLite (CRUD)
├── services/notification_service.dart
├── services/battery_optimization_service.dart
├── utils/birthday_dates.dart        # 7:00 AM, edad, días restantes
├── screens/app_bootstrap.dart       # splash + inicialización
├── screens/home_screen.dart
└── widgets/                         # formulario, lista y fila
test/                                # unitarios de fechas y de widget
docs/deuda-tecnica.md                # decisiones, límites de plataforma y pendientes
```

## Calidad

```bash
flutter analyze     # 0 issues
flutter test        # 25/25 en verde
dart format .
```

## Privacidad

- No hay servidor ni telemetría: los cumpleaños se guardan en SQLite dentro del dispositivo.
- La build de release **no declara** el permiso `INTERNET` (solo debug/profile lo usan para el modo desarrollo de Flutter).
- El sistema operativo puede incluir los datos de la app en el respaldo del usuario (Android `allowBackup`).

## Documentación

- [docs/deuda-tecnica.md](docs/deuda-tecnica.md): revisiones, límites de plataforma, escenarios en los que un aviso puede no llegar y pendientes.
- [AGENTS.md](AGENTS.md): guía para agentes de IA y desarrolladores que editen el repositorio.

## Licencia

Este proyecto todavía no define una licencia.
