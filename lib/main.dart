import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/birthday_database.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Datos de formato de fechas en español para `intl`.
  await initializeDateFormatting('es');

  // Notificaciones: zonas horarias, canal de alarma y avisos ya guardados.
  await NotificationService.instance.init();
  final birthdays = await BirthdayDatabase.instance.getAll();
  await NotificationService.instance.rescheduleAll(birthdays);

  runApp(const BirthdayReminderApp());
}

class BirthdayReminderApp extends StatelessWidget {
  const BirthdayReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recordatorio de cumpleaños',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFD81B60)),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es'), Locale('en')],
      locale: const Locale('es'),
      home: const HomeScreen(),
    );
  }
}
