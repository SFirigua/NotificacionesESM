import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../data/birthday_database.dart';
import '../models/birthday.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';

/// Color de marca compartido con el splash nativo de Android
/// (`android/app/src/main/res/values/colors.xml` → `splash_background`).
const Color kSplashColor = Color(0xFFC8145A);

/// Inicializa la app fuera del hilo del primer frame.
///
/// El arranque (locale, notificaciones, base de datos y reprogramación de
/// avisos) puede tardar varios segundos en dispositivos lentos; bloquear
/// `main()` dejaría la pantalla en negro todo ese tiempo. Aquí se muestra el
/// splash de inmediato y se pasa a [HomeScreen] cuando todo está listo.
class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  Future<List<Birthday>>? _bootstrap;

  @override
  void initState() {
    super.initState();
    // Deja pintar el splash antes de arrancar el trabajo pesado (zonas
    // horarias, plugin de notificaciones, BD).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _bootstrap = _initialize());
      }
    });
  }

  Future<List<Birthday>> _initialize() async {
    // Datos de formato de fechas en español para `intl`.
    await initializeDateFormatting('es');

    // Notificaciones: zonas horarias, canal de alarma y avisos ya guardados.
    await NotificationService.instance.init();
    final birthdays = await BirthdayDatabase.instance.getAll();
    try {
      await NotificationService.instance.rescheduleAll(birthdays);
    } catch (error) {
      // Un fallo al reprogramar no debe impedir usar la app.
      debugPrint('No se pudieron reprogramar los avisos: $error');
    }
    return birthdays;
  }

  void _retry() {
    setState(() => _bootstrap = _initialize());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Birthday>>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return BootstrapErrorScreen(error: snapshot.error, onRetry: _retry);
        }
        final birthdays = snapshot.data;
        if (birthdays == null) {
          return const SplashScreen();
        }
        return HomeScreen(initialBirthdays: birthdays);
      },
    );
  }
}

/// Pantalla de carga con la identidad de la app.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const foreground = Colors.white;
    return Scaffold(
      backgroundColor: kSplashColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cake_rounded, size: 72, color: foreground),
            const SizedBox(height: 16),
            Text(
              'Cumpleaños',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Recordatorios a las 7:00 AM',
              style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Error fatal de arranque (por ejemplo, la base de datos no abre).
class BootstrapErrorScreen extends StatelessWidget {
  const BootstrapErrorScreen({super.key, this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'No se pudo iniciar la app',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Cierra la app y vuelve a intentarlo.',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      ),
    );
  }
}
